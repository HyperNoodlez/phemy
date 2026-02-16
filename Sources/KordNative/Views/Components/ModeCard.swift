import SwiftUI

struct ModeCard: View {
    let mode: PromptMode
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(accentColor)
                    }
                }

                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(mode.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(Spacing.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Spacing.inputCornerRadius)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color(.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.inputCornerRadius)
                    .stroke(
                        isSelected ? accentColor.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
