import SwiftUI

struct HistoryView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionGap) {
            HStack {
                Text("History")
                    .font(.title2.bold())
                Spacer()
                if !vm.history.isEmpty {
                    Button(role: .destructive) {
                        vm.clearHistory()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                }
            }

            if vm.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No history yet")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("Your transcription history will appear here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vm.history) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
        .onAppear { vm.loadHistory() }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if let provider = entry.llmProvider {
                    Text(provider)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(entry.promptMode)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray).opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                Button {
                    vm.deleteHistoryEntry(entry.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let optimized = entry.optimizedPrompt, !optimized.isEmpty {
                Text(optimized)
                    .font(.system(size: 13))
                    .lineLimit(3)
            } else {
                Text(entry.rawTranscript)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text("\(String(format: "%.1f", entry.durationSecs))s")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(Spacing.sectionPadding)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.inputCornerRadius))
    }
}
