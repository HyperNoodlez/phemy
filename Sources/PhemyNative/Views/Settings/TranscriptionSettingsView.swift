import SwiftUI

struct TranscriptionSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    private var selectedModelDownloaded: Bool {
        vm.whisperModels.first(where: { $0.name == vm.settings.whisperModel })?.downloaded ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("Transcription")
                .font(.title2.bold())

            // Whisper model list
            SettingsSection(title: "Whisper Model") {
                ForEach(vm.whisperModels) { model in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.name.capitalized)
                                .font(.system(size: 13, weight: .medium))
                            Text("\(model.sizeMb) MB")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if model.downloaded {
                            if vm.settings.whisperModel == model.name {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.green)
                            } else {
                                HStack(spacing: 8) {
                                    Button("Use") {
                                        vm.settings.whisperModel = model.name
                                        vm.autoSave()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)

                                    Button {
                                        vm.deleteWhisperModel(model.name)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            }
                        } else if vm.isDownloadingModel && vm.downloadingModelName == model.name {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Download") {
                                vm.downloadWhisperModel(model.name)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(vm.isDownloadingModel)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !selectedModelDownloaded {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("The selected model '\(vm.settings.whisperModel)' is not downloaded. Download it or select a downloaded model.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Larger models are more accurate but slower. The 'base' model is recommended for most users.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Language
            SettingsSection(title: "Language") {
                LabeledField("Language Code") {
                    TextField("en", text: $vm.settings.language)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 80)
                        .onChange(of: vm.settings.language) { vm.autoSave() }
                }

                Text("ISO 639-1 code (e.g., en, es, fr, de, ja, zh)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
