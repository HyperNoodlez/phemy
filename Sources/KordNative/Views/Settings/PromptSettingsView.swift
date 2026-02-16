import SwiftUI

struct PromptSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("Prompt Mode")
                .font(.title2.bold())

            Text("Choose how your voice transcript is processed before pasting.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PromptMode.allCases) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: vm.settings.promptMode == mode,
                        accentColor: theme.primary
                    ) {
                        vm.settings.promptMode = mode
                        vm.autoSave()
                    }
                }
            }

            // Custom prompt editor
            if vm.settings.promptMode == .custom {
                SettingsSection(title: "Custom System Prompt") {
                    TextEditor(text: Binding(
                        get: { vm.settings.customSystemPrompt ?? "" },
                        set: { vm.settings.customSystemPrompt = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.system(size: 13, design: .monospaced))
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.inputCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.inputCornerRadius)
                            .stroke(Color(.separatorColor), lineWidth: 0.5)
                    )
                    .onChange(of: vm.settings.customSystemPrompt) { vm.autoSave() }

                    Text("This prompt instructs the LLM how to process your transcript. Output should be the optimized prompt only.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
