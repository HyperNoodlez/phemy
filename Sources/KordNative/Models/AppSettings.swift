import Foundation

enum PromptMode: String, CaseIterable, Identifiable, Codable {
    case clean, technical, formal, casual, code, verbatim, raw, custom

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var description: String {
        switch self {
        case .clean:     return "Remove filler words, fix grammar, preserve intent"
        case .technical: return "Precise technical terminology, clear requirements"
        case .formal:    return "Professional language, business-appropriate tone"
        case .casual:    return "Clean but conversational, friendly voice"
        case .code:      return "Structured coding task with language and requirements"
        case .verbatim:  return "Minimal cleanup, closest to original wording"
        case .raw:       return "No LLM processing, use transcript as-is"
        case .custom:    return "Use your own custom system prompt"
        }
    }

    var icon: String {
        switch self {
        case .clean:     return "sparkles"
        case .technical: return "wrench.and.screwdriver"
        case .formal:    return "briefcase"
        case .casual:    return "face.smiling"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .verbatim:  return "text.quote"
        case .raw:       return "waveform"
        case .custom:    return "slider.horizontal.3"
        }
    }
}

enum PasteMethod: String, CaseIterable, Identifiable, Codable {
    case ctrlV = "ctrl-v"
    case ctrlShiftV = "ctrl-shift-v"
    case shiftInsert = "shift-insert"
    case typeOut = "type-out"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ctrlV:       return "Cmd+V"
        case .ctrlShiftV:  return "Cmd+Shift+V"
        case .shiftInsert: return "Shift+Insert"
        case .typeOut:     return "Type Out"
        }
    }
}

enum HotkeyMode: String, CaseIterable, Identifiable, Codable {
    case toggle
    case pushToTalk = "push-to-talk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggle:      return "Toggle"
        case .pushToTalk:  return "Push to Talk"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct AppSettings: Codable {
    // Audio
    var inputDevice: String?

    // Transcription
    var whisperModel: String
    var language: String

    // LLM
    var promptMode: PromptMode
    var customSystemPrompt: String?
    var localLlmModel: String?

    // Paste
    var pasteMethod: PasteMethod
    var pasteDelayMs: Int
    var autoSubmit: Bool

    // Hotkey
    var hotkey: String
    var hotkeyMode: HotkeyMode

    // General
    var theme: AppTheme
    var launchAtStartup: Bool

    // Vocabulary
    var vocabulary: [String]

    static let `default` = AppSettings(
        inputDevice: nil,
        whisperModel: "base",
        language: "en",
        promptMode: .clean,
        customSystemPrompt: nil,
        localLlmModel: "qwen3-4b-instruct-q4km",
        pasteMethod: .ctrlV,
        pasteDelayMs: 100,
        autoSubmit: false,
        hotkey: "Alt+Space",
        hotkeyMode: .toggle,
        theme: .system,
        launchAtStartup: false,
        vocabulary: []
    )
}
