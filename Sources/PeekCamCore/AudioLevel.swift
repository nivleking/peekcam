import Foundation

/// Turns microphone samples into the 0...1 value the Mic Check meter shows.
public enum AudioLevel {
    /// Quietest level the meter shows, in dBFS.
    static let floorDB = -80.0

    /// Root-mean-square of samples in -1...1.
    public static func rms(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        return (sum / Double(samples.count)).squareRoot()
    }

    /// dBFS mapped linearly: -80 dB (silence) = 0, 0 dB (full scale) = 1.
    public static func meter(rms: Double) -> Double {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(max((db - floorDB) / -floorDB, 0), 1)
    }

    /// Rises at once, falls slowly, so the bar does not flicker between words.
    public static func smoothed(previous: Double, new: Double) -> Double {
        max(new, previous * 0.85)
    }
}
