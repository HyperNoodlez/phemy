import SwiftUI

struct AccentColorPicker: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AccentPreset.allCases) { preset in
                Button {
                    theme.select(preset)
                } label: {
                    ZStack {
                        Circle()
                            .fill(preset.primary)
                            .frame(width: 36, height: 36)

                        if theme.current == preset {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(preset.displayName)
            }
        }
    }
}
