import SwiftUI
import Combine

final class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var audioDevices: [AudioDeviceInfo] = []
    @Published var whisperModels: [WhisperModelInfo] = []
    @Published var history: [HistoryEntry] = []
    @Published var isDownloadingModel = false
    @Published var downloadingModelName: String?

    // Local LLM model state
    @Published var llmModels: [LlmModelInfo] = []
    @Published var isDownloadingLlmModel = false
    @Published var downloadingLlmModelName: String?
    @Published var llmDownloadProgress: Double = 0

    private let core = PhemyCore.shared
    private var llmProgressTimer: Timer?

    init() {
        self.settings = PhemyCore.shared.getSettings()
        loadDevicesAndModels()
    }

    /// Notification posted when settings are saved. AppDelegate observes this to re-register hotkeys etc.
    static let settingsDidChange = Notification.Name("PhemySettingsDidChange")

    func save() {
        core.saveSettings(settings)
        NotificationCenter.default.post(name: Self.settingsDidChange, object: settings)
    }

    func resetToDefaults() {
        settings = core.resetSettings()
    }

    func loadDevicesAndModels() {
        audioDevices = core.listAudioDevices()
        whisperModels = core.listWhisperModels()
        loadLlmModels()
    }

    func loadHistory() {
        history = core.getHistory()
    }

    func deleteHistoryEntry(_ id: String) {
        _ = core.deleteHistoryEntry(id: id)
        history.removeAll { $0.id == id }
    }

    func clearHistory() {
        _ = core.clearHistory()
        history = []
    }

    func downloadWhisperModel(_ name: String) {
        guard !isDownloadingModel else { return }
        isDownloadingModel = true
        downloadingModelName = name

        Task.detached {
            let success = PhemyCore.shared.downloadWhisperModel(name: name)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isDownloadingModel = false
                self.downloadingModelName = nil
                if success {
                    self.whisperModels = self.core.listWhisperModels()
                }
            }
        }
    }

    // MARK: - Local LLM Models

    func loadLlmModels() {
        llmModels = core.listLlmModels()
    }

    func downloadLlmModel(_ name: String) {
        guard !isDownloadingLlmModel else { return }
        isDownloadingLlmModel = true
        downloadingLlmModelName = name
        llmDownloadProgress = 0

        // Poll for progress updates
        llmProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let progress = self.core.getLlmDownloadProgress() {
                self.llmDownloadProgress = progress.progress
            }
        }

        Task.detached {
            let success = PhemyCore.shared.downloadLlmModel(name: name)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.llmProgressTimer?.invalidate()
                self.llmProgressTimer = nil
                self.isDownloadingLlmModel = false
                self.downloadingLlmModelName = nil
                self.llmDownloadProgress = 0
                if success {
                    self.llmModels = self.core.listLlmModels()
                }
            }
        }
    }

    // MARK: - Delete Models

    func deleteWhisperModel(_ name: String) {
        let success = core.deleteWhisperModel(name: name)
        if success {
            whisperModels = core.listWhisperModels()
        }
    }

    func deleteLlmModel(_ name: String) {
        let success = core.deleteLlmModel(name: name)
        if success {
            llmModels = core.listLlmModels()
        }
    }

    // Auto-save helper: call from .onChange modifiers
    func autoSave() {
        save()
    }
}
