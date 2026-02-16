import Foundation
import Carbon

/// Manages system-wide global hotkey registration via the Carbon Event API.
/// Works even when the app is not focused.
final class GlobalHotkeyManager {
    typealias HotkeyAction = () -> Void

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Called when the hotkey is pressed.
    var onPress: HotkeyAction?
    /// Called when the hotkey is released (used for push-to-talk mode).
    var onRelease: HotkeyAction?

    fileprivate static var instance: GlobalHotkeyManager?

    init() {
        GlobalHotkeyManager.instance = self
    }

    deinit {
        unregister()
        GlobalHotkeyManager.instance = nil
    }

    // MARK: - Registration

    /// Register a global hotkey from a string like "Alt+Space", "Ctrl+Shift+R", etc.
    func register(hotkey: String) {
        unregister()

        guard let parsed = Self.parseHotkey(hotkey) else {
            print("[GlobalHotkeyManager] Failed to parse hotkey: \(hotkey)")
            return
        }

        // Install Carbon event handler for hotkey press/release
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            eventTypes.count,
            &eventTypes,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else {
            print("[GlobalHotkeyManager] Failed to install event handler: \(status)")
            return
        }

        // Register the hotkey
        let hotkeyID = EventHotKeyID(signature: fourCharCode("KORD"), id: 1)
        let regStatus = RegisterEventHotKey(
            parsed.keyCode,
            parsed.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if regStatus == noErr {
            print("[GlobalHotkeyManager] Registered hotkey: \(hotkey)")
        } else {
            print("[GlobalHotkeyManager] Failed to register hotkey: \(regStatus)")
        }
    }

    /// Unregister the current hotkey.
    func unregister() {
        if let ref_ = hotkeyRef {
            UnregisterEventHotKey(ref_)
            hotkeyRef = nil
        }
        if let ref_ = eventHandlerRef {
            RemoveEventHandler(ref_)
            eventHandlerRef = nil
        }
    }

    // MARK: - Event Handling

    fileprivate func handlePress() {
        onPress?()
    }

    fileprivate func handleRelease() {
        onRelease?()
    }

    // MARK: - Hotkey Parsing

    struct ParsedHotkey {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    static func parseHotkey(_ str: String) -> ParsedHotkey? {
        let parts = str.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !parts.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        var keyPart: String?

        for part in parts {
            switch part {
            case "alt", "option", "opt":
                modifiers |= UInt32(optionKey)
            case "cmd", "command", "meta":
                modifiers |= UInt32(cmdKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            default:
                keyPart = part
            }
        }

        guard let key = keyPart, let keyCode = carbonKeyCode(for: key) else {
            return nil
        }

        return ParsedHotkey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Map key names to Carbon virtual key codes.
    static func carbonKeyCode(for key: String) -> UInt32? {
        switch key {
        case "space":       return UInt32(kVK_Space)
        case "return", "enter": return UInt32(kVK_Return)
        case "tab":         return UInt32(kVK_Tab)
        case "escape", "esc": return UInt32(kVK_Escape)
        case "delete", "backspace": return UInt32(kVK_Delete)
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        case "f1": return UInt32(kVK_F1)
        case "f2": return UInt32(kVK_F2)
        case "f3": return UInt32(kVK_F3)
        case "f4": return UInt32(kVK_F4)
        case "f5": return UInt32(kVK_F5)
        case "f6": return UInt32(kVK_F6)
        case "f7": return UInt32(kVK_F7)
        case "f8": return UInt32(kVK_F8)
        case "f9": return UInt32(kVK_F9)
        case "f10": return UInt32(kVK_F10)
        case "f11": return UInt32(kVK_F11)
        case "f12": return UInt32(kVK_F12)
        default: return nil
        }
    }
}

// MARK: - Carbon Event Handler (C function)

private func carbonHotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    let eventKind = GetEventKind(event)

    switch Int(eventKind) {
    case kEventHotKeyPressed:
        DispatchQueue.main.async {
            GlobalHotkeyManager.instance?.handlePress()
        }
    case kEventHotKeyReleased:
        DispatchQueue.main.async {
            GlobalHotkeyManager.instance?.handleRelease()
        }
    default:
        return OSStatus(eventNotHandledErr)
    }

    return noErr
}

// MARK: - Helper

private func fourCharCode(_ str: String) -> OSType {
    var result: OSType = 0
    for char in str.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}
