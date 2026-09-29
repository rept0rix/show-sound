import Foundation
import AVFoundation
import Combine

public final class VoiceActivityDetector: ObservableObject {
    public static let shared = VoiceActivityDetector()
    
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var micLevelDb: Float = -60.0
    @Published public private(set) var micLevelLinear: Float = 0.0
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var currentDuckingGain: Float = 1.0 // 1.0 = no reduction, 0.125 = -18dB
    
    // Configurable thresholds
    @Published public var speechThresholdDb: Float = -36.0
    @Published public var duckingTargetDb: Float = -18.0
    
    private var engine: AVAudioEngine?
    private var holdTimer: Float = 0.0
    private let holdDurationSec: Float = 0.6 // 600ms hold so natural breath pauses don't cut music in and out
    private let attackRate: Float = 0.15 // Fast ducking onset
    private let releaseRate: Float = 0.05 // Smooth natural release
    
    private var updateTimer: Timer?
    
    public init() {}
    
    public func startListening() {
        guard !isListening else { return }
        
        #if os(macOS)
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard granted, let self = self else { return }
                DispatchQueue.main.async {
                    self.setupAudioEngine()
                }
            }
        } else {
            setupAudioEngine()
        }
        #endif
    }
    
    public func stopListening() {
        guard isListening else { return }
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        updateTimer?.invalidate()
        updateTimer = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isSpeaking = false
            self.currentDuckingGain = 1.0
            self.micLevelDb = -60.0
            self.micLevelLinear = 0.0
        }
    }
    
    private func setupAudioEngine() {
        let eng = AVAudioEngine()
        let input = eng.inputNode
        let format = input.outputFormat(forBus: 0)
        
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            return
        }
        
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processMicBuffer(buffer)
        }
        
        do {
            try eng.start()
            self.engine = eng
            self.isListening = true
            
            // Background envelope updater for smooth ducking animation & transitions
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
                    self?.tickEnvelope()
                }
            }
        } catch {
            print("Failed to start AVAudioEngine for VAD: \(error)")
        }
    }
    
    private func processMicBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        
        var sumSquares: Float = 0.0
        for i in 0..<frameCount {
            let s = channelData[i]
            sumSquares += s * s
        }
        
        let rms = sqrt(sumSquares / Float(frameCount))
        let db = 20.0 * log10(max(rms, 1e-4))
        let linear = min(max((db + 60.0) / 60.0, 0.0), 1.0)
        
        let speakingNow = (db >= speechThresholdDb)
        
        DispatchQueue.main.async {
            self.micLevelDb = db
            self.micLevelLinear = linear
            if speakingNow {
                self.isSpeaking = true
                self.holdTimer = self.holdDurationSec
            }
        }
    }
    
    private func tickEnvelope() {
        let targetGain: Float
        let targetDbFactor = pow(10.0, duckingTargetDb / 20.0) // ~0.125 for -18dB
        
        if isSpeaking {
            targetGain = targetDbFactor
            holdTimer -= 0.03
            if holdTimer <= 0 {
                isSpeaking = false
            }
        } else {
            targetGain = 1.0
        }
        
        // Smoothly interpolate towards target
        let rate = (targetGain < currentDuckingGain) ? attackRate : releaseRate
        currentDuckingGain += (targetGain - currentDuckingGain) * rate
    }
}
