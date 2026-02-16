import Foundation

struct HistoryEntry: Identifiable, Codable {
    var id: String
    var rawTranscript: String
    var optimizedPrompt: String?
    var promptMode: String
    var llmProvider: String?
    var durationSecs: Double
    var createdAt: String

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: createdAt) else {
                return createdAt
            }
            return Self.displayFormatter.string(from: date)
        }
        return Self.displayFormatter.string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
