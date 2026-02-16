import Foundation
import Combine

/// Bridges audio level data from the Rust audio thread to SwiftUI.
/// The Rust callback fires on a background audio thread; this singleton
/// applies EMA smoothing, throttles to ~30fps, and publishes on main.
final class AudioLevelBridge: ObservableObject {
    static let shared = AudioLevelBridge()

    @Published var smoothedLevel: Float = 0

    private let lock = NSLock()
    private var lastUpdateTime: CFAbsoluteTime = 0
    private var rawLevel: Float = 0

    // EMA coefficients: attack is snappy for speech onset, decay is gentle for falloff
    private let attackAlpha: Float = 0.5
    private let decayAlpha: Float = 0.15
    // Minimum interval between main-thread updates (~30fps)
    private let updateInterval: CFAbsoluteTime = 1.0 / 30.0

    private init() {}

    /// Called from the Rust audio thread via C callback.
    func onAudioLevel(rms: Float, peak: Float) {
        // Normalize raw RMS (typically 0.01–0.15 for speech) to 0–1
        let normalized = min(rms * 18.0, 1.0)

        lock.lock()
        let alpha = normalized > rawLevel ? attackAlpha : decayAlpha
        rawLevel += alpha * (normalized - rawLevel)
        let level = rawLevel
        let now = CFAbsoluteTimeGetCurrent()
        let shouldUpdate = (now - lastUpdateTime) >= updateInterval
        if shouldUpdate { lastUpdateTime = now }
        lock.unlock()

        if shouldUpdate {
            DispatchQueue.main.async { [weak self] in
                self?.smoothedLevel = level
            }
        }
    }

    /// Reset levels when recording stops.
    func reset() {
        lock.lock()
        rawLevel = 0
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.smoothedLevel = 0
        }
    }
}

// MARK: - C-compatible callback for Rust FFI

/// Top-level function matching `void (*mic_cb)(float, float)`.
func kordMicLevelCallback(rms: Float, peak: Float) {
    AudioLevelBridge.shared.onAudioLevel(rms: rms, peak: peak)
}
