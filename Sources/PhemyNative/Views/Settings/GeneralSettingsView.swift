import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("General")
                .font(.title2.bold())

            // Accent Color
            SettingsSection(title: "Accent Color") {
                AccentColorPicker()
            }

            // Appearance
            SettingsSection(title: "Appearance") {
                LabeledField("Theme") {
                    Picker("", selection: $vm.settings.theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                    .onChange(of: vm.settings.theme) {
                        theme.selectTheme(vm.settings.theme)
                        vm.autoSave()
                    }
                }
            }

            // Hotkey
            SettingsSection(title: "Hotkey") {
                LabeledField("Shortcut") {
                    HotkeyRecorder(hotkey: $vm.settings.hotkey, accentColor: theme.primary) {
                        vm.autoSave()
                    }
                }

                LabeledField("Mode") {
                    Picker("", selection: $vm.settings.hotkeyMode) {
                        ForEach(HotkeyMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    .onChange(of: vm.settings.hotkeyMode) { vm.autoSave() }
                }
            }

            // Startup
            SettingsSection(title: "Startup") {
                Toggle("Launch Phemy at login", isOn: $vm.settings.launchAtStartup)
                    .toggleStyle(.switch)
                    .tint(theme.primary)
                    .onChange(of: vm.settings.launchAtStartup) { vm.autoSave() }
            }

            // Reset
            Button("Reset All Settings to Defaults") {
                vm.resetToDefaults()
            }
            .foregroundStyle(.red)
        }
    }
}

// MARK: - Reusable Section + Field

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Spacing.fieldGap) {
                content
            }
            .padding(Spacing.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.sectionCornerRadius))
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
            content
        }
    }
}
