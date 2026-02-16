import Foundation
import SwiftUI
import Combine

/// Orchestrates the recording workflow: idle → recording → processing → ready/error.
final class RecordingManager: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case ready
        case error
    }

    @Published var phase: Phase = .idle
    @Published var result: ProcessingResult?
    @Published var errorMessage: String?
    @Published var audioLevel: Float = 0
    /// Set to true when CGEvent tap fails due to missing Accessibility permission
    @Published var accessibilityDenied: Bool = false

    private let core = PhemyCore.shared
    private var audioLevelCancellable: AnyCancellable?

    // MARK: - Actions

    /// Toggle between idle/recording/processing (for toggle hotkey mode).
    func toggle() {
        switch phase {
        case .idle:
            startRecording()
        case .recording:
            stopAndProcess()
        case .ready, .error:
            dismiss()
        case .processing:
            break // ignore during processing
        }
    }

    /// Start recording audio.
    func startRecording() {
        guard phase == .idle else { return }

        let settings = core.getSettings()
        let success = core.startRecording(device: settings.inputDevice)

        if success {
            phase = .recording
            audioLevelCancellable = AudioLevelBridge.shared.$smoothedLevel
                .receive(on: DispatchQueue.main)
                .assign(to: \.audioLevel, on: self)
        } else {
            errorMessage = "Failed to start recording. Check microphone permissions."
            phase = .error
        }
    }

    /// Stop recording and process (transcribe + optimize).
    func stopAndProcess() {
        guard phase == .recording else { return }
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        AudioLevelBridge.shared.reset()
        audioLevel = 0
        phase = .processing

        let manager = self
        Task.detached {
            let result = PhemyCore.shared.stopAndProcess()

            await MainActor.run {
                switch result {
                case .success(let processingResult):
                    manager.result = processingResult
                    manager.phase = .ready
                case .failure(let errorMsg):
                    manager.errorMessage = errorMsg
                    manager.phase = .error
                    print("[RecordingManager] Error: \(errorMsg)")
                }
            }
        }
    }

    /// Paste the optimized prompt into the focused application.
    func paste() {
        guard phase == .ready, let result = result else { return }
        let text = result.optimizedPrompt
        dismiss()  // Hide panel first so focus returns to target app
        DispatchQueue.global(qos: .userInitiated).async {
            _ = PhemyCore.shared.pasteText(text)
        }
    }

    /// Copy the optimized prompt to clipboard without pasting.
    func copy() {
        guard let result = result else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.optimizedPrompt, forType: .string)
    }

    /// Dismiss the overlay and reset to idle.
    func dismiss() {
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil
        audioLevel = 0
        phase = .idle
        result = nil
        errorMessage = nil
    }
}
