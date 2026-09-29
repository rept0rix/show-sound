import Foundation
import Combine

public struct EQBand: Identifiable, Equatable {
    public let id: Int
    public let frequencyHz: Float
    public let label: String
    public var gainDb: Float // -12.0 dB to +12.0 dB
    
    public init(id: Int, frequencyHz: Float, label: String, gainDb: Float = 0.0) {
        self.id = id
        self.frequencyHz = frequencyHz
        self.label = label
        self.gainDb = gainDb
    }
}

public struct BiquadFilter {
    public var b0: Float = 1.0
    public var b1: Float = 0.0
    public var b2: Float = 0.0
    public var a1: Float = 0.0
    public var a2: Float = 0.0
    
    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0
    
    public init() {}
    
    public mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
    
    public mutating func setPeaking(frequency: Float, gainDb: Float, q: Float = 1.414, sampleRate: Float = 48000.0) {
        if abs(gainDb) < 0.05 {
            b0 = 1.0
            b1 = 0.0
            b2 = 0.0
            a1 = 0.0
            a2 = 0.0
            return
        }
        
        let safeFreq = min(max(frequency, 20.0), sampleRate * 0.45)
        let A = pow(10.0, gainDb / 40.0)
        let omega = 2.0 * Float.pi * safeFreq / sampleRate
        let alpha = sin(omega) / (2.0 * q)
        let cosW = cos(omega)
        let a0 = 1.0 + alpha / A
        
        b0 = (1.0 + alpha * A) / a0
        b1 = (-2.0 * cosW) / a0
        b2 = (1.0 - alpha * A) / a0
        a1 = (-2.0 * cosW) / a0
        a2 = (1.0 - alpha / A) / a0
    }
    
    @inline(__always)
    public mutating func process(sample: Float) -> Float {
        let output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = sample
        y2 = y1
        y1 = output
        return output
    }
}

public final class EqualizerEngine: ObservableObject {
    public static let shared = EqualizerEngine()
    
    @Published public var isEnabled: Bool = true
    @Published public var bands: [EQBand] = [
        EQBand(id: 0, frequencyHz: 32, label: "32Hz", gainDb: 0.0),
        EQBand(id: 1, frequencyHz: 64, label: "64Hz", gainDb: 0.0),
        EQBand(id: 2, frequencyHz: 125, label: "125Hz", gainDb: 0.0),
        EQBand(id: 3, frequencyHz: 250, label: "250Hz", gainDb: 0.0),
        EQBand(id: 4, frequencyHz: 500, label: "500Hz", gainDb: 0.0),
        EQBand(id: 5, frequencyHz: 1000, label: "1kHz", gainDb: 0.0),
        EQBand(id: 6, frequencyHz: 2000, label: "2kHz", gainDb: 0.0),
        EQBand(id: 7, frequencyHz: 4000, label: "4kHz", gainDb: 0.0),
        EQBand(id: 8, frequencyHz: 8000, label: "8kHz", gainDb: 0.0),
        EQBand(id: 9, frequencyHz: 16000, label: "16kHz", gainDb: 0.0)
    ]
    
    // Noise Isolation / Gate
    @Published public var noiseGateEnabled: Bool = false
    @Published public var noiseGateThresholdDb: Float = -48.0 // Cut hiss below -48dB
    
    // Internal Biquad Filters for 10 bands (Stereo)
    private var filtersL: [BiquadFilter] = Array(repeating: BiquadFilter(), count: 10)
    private var filtersR: [BiquadFilter] = Array(repeating: BiquadFilter(), count: 10)
    
    private let sampleRate: Float = 48000.0
    
    public init() {
        updateAllFilterCoeffs()
    }
    
    public func setBandGain(id: Int, gainDb: Float) {
        guard id >= 0 && id < bands.count else { return }
        bands[id].gainDb = max(min(gainDb, 12.0), -12.0)
        let freq = bands[id].frequencyHz
        filtersL[id].setPeaking(frequency: freq, gainDb: bands[id].gainDb, sampleRate: sampleRate)
        filtersR[id].setPeaking(frequency: freq, gainDb: bands[id].gainDb, sampleRate: sampleRate)
    }
    
    public func resetToFlat() {
        for i in 0..<bands.count {
            bands[i].gainDb = 0.0
        }
        updateAllFilterCoeffs()
    }
    
    public func applyPresetGains(_ presetGains: [Float]) {
        guard presetGains.count == bands.count else { return }
        for i in 0..<bands.count {
            bands[i].gainDb = presetGains[i]
        }
        updateAllFilterCoeffs()
    }
    
    private func updateAllFilterCoeffs() {
        for i in 0..<bands.count {
            let freq = bands[i].frequencyHz
            let gain = bands[i].gainDb
            filtersL[i].setPeaking(frequency: freq, gainDb: gain, sampleRate: sampleRate)
            filtersR[i].setPeaking(frequency: freq, gainDb: gain, sampleRate: sampleRate)
        }
    }
    
    /// Process a stereo buffer of audio through the 10-band EQ and optional noise gate.
    public func processStereo(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard isEnabled else { return }
        
        let gateLin = pow(10.0, noiseGateThresholdDb / 20.0)
        
        for i in 0..<frameCount {
            var sL = left[i]
            var sR = right[i]
            
            // Noise Gate check
            if noiseGateEnabled {
                let mag = max(abs(sL), abs(sR))
                if mag < gateLin {
                    // Soft attenuation when below gate threshold
                    let ratio = max(mag / max(gateLin, 1e-6), 0.0)
                    sL *= ratio
                    sR *= ratio
                }
            }
            
            // Cascade through 10 bands
            for b in 0..<10 {
                sL = filtersL[b].process(sample: sL)
                sR = filtersR[b].process(sample: sR)
            }
            
            left[i] = sL
            right[i] = sR
        }
    }
}
