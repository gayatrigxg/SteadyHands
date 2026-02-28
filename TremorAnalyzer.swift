import Foundation
import Accelerate
import PencilKit

struct TremorAnalysisResult {
    let dominantFrequency: Float
    let tremorStrength: Float
    let isTremorDetected: Bool
}

struct TremorAnalyzer {
    
    // MARK: Main Entry
    
    static func analyze(stroke: PKStroke) -> TremorAnalysisResult? {
        
        let path = stroke.path
        let count = path.count
        
        guard count > 20 else { return nil }
        
        // Extract velocity magnitude over time
        var velocity: [Float] = []
        
        for i in 1..<count {
            let p1 = path[i - 1]
            let p2 = path[i]
            
            let dx = Float(p2.location.x - p1.location.x)
            let dy = Float(p2.location.y - p1.location.y)
            let dt = Float(p2.timeOffset - p1.timeOffset)
            
            guard dt > 0 else { continue }
            
            let v = sqrt(dx * dx + dy * dy) / dt
            velocity.append(v)
        }
        
        guard velocity.count > 16 else { return nil }
        
        return performFFT(on: velocity)
    }
    
    // MARK: FFT
    
    private static func performFFT(on signal: [Float]) -> TremorAnalysisResult {
        
        let length = signal.count
        let log2n = UInt(round(log2(Double(length))))
        let n = Int(pow(2.0, Double(log2n)))
        
        let truncated = Array(signal.prefix(n))
        
        var real = truncated
        var imag = [Float](repeating: 0, count: n)
        
        let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )
                
                vDSP_fft_zip(
                    setup,
                    &splitComplex,
                    1,
                    log2n,
                    FFTDirection(FFT_FORWARD)
                )
            }
        }
        
        vDSP_destroy_fftsetup(setup)
        
        // Magnitudes
        var magnitudes = [Float](repeating: 0, count: n/2)
        
        for i in 0..<n/2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }
        
        // Find dominant frequency index
        guard let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return TremorAnalysisResult(
                dominantFrequency: 0,
                tremorStrength: 0,
                isTremorDetected: false
            )
        }
        
        // Estimate frequency
        let samplingRate: Float = 60 // approx Apple Pencil sampling
        let dominantFreq = Float(maxIndex) * samplingRate / Float(n)
        
        // Tremor band detection
        let tremorBand = dominantFreq >= 3 && dominantFreq <= 12
        
        let strength = magnitudes[maxIndex] / (magnitudes.reduce(0,+) + 0.0001)
        
        return TremorAnalysisResult(
            dominantFrequency: dominantFreq,
            tremorStrength: strength,
            isTremorDetected: tremorBand
        )
    }
}
