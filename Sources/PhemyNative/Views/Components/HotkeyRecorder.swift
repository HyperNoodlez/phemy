import SwiftUI

struct HotkeyRecorder: View {
    @Binding var hotkey: String
    var accentColor: Color = .accentColor
    var onChanged: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: modifierBinding) {
                ForEach(HotkeyModifier.allCases) { mod in
                    Text(mod.displayName).tag(mod.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            Text("+")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .medium))

            Picker("", selection: keyBinding) {
                ForEach(HotkeyKey.allGroups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.keys) { key in
                            Text(key.displayName).tag(key.rawValue)
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(width: 100)
        }
    }

    // MARK: - Parse / reconstruct hotkey string

    private var modifierBinding: Binding<String> {
        Binding(
            get: {
                let parts = hotkey.split(separator: "+").map(String.init)
                // Everything except the last part is the modifier
                if parts.count >= 2 {
                    return parts.dropLast().joined(separator: "+")
                }
                return HotkeyModifier.alt.rawValue
            },
            set: { newMod in
                let key = currentKey
                hotkey = "\(newMod)+\(key)"
                onChanged?()
            }
        )
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { currentKey },
            set: { newKey in
                let mod = currentModifier
                hotkey = "\(mod)+\(newKey)"
                onChanged?()
            }
        )
    }

    private var currentModifier: String {
        let parts = hotkey.split(separator: "+").map(String.init)
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: "+")
        }
        return HotkeyModifier.alt.rawValue
    }

    private var currentKey: String {
        let parts = hotkey.split(separator: "+").map(String.init)
        return parts.last ?? HotkeyKey.space.rawValue
    }
}

// MARK: - Modifier options

enum HotkeyModifier: String, CaseIterable, Identifiable {
    case ctrl = "Ctrl"
    case alt = "Alt"
    case shift = "Shift"
    case superKey = "Super"
    case ctrlAlt = "Ctrl+Alt"
    case ctrlShift = "Ctrl+Shift"
    case altShift = "Alt+Shift"
    case superShift = "Super+Shift"
    case ctrlAltShift = "Ctrl+Alt+Shift"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ctrl:         return "\u{2303} Control"
        case .alt:          return "\u{2325} Option"
        case .shift:        return "\u{21E7} Shift"
        case .superKey:     return "\u{2318} Command"
        case .ctrlAlt:      return "\u{2303}\u{2325} Control+Option"
        case .ctrlShift:    return "\u{2303}\u{21E7} Control+Shift"
        case .altShift:     return "\u{2325}\u{21E7} Option+Shift"
        case .superShift:   return "\u{2318}\u{21E7} Command+Shift"
        case .ctrlAltShift: return "\u{2303}\u{2325}\u{21E7} Ctrl+Opt+Shift"
        }
    }
}

// MARK: - Key options

struct HotkeyKeyGroup {
    let name: String
    let keys: [HotkeyKey]
}

enum HotkeyKey: String, Identifiable {
    // Special
    case space = "Space"
    case enter = "Enter"
    case tab = "Tab"
    case backspace = "Backspace"
    case delete = "Delete"
    // Arrows
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    // Letters
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F"
    case g = "G", h = "H", i = "I", j = "J", k = "K", l = "L"
    case m = "M", n = "N", o = "O", p = "P", q = "Q", r = "R"
    case s = "S", t = "T", u = "U", v = "V", w = "W", x = "X"
    case y = "Y", z = "Z"
    // Numbers
    case n0 = "0", n1 = "1", n2 = "2", n3 = "3", n4 = "4"
    case n5 = "5", n6 = "6", n7 = "7", n8 = "8", n9 = "9"
    // Function keys
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4"
    case f5 = "F5", f6 = "F6", f7 = "F7", f8 = "F8"
    case f9 = "F9", f10 = "F10", f11 = "F11", f12 = "F12"
    // Punctuation
    case minus = "-", equal = "=", leftBracket = "["
    case rightBracket = "]", backslash = "\\"
    case semicolon = ";", quote = "'"
    case grave = "`", comma = ",", period = ".", slash = "/"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .space:     return "\u{2423} Space"
        case .enter:     return "\u{21A9} Enter"
        case .tab:       return "\u{21E5} Tab"
        case .backspace: return "\u{232B} Backspace"
        case .delete:    return "\u{2326} Delete"
        case .up:        return "\u{2191} Up"
        case .down:      return "\u{2193} Down"
        case .left:      return "\u{2190} Left"
        case .right:     return "\u{2192} Right"
        default:         return rawValue
        }
    }

    static let allGroups: [HotkeyKeyGroup] = [
        HotkeyKeyGroup(name: "Special", keys: [.space, .enter, .tab, .backspace, .delete]),
        HotkeyKeyGroup(name: "Arrows", keys: [.up, .down, .left, .right]),
        HotkeyKeyGroup(name: "Letters", keys: [
            .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
            .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z
        ]),
        HotkeyKeyGroup(name: "Numbers", keys: [
            .n0, .n1, .n2, .n3, .n4, .n5, .n6, .n7, .n8, .n9
        ]),
        HotkeyKeyGroup(name: "Function Keys", keys: [
            .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12
        ]),
        HotkeyKeyGroup(name: "Punctuation", keys: [
            .minus, .equal, .leftBracket, .rightBracket, .backslash,
            .semicolon, .quote, .grave, .comma, .period, .slash
        ]),
    ]
}
