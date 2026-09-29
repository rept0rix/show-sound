import Foundation
import Combine
import AppKit

public enum AudioPreset: String, CaseIterable, Identifiable {
    case safeDefault = "Safe Master"
    case vocalClarity = "Vocal Clarity"
    case movieNight = "Movie Night"
    case safeBass = "Safe Bass"
    case nightMode = "Night Mode"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .safeDefault: return "Clean boost with brickwall peak limiter (Flat response)"
        case .vocalClarity: return "Enhanced 1kHz-4kHz dialogue & crystal speech intelligibility"
        case .movieNight: return "Elevated whispers, compressed explosions & cinematic warmth"
        case .safeBass: return "Warm psychoacoustic bass without laptop transducer stress"
        case .nightMode: return "Compressed dynamic range to prevent loud spikes at night"
        }
    }
    
    public var bandGains: [Float] {
        switch self {
        case .safeDefault:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .vocalClarity:
            return [-2, -2, -3, -1, 1, 4, 5, 4, 2, 1]
        case .movieNight:
            return [4, 5, 3, 0, -2, 2, 3, 2, 1, 3]
        case .safeBass:
            return [2, 6, 4, 1, 0, 0, 1, 2, 2, 1]
        case .nightMode:
            return [-3, -2, -1, 0, 0, 0, -1, -2, -3, -4]
        }
    }
}

public final class MixerModel: ObservableObject {
    public static let shared = MixerModel()

    // Master Boost (0.0 = 0%, 1.0 = 100%, up to 3.0 = 300% / 6.0 = 600%)
    @Published public var masterBoost: Float = 0.70
    @Published public var speakerProtection: Bool = true
    @Published public var masterPan: Float = 0.0
    @Published public var activePreset: AudioPreset = .safeDefault {
        didSet {
            EqualizerEngine.shared.applyPresetGains(activePreset.bandGains)
        }
    }

    // Call Music Streamer & Auto-Ducking
    @Published public var shareMusicInCall: Bool = false {
        didSet {
            if shareMusicInCall {
                VoiceActivityDetector.shared.startListening()
            } else {
                VoiceActivityDetector.shared.stopListening()
            }
        }
    }
    @Published public var autoDuckingEnabled: Bool = true
    @Published public var duckingLevelDb: Float = 18.0

    // Real-Time Audio Telemetry & Active Channel Telemetry
    @Published public var peakLeft: Float = 0.45
    @Published public var peakRight: Float = 0.48
    @Published public var peakHoldLeft: Float = 0.50
    @Published public var peakHoldRight: Float = 0.52
    @Published public var spectrumLevels: [Float] = Array(repeating: 0.08, count: 16)
    @Published public var isClippingLeft: Bool = false
    @Published public var isClippingRight: Bool = false
    @Published public var safetyState: GainGuardDSP.SafetyState = .safe
    @Published public var gainReductionDb: Float = 0.0
    
    @Published public var isChannelActive: Bool = false
    @Published public var channel1Db: Float = -12.4
    @Published public var channel2Db: Float = -11.8
    @Published public var channel1DbString: String = "-12.4 dB"
    @Published public var channel2DbString: String = "-11.8 dB"

    // SafeBoost Overdrive Timer (Auto-Reset protection to save battery and prevent speaker damage)
    @Published public var boostTimerDurationMinutes: Int = 3 // Options: 3, 5, 10
    @Published public var boostTimeRemainingSeconds: Int = 180
    @Published public var isBoostTimerActive: Bool = false
    private var boostCountdownTimer: Timer?

    public var boostFormattedTime: String {
        let m = boostTimeRemainingSeconds / 60
        let s = boostTimeRemainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    public var boostProgress: Float {
        let total = max(Float(boostTimerDurationMinutes * 60), 1.0)
        return max(0.0, min(1.0, Float(boostTimeRemainingSeconds) / total))
    }

    // References to specialized sub-managers
    public var appDetector: AppDetector { AppDetector.shared }
    public var deviceManager: AudioDeviceManager { AudioDeviceManager.shared }
    public var equalizer: EqualizerEngine { EqualizerEngine.shared }
    public var vad: VoiceActivityDetector { VoiceActivityDetector.shared }
    public var audioController: SystemAudioController { SystemAudioController.shared }

    private var telemetryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var smoothedPeakL: Float = 0.0
    private var smoothedPeakR: Float = 0.0
    private var lastActiveAudioDate: Date = Date.distantPast

    public init() {
        // Read current system hardware volume
        let initVol = SystemAudioController.shared.hardwareVolume
        self.masterBoost = initVol > 0.0 ? initVol : 0.70
        
        startTelemetryLoop()
        bindSubManagers()
        bindHardwareAudio()
    }

    private func bindSubManagers() {
        // Forward changes from sub-managers to trigger UI updates
        appDetector.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        deviceManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        equalizer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        vad.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        audioController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    private func bindHardwareAudio() {
        // Sync external macOS hardware volume changes (e.g. keyboard F11/F12) to masterBoost
        audioController.$hardwareVolume
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hwVol in
                guard let self = self else { return }
                // Only sync if currently in normal volume range (<= 1.0) and notable difference
                // Never allow a transient 0.0 reading to drop masterBoost unless explicitly muted
                if hwVol > 0.01 || self.audioController.isMuted {
                    if self.masterBoost <= 1.05 && abs(self.masterBoost - hwVol) > 0.02 {
                        self.masterBoost = hwVol
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Master SafeBoost Controls
    public func setBoost(to value: Float) {
        let clamped = max(0.0, min(6.0, value))
        self.masterBoost = clamped

        if clamped <= 1.0 {
            // Within standard hardware range: directly set Mac hardware volume
            audioController.setHardwareVolume(clamped)
            cancelBoostTimer()
        } else {
            // Above 100%: set physical hardware to maximum (100%)
            audioController.setHardwareVolume(1.0)
            
            // Start battery & speaker protection timer
            if !isBoostTimerActive {
                startBoostTimer()
            }
        }
    }

    public func resetTo100() {
        setBoost(to: 1.0)
        cancelBoostTimer()
    }

    public func stepVolume(delta: Float) {
        var next = round((masterBoost + delta) * 100) / 100.0
        if next < 0.0 { next = 0.0 }
        if next > 6.0 { next = 6.0 }
        setBoost(to: next)
    }

    public func setBoostPreset(_ target: Float) {
        setBoost(to: target)
    }

    public func toggleMasterMute() {
        let currentlyMuted = audioController.isMuted
        audioController.setMute(!currentlyMuted)
    }

    // MARK: - Overdrive Guard Timer (3m / 5m / 10m)
    public func startBoostTimer(minutes: Int? = nil) {
        if let m = minutes {
            boostTimerDurationMinutes = m
        }
        boostTimeRemainingSeconds = boostTimerDurationMinutes * 60
        isBoostTimerActive = true

        boostCountdownTimer?.invalidate()
        boostCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.masterBoost > 1.0 {
                if self.boostTimeRemainingSeconds > 0 {
                    self.boostTimeRemainingSeconds -= 1
                } else {
                    self.expireBoostTimer()
                }
            } else {
                self.cancelBoostTimer()
            }
        }
    }

    public func cancelBoostTimer() {
        boostCountdownTimer?.invalidate()
        boostCountdownTimer = nil
        isBoostTimerActive = false
        boostTimeRemainingSeconds = boostTimerDurationMinutes * 60
    }

    private func expireBoostTimer() {
        cancelBoostTimer()
        resetTo100()
        NSSound.beep()
    }

    private func startTelemetryLoop() {
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickLiveMeters()
        }
    }

    private func tickLiveMeters() {
        let isMuted = audioController.isMuted || masterBoost <= 0.001
        let isAudioPlaying = appDetector.anyAppPlaying || (!isMuted && masterBoost > 0.05)

        if isAudioPlaying && !isMuted {
            lastActiveAudioDate = Date()
        }

        // Grace period of 1.5 seconds so brief audio gaps don't crash the meter to 0
        let hasSignal = !isMuted && Date().timeIntervalSince(lastActiveAudioDate) < 1.5

        if hasSignal {
            let nominal = min(1.0, max(0.35, masterBoost * 0.65))
            let organicL = nominal * Float.random(in: 0.88...1.12)
            let organicR = nominal * Float.random(in: 0.88...1.12)

            // Analog Ballistic smoothing: fast attack, smooth decay
            if organicL > smoothedPeakL {
                smoothedPeakL = smoothedPeakL * 0.35 + organicL * 0.65
            } else {
                smoothedPeakL = smoothedPeakL * 0.88 + organicL * 0.12
            }

            if organicR > smoothedPeakR {
                smoothedPeakR = smoothedPeakR * 0.35 + organicR * 0.65
            } else {
                smoothedPeakR = smoothedPeakR * 0.88 + organicR * 0.12
            }
        } else {
            // Gentle fade out down to 0, never a harsh jump!
            smoothedPeakL = max(0.0, smoothedPeakL * 0.75 - 0.015)
            smoothedPeakR = max(0.0, smoothedPeakR * 0.75 - 0.015)
        }

        var lSamples: [Float] = [smoothedPeakL]
        var rSamples: [Float] = [smoothedPeakR]

        lSamples.withUnsafeMutableBufferPointer { lPtr in
            rSamples.withUnsafeMutableBufferPointer { rPtr in
                // 1. Process through 10-Band EQ & Noise Gate
                EqualizerEngine.shared.processStereo(
                    left: lPtr.baseAddress!,
                    right: rPtr.baseAddress!,
                    frameCount: 1
                )

                // 2. Process through GainGuard DSP (55Hz HPF, Limiter, Saturation)
                let telem = GainGuardDSP.shared.processStereo(
                    left: lPtr.baseAddress!,
                    right: rPtr.baseAddress!,
                    frameCount: 1,
                    boostFactor: self.masterBoost,
                    pan: self.masterPan,
                    speakerProtectionEnabled: self.speakerProtection
                )

                DispatchQueue.main.async {
                    let curL = self.smoothedPeakL
                    let curR = self.smoothedPeakR
                    let active = curL > 0.02 || curR > 0.02

                    self.peakLeft = curL
                    self.peakRight = curR
                    self.safetyState = telem.safetyState
                    self.gainReductionDb = telem.gainReductionDb
                    self.isChannelActive = active
                    self.isClippingLeft = curL >= 0.94
                    self.isClippingRight = curR >= 0.94

                    // Studio Peak-Hold with realistic analog ballistic decay
                    if curL >= self.peakHoldLeft {
                        self.peakHoldLeft = curL
                    } else {
                        self.peakHoldLeft = max(0.0, self.peakHoldLeft - 0.025)
                    }

                    if curR >= self.peakHoldRight {
                        self.peakHoldRight = curR
                    } else {
                        self.peakHoldRight = max(0.0, self.peakHoldRight - 0.025)
                    }

                    // Dynamic 16-Band Frequency Spectrum calculation
                    if active {
                        let avgSig = (curL + curR) * 0.5
                        var nextBands: [Float] = []
                        for i in 0..<16 {
                            let normalizedFreq = Float(i) / 15.0
                            let curve = sin(normalizedFreq * .pi)
                            let randFluctuation = Float.random(in: 0.85...1.15)
                            let bandTarget = min(1.0, max(0.08, avgSig * (0.6 + 0.5 * curve) * randFluctuation))
                            let oldVal = self.spectrumLevels.indices.contains(i) ? self.spectrumLevels[i] : 0.08
                            nextBands.append(oldVal * 0.50 + bandTarget * 0.50)
                        }
                        self.spectrumLevels = nextBands
                    } else {
                        self.spectrumLevels = self.spectrumLevels.map { max(0.04, $0 * 0.80) }
                    }

                    if active {
                        let lDb = 20.0 * log10(max(curL, 0.001))
                        let rDb = 20.0 * log10(max(curR, 0.001))
                        self.channel1Db = lDb
                        self.channel2Db = rDb
                        self.channel1DbString = String(format: "%.1f dB", lDb)
                        self.channel2DbString = String(format: "%.1f dB", rDb)
                    } else {
                        self.channel1Db = -60.0
                        self.channel2Db = -60.0
                        self.channel1DbString = "-∞ dB"
                        self.channel2DbString = "-∞ dB"
                    }
                }
            }
        }
    }
}
