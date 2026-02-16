import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, audio, transcription, llm, prompt, paste, vocabulary, history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .llm: return "LLM"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .general:       return "gearshape"
        case .audio:         return "mic"
        case .transcription: return "globe"
        case .llm:           return "brain"
        case .prompt:        return "text.bubble"
        case .paste:         return "doc.on.clipboard"
        case .vocabulary:    return "book"
        case .history:       return "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var theme: ThemeManager
    @State private var selectedTab: SettingsTab = .general
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App title + company logo
            VStack(alignment: .leading, spacing: 6) {
                Text("Phemy")
                    .font(.system(size: 18, weight: .semibold))
                if let url = Bundle.module.url(forResource: "CompanyLogo", withExtension: "png"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 14)
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Tab list
            ForEach(SettingsTab.allCases) { tab in
                sidebarRow(tab)
            }

            Spacer()

            // Version
            Text("v0.1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(minWidth: Spacing.sidebarWidth)
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                    .foregroundStyle(selectedTab == tab ? theme.primary : .secondary)
                Text(tab.label)
                    .font(.system(size: Spacing.sidebarFont))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Spacing.sidebarRowHeight)
            .padding(.horizontal, 16)
            .background(
                selectedTab == tab
                    ? theme.primary.opacity(0.12)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        ScrollView {
            Group {
                switch selectedTab {
                case .general:       GeneralSettingsView(vm: settingsVM)
                case .audio:         AudioSettingsView(vm: settingsVM)
                case .transcription: TranscriptionSettingsView(vm: settingsVM)
                case .llm:           LLMSettingsView(vm: settingsVM)
                case .prompt:        PromptSettingsView(vm: settingsVM)
                case .paste:         PasteSettingsView(vm: settingsVM)
                case .vocabulary:    VocabularySettingsView(vm: settingsVM)
                case .history:       HistoryView(vm: settingsVM)
                }
            }
            .padding(Spacing.contentPadding)
        }
    }
}
