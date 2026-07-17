import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Color format preference
//
// Shared enum for loupe/hero display and clipboard-on-pick. All four formats
// still appear in the formats card; these prefs only pick the primary ones.

enum ColorDisplayFormat: String, CaseIterable, Codable, Identifiable {
    case hex
    case rgb
    case hsl
    case hsb

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hex: "HEX"
        case .rgb: "RGB"
        case .hsl: "HSL"
        case .hsb: "HSB"
        }
    }
}

// MARK: - Freeze loupe display scope
//
// Whether Pick a Color freezes every monitor or only the one under the cursor.
// All-displays uses one overlay window per NSScreen (multi-monitor safe).

enum FreezeScope: String, CaseIterable, Codable, Identifiable {
    case allDisplays
    case cursorDisplay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allDisplays: "All displays"
        case .cursorDisplay: "Display under cursor"
        }
    }
}

// MARK: - Color value semantics
//
// One sampled pixel, reduced to its sRGB truth. We store normalized components
// (0...1) rather than a hex string so every format — hex, rgb, hsl, hsb — derives
// from the same source and round-trips losslessly.

struct PickedColor: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let r: Double
    let g: Double
    let b: Double
    let sampledAt: Date

    init(r: Double, g: Double, b: Double, id: UUID = UUID(), sampledAt: Date = .now) {
        self.id = id
        self.r = r
        self.g = g
        self.b = b
        self.sampledAt = sampledAt
    }

    init?(nsColor: NSColor, sampledAt: Date = .now) {
        guard let c = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(
            r: Double(c.redComponent),
            g: Double(c.greenComponent),
            b: Double(c.blueComponent),
            sampledAt: sampledAt)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    var r255: Int { Int((r * 255).rounded()) }
    var g255: Int { Int((g * 255).rounded()) }
    var b255: Int { Int((b * 255).rounded()) }

    var hex: String { String(format: "#%02X%02X%02X", r255, g255, b255) }
    var rgbString: String { "rgb(\(r255), \(g255), \(b255))" }

    /// HSL, the way CSS reports it.
    var hsl: (h: Int, s: Int, l: Int) {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        let d = maxV - minV
        guard d != 0 else { return (0, 0, Int((l * 100).rounded())) }
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h /= 6
        return (Int((h * 360).rounded()), Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    var hslString: String { let v = hsl; return "hsl(\(v.h), \(v.s)%, \(v.l)%)" }

    /// HSB / HSV as CSS `hsb(h, s%, b%)`, from AppKit's device-HSB conversion.
    var hsb: (h: Int, s: Int, b: Int) {
        let c = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return (Int((h * 360).rounded()), Int((s * 100).rounded()), Int((br * 100).rounded()))
    }

    var hsbString: String { let v = hsb; return "hsb(\(v.h), \(v.s)%, \(v.b)%)" }

    func string(for format: ColorDisplayFormat) -> String {
        switch format {
        case .hex: hex
        case .rgb: rgbString
        case .hsl: hslString
        case .hsb: hsbString
        }
    }

    /// Whether black ink reads better than white over this color.
    ///
    /// Uses perceived (gamma-encoded) brightness — the classic YIQ weighting — not
    /// raw WCAG relative luminance. WCAG luminance over-weights green and treats
    /// pure red/blue as "light enough" for black text, which looks wrong; perceived
    /// brightness keeps white ink on reds, blues, and any genuinely dark tone, and
    /// only switches to black once the background is actually bright.
    var prefersDarkInk: Bool {
        let brightness = 0.299 * r + 0.587 * g + 0.114 * b
        return brightness >= 0.5
    }
}

// MARK: - Keyboard shortcut
//
// Carbon keyCode + modifiers for the global pick hotkey. Display uses the usual
// macOS glyphs (⌃⌥⇧⌘). Default is Control+Option+C.

struct PickShortcut: Equatable {
    var keyCode: UInt32
    /// Carbon modifier flags (`controlKey`, `optionKey`, `shiftKey`, `cmdKey`).
    var carbonModifiers: UInt32

    /// Default: ⌃⌥C
    static let `default` = PickShortcut(
        keyCode: 8,  // kVK_ANSI_C
        carbonModifiers: UInt32(controlKey | optionKey))

    static let magnificationMin: Double = 4
    static let magnificationMax: Double = 32
    static let magnificationStep: Double = 2
    static let magnificationDefault: Double = 12
    /// Zoom at which the loupe draws a pixel boundary grid.
    static let pixelGridMinMagnification: Double = 8

    static let loupeRadiusMin: Double = 48
    static let loupeRadiusMax: Double = 160
    static let loupeRadiusStep: Double = 8
    static let loupeRadiusDefault: Double = 72

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    /// True when the combo has at least one modifier (bare keys are rejected).
    var isValid: Bool {
        carbonModifiers
            & UInt32(controlKey | optionKey | shiftKey | cmdKey) != 0
    }

    static func from(nsEvent event: NSEvent) -> PickShortcut? {
        var mods: UInt32 = 0
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        let shortcut = PickShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
        guard shortcut.isValid else { return nil }
        // Reject pure modifier presses.
        let code = Int(event.keyCode)
        let modifierKeys: Set<Int> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        if modifierKeys.contains(code) { return nil }
        return shortcut
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "⇥"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 114: return "Help"
        case 115: return "↖"
        case 116: return "⇞"
        case 117: return "⌦"
        case 118: return "F4"
        case 119: return "↘"
        case 120: return "F2"
        case 121: return "⇟"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key\(keyCode)"
        }
    }
}

// MARK: - App settings
//
// Lightweight preferences. Mutated on the main actor; persists to UserDefaults
// unless `--demo` turns persistence off.

@MainActor
final class AppSettings: ObservableObject {
    /// Loupe label, hero card, and preferred highlight in the formats card.
    @Published var colorDisplayFormat: ColorDisplayFormat {
        didSet { persist() }
    }

    /// String written to the clipboard when a loupe pick commits.
    @Published var clipboardFormat: ColorDisplayFormat {
        didSet { persist() }
    }

    @Published var loupeMagnification: Double {
        didSet {
            let clamped = Self.clampMagnification(loupeMagnification)
            if clamped != loupeMagnification {
                loupeMagnification = clamped
                return
            }
            persist()
        }
    }

    @Published var loupeRadius: Double {
        didSet {
            let clamped = Self.clampLoupeRadius(loupeRadius)
            if clamped != loupeRadius {
                loupeRadius = clamped
                return
            }
            persist()
        }
    }

    @Published var pickShortcut: PickShortcut {
        didSet { persist() }
    }

    @Published var freezeScope: FreezeScope {
        didSet { persist() }
    }

    /// When true, the loupe draws pixel boundary lines from 8× zoom upward.
    @Published var showPixelGrid: Bool {
        didSet { persist() }
    }

    /// Fired after any persisted mutation so the host can re-register the hotkey.
    var onChange: (() -> Void)?

    /// When false, changes stay in memory only — used by `--demo`.
    var persistenceEnabled = true

    private let formatKey = "picker.colorDisplayFormat.v1"
    private let clipboardFormatKey = "picker.clipboardFormat.v1"
    private let magnificationKey = "picker.loupeMagnification.v1"
    private let loupeRadiusKey = "picker.loupeRadius.v1"
    private let freezeScopeKey = "picker.freezeScope.v1"
    private let showPixelGridKey = "picker.showPixelGrid.v1"
    private let shortcutKeyCodeKey = "picker.pickShortcut.keyCode.v1"
    private let shortcutModifiersKey = "picker.pickShortcut.modifiers.v1"

    init() {
        if let raw = UserDefaults.standard.string(forKey: formatKey),
            let format = ColorDisplayFormat(rawValue: raw)
        {
            colorDisplayFormat = format
        } else {
            colorDisplayFormat = .hex
        }

        if let raw = UserDefaults.standard.string(forKey: clipboardFormatKey),
            let format = ColorDisplayFormat(rawValue: raw)
        {
            clipboardFormat = format
        } else {
            clipboardFormat = .hex
        }

        let storedMag = UserDefaults.standard.object(forKey: magnificationKey) as? Double
        loupeMagnification = Self.clampMagnification(
            storedMag ?? PickShortcut.magnificationDefault)

        let storedRadius = UserDefaults.standard.object(forKey: loupeRadiusKey) as? Double
        loupeRadius = Self.clampLoupeRadius(storedRadius ?? PickShortcut.loupeRadiusDefault)

        if let raw = UserDefaults.standard.string(forKey: freezeScopeKey),
            let scope = FreezeScope(rawValue: raw)
        {
            freezeScope = scope
        } else {
            freezeScope = .allDisplays
        }

        if UserDefaults.standard.object(forKey: showPixelGridKey) != nil {
            showPixelGrid = UserDefaults.standard.bool(forKey: showPixelGridKey)
        } else {
            showPixelGrid = true
        }

        if UserDefaults.standard.object(forKey: shortcutKeyCodeKey) != nil {
            let code = UInt32(UserDefaults.standard.integer(forKey: shortcutKeyCodeKey))
            let mods = UInt32(UserDefaults.standard.integer(forKey: shortcutModifiersKey))
            let shortcut = PickShortcut(keyCode: code, carbonModifiers: mods)
            pickShortcut = shortcut.isValid ? shortcut : .default
        } else {
            pickShortcut = .default
        }
    }

    func nudgeMagnification(_ delta: Double) {
        loupeMagnification = Self.clampMagnification(loupeMagnification + delta)
    }

    func nudgeLoupeRadius(_ delta: Double) {
        loupeRadius = Self.clampLoupeRadius(loupeRadius + delta)
    }

    static func clampMagnification(_ value: Double) -> Double {
        let stepped =
            (value / PickShortcut.magnificationStep).rounded()
            * PickShortcut.magnificationStep
        return min(
            PickShortcut.magnificationMax,
            max(PickShortcut.magnificationMin, stepped))
    }

    static func clampLoupeRadius(_ value: Double) -> Double {
        let stepped =
            (value / PickShortcut.loupeRadiusStep).rounded() * PickShortcut.loupeRadiusStep
        return min(
            PickShortcut.loupeRadiusMax,
            max(PickShortcut.loupeRadiusMin, stepped))
    }

    private func persist() {
        if persistenceEnabled {
            UserDefaults.standard.set(colorDisplayFormat.rawValue, forKey: formatKey)
            UserDefaults.standard.set(clipboardFormat.rawValue, forKey: clipboardFormatKey)
            UserDefaults.standard.set(loupeMagnification, forKey: magnificationKey)
            UserDefaults.standard.set(loupeRadius, forKey: loupeRadiusKey)
            UserDefaults.standard.set(freezeScope.rawValue, forKey: freezeScopeKey)
            UserDefaults.standard.set(showPixelGrid, forKey: showPixelGridKey)
            UserDefaults.standard.set(Int(pickShortcut.keyCode), forKey: shortcutKeyCodeKey)
            UserDefaults.standard.set(
                Int(pickShortcut.carbonModifiers), forKey: shortcutModifiersKey)
        }
        onChange?()
    }
}

// MARK: - Store
//
// The picked-color history. Mutated only on the main actor; persists itself to
// UserDefaults as JSON on every change and pings `onChange` so the panel can
// resize to fit.

@MainActor
final class ColorStore: ObservableObject {
    @Published private(set) var colors: [PickedColor] = []

    /// Fired after any mutation so the host window can re-measure.
    var onChange: (() -> Void)?

    /// When false, changes stay in memory only — used by the `--demo` preview so
    /// seeded swatches never touch the user's real saved palette.
    var persistenceEnabled = true

    private let key = "picker.pickedColors.v1"
    private let limit = 60

    init() { load() }

    var latest: PickedColor? { colors.first }

    func add(_ color: PickedColor) {
        // Skip consecutive duplicates — re-grabbing the same pixel shouldn't pile up.
        if let first = colors.first, first.hex == color.hex {
            colors[0] = color
        } else {
            colors.insert(color, at: 0)
            if colors.count > limit { colors.removeLast(colors.count - limit) }
        }
        persist()
    }

    func remove(_ color: PickedColor) {
        colors.removeAll { $0.id == color.id }
        persist()
    }

    func clear() {
        colors.removeAll()
        persist()
    }

    private func persist() {
        if persistenceEnabled, let data = try? JSONEncoder().encode(colors) {
            UserDefaults.standard.set(data, forKey: key)
        }
        onChange?()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([PickedColor].self, from: data)
        else { return }
        colors = decoded
    }
}

// MARK: - System glue

enum Clipboard {
    static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}

enum Haptics {
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    static func confirm() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
