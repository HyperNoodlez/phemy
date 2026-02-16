import SwiftUI

struct AudioSettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("Audio")
                .font(.title2.bold())

            SettingsSection(title: "Input Device") {
                Picker("", selection: Binding(
                    get: { vm.settings.inputDevice ?? "__default__" },
                    set: { vm.settings.inputDevice = $0 == "__default__" ? nil : $0; vm.autoSave() }
                )) {
                    Text("System Default").tag("__default__")
                    Divider()
                    ForEach(vm.audioDevices) { device in
                        HStack {
                            Text(device.name)
                            if device.isDefault {
                                Text("(Default)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(device.name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 360)

                Button {
                    vm.loadDevicesAndModels()
                } label: {
                    Label("Refresh Devices", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.primary)
                .font(.system(size: 12))
            }

            SettingsSection(title: "Tip") {
                Text("If you connect an external microphone, click Refresh Devices to update the list. The system default is used when no device is explicitly selected.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
