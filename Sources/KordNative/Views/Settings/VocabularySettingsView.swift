import SwiftUI

struct VocabularySettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager
    @State private var newWord: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            Text("Vocabulary")
                .font(.title2.bold())

            Text("Add custom words to improve transcription accuracy for names, jargon, or technical terms.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            // Add word
            SettingsSection(title: "Add Word") {
                HStack(spacing: 8) {
                    TextField("Type a word or phrase...", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .onSubmit { addWord() }

                    Button {
                        addWord()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(theme.primary)
                }
            }

            // Word list
            SettingsSection(title: "Custom Words (\(vm.settings.vocabulary.count))") {
                if vm.settings.vocabulary.isEmpty {
                    Text("No custom words added yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(vm.settings.vocabulary, id: \.self) { word in
                            wordChip(word)
                        }
                    }
                }
            }
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !vm.settings.vocabulary.contains(trimmed) else { return }
        vm.settings.vocabulary.append(trimmed)
        vm.autoSave()
        newWord = ""
    }

    private func wordChip(_ word: String) -> some View {
        HStack(spacing: 4) {
            Text(word)
                .font(.system(size: 12))
            Button {
                vm.settings.vocabulary.removeAll { $0 == word }
                vm.autoSave()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.primary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
