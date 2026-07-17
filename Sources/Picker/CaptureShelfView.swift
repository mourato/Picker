import AppKit
import SwiftUI

// MARK: - Capture shelf
//
// Floating strip of swatches shown during a multi-pick loupe session. Click-through
// at the window level so picks still land on the loupe beneath.

struct CaptureShelfView: View {
    let colors: [PickedColor]
    let format: ColorDisplayFormat

    private let swatchSize: CGFloat = 22

    var body: some View {
        HStack(spacing: Space.sm) {
            ForEach(colors) { color in
                RoundedRectangle(cornerRadius: Radius.chip - 4, style: .continuous)
                    .fill(color.color)
                    .frame(width: swatchSize, height: swatchSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.chip - 4, style: .continuous)
                            .stroke(Hairline.onColor, lineWidth: 1)
                    )
                    .help(color.string(for: format))
            }

            if colors.count > 1 {
                Text("\(colors.count)")
                    .font(TypeScale.caption)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("\(colors.count) colors captured")
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().stroke(Hairline.medium, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(shelfAccessibilityLabel)
    }

    private var shelfAccessibilityLabel: String {
        let strings = colors.map { $0.string(for: format) }
        return strings.joined(separator: ", ")
    }
}

// MARK: - Shelf window host

@MainActor
final class CaptureShelfController {
    private var window: NSWindow?
    private var hosting: NSHostingView<CaptureShelfView>?
    private var screen: NSScreen?

    var isVisible: Bool { window != nil }

    func show(colors: [PickedColor], format: ColorDisplayFormat) {
        guard !colors.isEmpty else {
            hide()
            return
        }
        if window == nil {
            let hosting = NSHostingView(
                rootView: CaptureShelfView(colors: colors, format: format))
            let win = NSWindow(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.contentView = hosting
            self.hosting = hosting
            window = win
            win.orderFrontRegardless()
        } else {
            hosting?.rootView = CaptureShelfView(colors: colors, format: format)
            hosting?.invalidateIntrinsicContentSize()
        }
        position(at: NSEvent.mouseLocation)
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        hosting = nil
        screen = nil
    }

    /// Reposition only when the cursor crosses to another display.
    func followCursorIfScreenChanged(at point: CGPoint) {
        guard window != nil else { return }
        let next =
            NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.main
        guard let next, next !== screen else { return }
        screen = next
        position(on: next)
    }

    private func position(at point: CGPoint) {
        let next =
            NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.main
        guard let next else { return }
        screen = next
        position(on: next)
    }

    private func position(on screen: NSScreen) {
        guard let hosting, let window else { return }
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let vf = screen.visibleFrame
        let margin: CGFloat = 24
        var x = vf.midX - size.width / 2
        let y = vf.minY + margin
        x = min(max(vf.minX + margin, x), vf.maxX - size.width - margin)
        window.setFrame(
            NSRect(x: x, y: y, width: max(size.width, 1), height: max(size.height, 1)),
            display: true)
    }
}

#Preview("Two colors") {
    CaptureShelfView(
        colors: [
            PickedColor(r: 0.9, g: 0.2, b: 0.15),
            PickedColor(r: 0.15, g: 0.45, b: 0.85),
        ],
        format: .hex
    )
    .padding()
}

#Preview("Three colors") {
    CaptureShelfView(
        colors: [
            PickedColor(r: 0.2, g: 0.8, b: 0.4),
            PickedColor(r: 0.95, g: 0.75, b: 0.1),
            PickedColor(r: 0.5, g: 0.2, b: 0.7),
        ],
        format: .rgb
    )
    .padding()
}
