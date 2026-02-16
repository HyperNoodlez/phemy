import Foundation
import CKordCore
import os.log

private let kordLog = Logger(subsystem: "com.labgarge.kord", category: "FFI")

/// Swift wrapper around the Rust kord-core C FFI.
/// All complex types are exchanged as JSON strings over the C boundary.
final class KordCore {
    static let shared = KordCore()

    private init() {
        // Initialize Rust core with app data directory
        let dataDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("com.labgarge.kord")
            .path
        dataDir.withCString { ptr in
            _ = kord_init(ptr)
        }
    }

    // MARK: - FFI Helpers

    /// Shared decoder: Rust uses snake_case JSON keys, Swift uses camelCase properties.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Shared encoder: Convert Swift camelCase back to Rust snake_case.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    /// Read a C string returned by Rust, convert to Swift String, then free it.
    private func consumeRustString(_ ptr: UnsafeMutablePointer<CChar>?) -> String? {
        guard let ptr = ptr else { return nil }
        guard let str = String(validatingUTF8: ptr) else {
            kordLog.warning("Rust FFI returned invalid UTF-8 data")
            kord_free_string(ptr)
            return nil
        }
        kord_free_string(ptr)
        return str
    }

    /// Decode JSON from a Rust-returned C string.
    private func decodeRustJSON<T: Decodable>(_ ptr: UnsafeMutablePointer<CChar>?, as type: T.Type) -> T? {
        guard let json = consumeRustString(ptr),
              let data = json.data(using: .utf8) else { return nil }
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            kordLog.warning("Failed to decode \(String(describing: type)) from Rust JSON: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Settings

    func getSettings() -> AppSettings {
        let ptr = kord_get_settings()
        return decodeRustJSON(ptr, as: AppSettings.self) ?? .default
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? Self.encoder.encode(settings),
              let json = String(data: data, encoding: .utf8) else { return }
        json.withCString { ptr in
            _ = kord_save_settings(ptr)
        }
    }

    func resetSettings() -> AppSettings {
        let ptr = kord_reset_settings()
        return decodeRustJSON(ptr, as: AppSettings.self) ?? .default
    }

    // MARK: - Audio

    func listAudioDevices() -> [AudioDeviceInfo] {
        let ptr = kord_list_audio_devices()
        return decodeRustJSON(ptr, as: [AudioDeviceInfo].self) ?? []
    }

    func startRecording(device: String? = nil) -> Bool {
        if let device = device {
            return device.withCString { ptr in
                kord_start_recording(ptr, kordMicLevelCallback)
            }
        } else {
            return kord_start_recording(nil, kordMicLevelCallback)
        }
    }

    func stopRecording() -> String? {
        consumeRustString(kord_stop_recording())
    }

    enum StopAndProcessResult {
        case success(ProcessingResult)
        case failure(String)
    }

    /// Stop recording, transcribe, optimize, save to history, and return result.
    func stopAndProcess() -> StopAndProcessResult {
        let ptr = kord_stop_and_process()
        guard let json = consumeRustString(ptr),
              let data = json.data(using: .utf8) else {
            return .failure("No response from processing engine")
        }

        // Check if it's an error response
        if let errObj = try? Self.decoder.decode(ProcessingError.self, from: data),
           !errObj.error.isEmpty {
            return .failure(errObj.error)
        }

        // Try to decode as success
        if let result = try? Self.decoder.decode(ProcessingResult.self, from: data) {
            return .success(result)
        }

        return .failure("Failed to decode processing result: \(json)")
    }

    func isRecording() -> Bool {
        kord_get_recording_state()
    }

    // MARK: - Transcription

    func listWhisperModels() -> [WhisperModelInfo] {
        let ptr = kord_list_whisper_models()
        return decodeRustJSON(ptr, as: [WhisperModelInfo].self) ?? []
    }

    func downloadWhisperModel(name: String) -> Bool {
        name.withCString { ptr in
            kord_download_whisper_model(ptr)
        }
    }

    // MARK: - LLM

    func optimizePrompt(transcript: String) -> String? {
        let ptr = transcript.withCString { ptr in
            kord_optimize_prompt(ptr)
        }
        return consumeRustString(ptr)
    }

    // MARK: - Local LLM Models

    func listLlmModels() -> [LlmModelInfo] {
        let ptr = kord_list_llm_models()
        return decodeRustJSON(ptr, as: [LlmModelInfo].self) ?? []
    }

    func downloadLlmModel(name: String) -> Bool {
        name.withCString { ptr in
            kord_download_llm_model(ptr)
        }
    }

    func getLlmDownloadProgress() -> LlmDownloadProgress? {
        let ptr = kord_get_llm_download_progress()
        return decodeRustJSON(ptr, as: LlmDownloadProgress.self)
    }

    func deleteWhisperModel(name: String) -> Bool {
        name.withCString { ptr in
            kord_delete_whisper_model(ptr)
        }
    }

    func deleteLlmModel(name: String) -> Bool {
        name.withCString { ptr in
            kord_delete_llm_model(ptr)
        }
    }

    // MARK: - History

    func getHistory(limit: Int = 50, offset: Int = 0) -> [HistoryEntry] {
        let ptr = kord_get_history(Int32(limit), Int32(offset))
        return decodeRustJSON(ptr, as: [HistoryEntry].self) ?? []
    }

    func deleteHistoryEntry(id: String) -> Bool {
        id.withCString { ptr in
            kord_delete_history_entry(ptr)
        }
    }

    func clearHistory() -> Bool {
        kord_clear_history()
    }

    // MARK: - Clipboard

    func pasteText(_ text: String) -> Bool {
        text.withCString { ptr in
            kord_paste_text(ptr)
        }
    }
}

// MARK: - Supporting Types

struct AudioDeviceInfo: Identifiable, Codable {
    var name: String
    var isDefault: Bool
    var id: String { name }
}

struct ProcessingResult: Codable {
    var rawTranscript: String
    var optimizedPrompt: String
    var mode: String
    var durationSecs: Double
    var llmError: String?
}

private struct ProcessingError: Codable {
    var error: String
}

struct WhisperModelInfo: Identifiable, Codable {
    var name: String
    var sizeMb: Int
    var downloaded: Bool
    var id: String { name }
}

struct LlmModelInfo: Identifiable, Codable {
    var name: String
    var sizeMb: Int
    var downloaded: Bool
    var description: String
    var id: String { name }
}

struct LlmDownloadProgress: Codable {
    var model: String
    var downloadedBytes: Int
    var totalBytes: Int
    var progress: Double
}
