import AppKit
import SwiftUI

// MARK: - Color value semantics
//
// One sampled pixel, reduced to its sRGB truth. We store normalized components
// (0...1) rather than a hex string so every format — hex, rgb, hsl — derives
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
