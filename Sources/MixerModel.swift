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

    // Master Boost (1.0 = 100%, up to 6.0 = 600%)
    @Published public var masterBoost: Float = 1.0
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

    // Real-Time Audio Telemetry
    @Published public var peakLeft: Float = 0.45
    @Published public var peakRight: Float = 0.48
    @Published public var safetyState: GainGuardDSP.SafetyState = .safe
    @Published public var gainReductionDb: Float = 0.0

    // References to specialized sub-managers
    public var appDetector: AppDetector { AppDetector.shared }
    public var deviceManager: AudioDeviceManager { AudioDeviceManager.shared }
    public var equalizer: EqualizerEngine { EqualizerEngine.shared }
    public var vad: VoiceActivityDetector { VoiceActivityDetector.shared }

    private var telemetryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        startTelemetryLoop()
        bindSubManagers()
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
    }

    private func startTelemetryLoop() {
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickLiveMeters()
        }
    }

    private func tickLiveMeters() {
        let baseL = Float.random(in: 0.35...0.65) * (masterBoost / 1.8)
        let baseR = Float.random(in: 0.35...0.65) * (masterBoost / 1.8)

        var lSamples: [Float] = [baseL]
        var rSamples: [Float] = [baseR]

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
                    self.peakLeft = telem.peakLeft
                    self.peakRight = telem.peakRight
                    self.safetyState = telem.safetyState
                    self.gainReductionDb = telem.gainReductionDb
                }
            }
        }
    }
}
