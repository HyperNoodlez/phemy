import SwiftUI

struct PasteSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("Paste")
                .font(.title2.bold())

            // Paste method
            SettingsSection(title: "Method") {
                Picker("", selection: $vm.settings.pasteMethod) {
                    ForEach(PasteMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                .onChange(of: vm.settings.pasteMethod) { vm.autoSave() }

                Text("Cmd+V works for most apps. Use Cmd+Shift+V for plain text paste, or Type Out to simulate keystrokes.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Paste delay
            SettingsSection(title: "Delay") {
                LabeledField("Delay (ms)") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(vm.settings.pasteDelayMs) },
                                set: { vm.settings.pasteDelayMs = Int($0); vm.autoSave() }
                            ),
                            in: 0...500,
                            step: 10
                        )
                        .frame(maxWidth: 200)
                        .tint(theme.primary)

                        Text("\(vm.settings.pasteDelayMs) ms")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                Text("Delay before pasting, allowing focus to return to the target app.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            // Auto-submit
            SettingsSection(title: "Auto-Submit") {
                Toggle("Press Enter after pasting", isOn: $vm.settings.autoSubmit)
                    .toggleStyle(.switch)
                    .tint(theme.primary)
                    .onChange(of: vm.settings.autoSubmit) { vm.autoSave() }

                Text("Automatically press Enter/Return after pasting, useful for chat inputs.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
