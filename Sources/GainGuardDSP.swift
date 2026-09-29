import Foundation
import Accelerate

/// GainGuardDSP: Intelligent audio processing pipeline engineered to allow amplification
/// beyond 100% (up to 600%) while strictly safeguarding speakers and hearing against
/// square-wave clipping, DC-offset burnout, and acoustic shock.
public final class GainGuardDSP {
    public static let shared = GainGuardDSP()

    // MARK: - Constants & Limits
    public let ceilingLinear: Float = 0.965 // -0.31 dBFS hard ceiling (strictly prevents 0dB clipping)
    public let softKneeThreshold: Float = 0.707 // -3.0 dBFS where compression transitions into limiting
    public let subBassCutoffHz: Float = 55.0 // Mechanical safety cutoff for laptop speakers

    // MARK: - Safety Telemetry
    public enum SafetyState {
        case safe           // Green: normal range (< 100% or low peak)
        case compressing    // Yellow: dynamic range compressor active (loud dialogue lift)
        case limiting       // Orange: brickwall limiter actively protecting speakers
    }

    public struct Telemetry {
        public var peakLeft: Float = 0.0
        public var peakRight: Float = 0.0
        public var safetyState: SafetyState = .safe
        public var gainReductionDb: Float = 0.0
    }

    // High-Pass Filter State (Biquad Direct Form II)
    private var hpf_x1_L: Float = 0, hpf_x2_L: Float = 0, hpf_y1_L: Float = 0, hpf_y2_L: Float = 0
    private var hpf_x1_R: Float = 0, hpf_x2_R: Float = 0, hpf_y1_R: Float = 0, hpf_y2_R: Float = 0

    public init() {}

    /// Process a stereo buffer of audio samples in-place.
    /// - Parameters:
    ///   - left: Pointer to Left channel Float samples (-1.0 to 1.0)
    ///   - right: Pointer to Right channel Float samples (-1.0 to 1.0)
    ///   - frameCount: Number of frames in buffer
    ///   - boostFactor: Linear gain multiplier (1.0 = 100%, 3.0 = 300%, 6.0 = 600%)
    ///   - pan: Stereo pan (-1.0 full left, 0.0 center, 1.0 full right)
    ///   - speakerProtectionEnabled: If true, filters damaging sub-bass (<55Hz)
    /// - Returns: Live telemetry for VU meters and safety state
    @discardableResult
    public func processStereo(
        left: UnsafeMutablePointer<Float>,
        right: UnsafeMutablePointer<Float>,
        frameCount: Int,
        boostFactor: Float,
        pan: Float = 0.0,
        speakerProtectionEnabled: Bool = true
    ) -> Telemetry {
        var maxPeakL: Float = 0.0
        var maxPeakR: Float = 0.0
        var maxGainReduction: Float = 0.0

        // Pan Law (Equal Power: -3dB at center)
        let panAngle = (pan + 1.0) * (.pi / 4.0) // 0 to pi/2
        let gainL = boostFactor * cos(panAngle) * 1.4142
        let gainR = boostFactor * sin(panAngle) * 1.4142

        for i in 0..<frameCount {
            var sampleL = left[i]
            var sampleR = right[i]

            // Stage 1: High-Pass Filter (Laptop Speaker Transducer Safety)
            if speakerProtectionEnabled {
                sampleL = applyHPF(sample: sampleL, x1: &hpf_x1_L, x2: &hpf_x2_L, y1: &hpf_y1_L, y2: &hpf_y2_L)
                sampleR = applyHPF(sample: sampleR, x1: &hpf_x1_R, x2: &hpf_x2_R, y1: &hpf_y1_R, y2: &hpf_y2_R)
            }

            // Stage 2: Gain & Panning
            let amplifiedL = sampleL * gainL
            let amplifiedR = sampleR * gainR

            // Stage 3 & 4: Brickwall Peak Limiter & Soft Clipper
            let (limitedL, redL) = limitSample(amplifiedL)
            let (limitedR, redR) = limitSample(amplifiedR)

            left[i] = limitedL
            right[i] = limitedR

            maxPeakL = max(maxPeakL, abs(limitedL))
            maxPeakR = max(maxPeakR, abs(limitedR))
            maxGainReduction = max(maxGainReduction, max(redL, redR))
        }

        let state: SafetyState
        if maxGainReduction > 2.5 {
            state = .limiting
        } else if maxGainReduction > 0.3 || boostFactor > 1.2 {
            state = .compressing
        } else {
            state = .safe
        }

        return Telemetry(
            peakLeft: min(maxPeakL, 1.0),
            peakRight: min(maxPeakR, 1.0),
            safetyState: state,
            gainReductionDb: maxGainReduction
        )
    }

    /// Soft-Knee Saturation & Brickwall Limiter.
    /// Perfectly maps infinite input to strictly [-ceilingLinear, +ceilingLinear]
    /// using smooth continuous hyperbolic tangency at the knee, completely eliminating square-wave clipping.
    @inline(__always)
    private func limitSample(_ input: Float) -> (output: Float, reductionDb: Float) {
        let absIn = abs(input)
        if absIn <= softKneeThreshold {
            return (input, 0.0)
        }

        // Apply smooth soft-knee tanh compression
        let sign: Float = input < 0 ? -1.0 : 1.0
        let excess = absIn - softKneeThreshold
        let headroom = ceilingLinear - softKneeThreshold
        let compressedExcess = headroom * tanh(excess / headroom)
        let limitedAbs = softKneeThreshold + compressedExcess

        let finalOutput = sign * min(limitedAbs, ceilingLinear)
        let reduction = 20.0 * log10(max(absIn / finalOutput, 1.0))
        return (finalOutput, reduction)
    }

    /// 2nd Order Butterworth High-Pass Filter @ 55Hz (SampleRate: 48,000Hz)
    @inline(__always)
    private func applyHPF(
        sample: Float,
        x1: inout Float, x2: inout Float,
        y1: inout Float, y2: inout Float
    ) -> Float {
        // Pre-computed Butterworth coefficients (fc = 55Hz, fs = 48000Hz, Q = 0.7071)
        let b0: Float = 0.9949216
        let b1: Float = -1.9898432
        let b2: Float = 0.9949216
        let a1: Float = -1.9898174
        let a2: Float = 0.9898690

        let output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = sample
        y2 = y1
        y1 = output
        return output
    }
}
