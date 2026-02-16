import SwiftUI

struct LLMSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("LLM")
                .font(.title2.bold())

            SettingsSection(title: "Local Model") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.llmModels) { model in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(model.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text("\(model.sizeMb) MB")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if model.downloaded {
                                if vm.settings.localLlmModel == model.name {
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                } else {
                                    HStack(spacing: 8) {
                                        Button("Use") {
                                            vm.settings.localLlmModel = model.name
                                            vm.autoSave()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button {
                                            vm.deleteLlmModel(model.name)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.borderless)
                                        .controlSize(.small)
                                    }
                                }
                            } else if vm.isDownloadingLlmModel && vm.downloadingLlmModelName == model.name {
                                VStack(spacing: 4) {
                                    ProgressView(value: vm.llmDownloadProgress)
                                        .frame(width: 100)
                                    Text("\(Int(vm.llmDownloadProgress * 100))%")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button("Download") {
                                    vm.downloadLlmModel(model.name)
                                }
                                .disabled(vm.isDownloadingLlmModel)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            SettingsSection(title: "Performance") {
                Text("Expected ~30-50 tokens/sec on Apple Silicon. Prompt optimization typically completes in under 2 seconds.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
