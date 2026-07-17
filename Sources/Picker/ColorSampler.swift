import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - Color sampling
//
// Custom freeze loupe (replaces NSColorSampler). Captures displays once (all, or
// only the one under the cursor), paints each frozen frame into a per-NSScreen
// overlay that owns mouse + keyboard, and samples pixels from those bitmaps
// while the cursor moves — so the label can show HEX / RGB / HSL / HSB from
// AppSettings. Requires Screen Recording.

@MainActor
final class ColorSampler {

    enum Start { case began, needsPermission }

    private struct Overlay {
        let window: NSWindow
        let view: LoupeOverlayView
        let screenFrame: CGRect
    }

    private var overlays: [Overlay] = []
    private var keyMonitor: Any?
    private var onResult: ((PickedColor?) -> Void)?
    private var frames: [FrozenFrame] = []
    private var formatProvider: () -> ColorDisplayFormat = { .hex }
    private var magnificationProvider: () -> Double = { PickShortcut.magnificationDefault }
    private var radiusProvider: () -> Double = { PickShortcut.loupeRadiusDefault }
    private var showPixelGridProvider: () -> Bool = { true }
    private var onMagnificationChange: ((Double) -> Void)?
    private var onRadiusChange: ((Double) -> Void)?
    private var onPresented: (() -> Void)?
    /// Called just before the overlay is removed, with the pick result (`nil` = cancel).
    /// Hosts that want to reopen the panel under the loupe (cancel path) should do it here.
    private var onWillDismiss: ((PickedColor?) -> Void)?
    private var currentColor: PickedColor?
    private var magnification: Double = PickShortcut.magnificationDefault
    private var loupeRadius: Double = PickShortcut.loupeRadiusDefault
    private var showPixelGrid = true

    var isSampling: Bool { !overlays.isEmpty }

    struct FrozenFrame {
        /// Screen frame in AppKit global coordinates (bottom-left origin).
        var screenFrame: CGRect
        var image: CGImage
        /// Backing-scale of the capture (pixels / points).
        var scale: CGFloat
    }

    /// Begins a freeze-loupe session. Returns `.needsPermission` when Screen
    /// Recording hasn't been granted yet (and triggers the system prompt).
    ///
    /// - Parameters:
    ///   - onPresented: Called once the overlay is on screen (hide the panel here).
    ///   - onWillDismiss: Called just before the overlay is removed, with the pick
    ///     result. Reveal the panel here on cancel (when it was open) so tearing
    ///     down the loupe does not flash the live desktop; leave it closed on a
    ///     successful pick.
    func start(
        freezeScope: FreezeScope,
        formatProvider: @escaping () -> ColorDisplayFormat,
        magnificationProvider: @escaping () -> Double,
        radiusProvider: @escaping () -> Double,
        showPixelGridProvider: @escaping () -> Bool,
        onMagnificationChange: @escaping (Double) -> Void,
        onRadiusChange: @escaping (Double) -> Void,
        onPresented: @escaping () -> Void,
        onWillDismiss: @escaping (PickedColor?) -> Void,
        onResult: @escaping (PickedColor?) -> Void
    ) async -> Start {
        guard ensureScreenAccess() else { return .needsPermission }
        guard !isSampling else { return .began }

        do {
            let captured = try await Self.captureDisplays(scope: freezeScope)
            guard !captured.isEmpty else { return .needsPermission }
            self.formatProvider = formatProvider
            self.magnificationProvider = magnificationProvider
            self.radiusProvider = radiusProvider
            self.showPixelGridProvider = showPixelGridProvider
            self.onMagnificationChange = onMagnificationChange
            self.onRadiusChange = onRadiusChange
            self.onPresented = onPresented
            self.onWillDismiss = onWillDismiss
            self.magnification = AppSettings.clampMagnification(magnificationProvider())
            self.loupeRadius = AppSettings.clampLoupeRadius(radiusProvider())
            self.showPixelGrid = showPixelGridProvider()
            self.onResult = onResult
            self.frames = captured
            present()
            return .began
        } catch {
            _ = CGRequestScreenCaptureAccess()
            return .needsPermission
        }
    }

    func cancel() { finish(nil) }

    // MARK: Permission

    private func ensureScreenAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        _ = CGRequestScreenCaptureAccess()
        return false
    }

    // MARK: Capture

    private static func captureDisplays(scope: FreezeScope) async throws -> [FrozenFrame] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        // Keep our panel out of the freeze so we can capture while it's still
        // visible — avoids a desktop flash between hide and overlay.
        let excluded = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let displays: [SCDisplay]
        switch scope {
        case .allDisplays:
            displays = content.displays
        case .cursorDisplay:
            let point = NSEvent.mouseLocation
            let screen =
                NSScreen.screens.first { $0.frame.contains(point) }
                ?? NSScreen.main
            let targetID = displayID(for: screen)
            if let targetID, let match = content.displays.first(where: { $0.displayID == targetID })
            {
                displays = [match]
            } else if let first = content.displays.first {
                displays = [first]
            } else {
                displays = []
            }
        }

        var frames: [FrozenFrame] = []
        for display in displays {
            let filter = SCContentFilter(
                display: display, excludingApplications: excluded, exceptingWindows: [])
            let scale = scaleForDisplay(display)
            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * scale)
            config.height = Int(CGFloat(display.height) * scale)
            config.showsCursor = false
            config.capturesAudio = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: config)
            let screenFrame = screenFrame(for: display)
            frames.append(
                FrozenFrame(screenFrame: screenFrame, image: image, scale: scale))
        }
        return frames
    }

    private static func displayID(for screen: NSScreen?) -> CGDirectDisplayID? {
        guard let screen,
            let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
        else { return nil }
        return CGDirectDisplayID(num.uint32Value)
    }

    private static func scaleForDisplay(_ display: SCDisplay) -> CGFloat {
        for screen in NSScreen.screens {
            if displayID(for: screen) == display.displayID {
                return screen.backingScaleFactor
            }
        }
        return NSScreen.main?.backingScaleFactor ?? 2
    }

    /// AppKit global frame for an SCDisplay (bottom-left origin).
    private static func screenFrame(for display: SCDisplay) -> CGRect {
        for screen in NSScreen.screens {
            if displayID(for: screen) == display.displayID {
                return screen.frame
            }
        }
        let q = display.frame
        let primaryH =
            NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? NSScreen.main?.frame.height ?? q.height
        return CGRect(
            x: q.origin.x,
            y: primaryH - q.origin.y - q.height,
            width: q.width,
            height: q.height)
    }

    // MARK: Overlay lifecycle

    private func present() {
        let cursor = NSEvent.mouseLocation
        var built: [Overlay] = []

        for frame in frames {
            let win = NSWindow(
                contentRect: frame.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false)
            win.isOpaque = true
            win.backgroundColor = .black
            win.hasShadow = false
            win.level = .screenSaver
            win.ignoresMouseEvents = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.acceptsMouseMovedEvents = true

            let v = LoupeOverlayView(frame: CGRect(origin: .zero, size: frame.screenFrame.size))
            v.screenFrame = frame.screenFrame
            v.magnification = magnification
            v.loupeRadius = loupeRadius
            v.showPixelGrid = showPixelGrid
            v.onMove = { [weak self] global in self?.refresh(atAppKit: global) }
            v.onCommit = { [weak self] in self?.commit() }
            v.onCancel = { [weak self] in self?.cancel() }
            v.onKey = { [weak self] event in self?.handleKey(event) ?? false }
            win.contentView = v
            v.setAccessibilityElement(false)

            built.append(Overlay(window: win, view: v, screenFrame: frame.screenFrame))
        }

        // Freeze overlay must become the key app/window so Esc / − / = are delivered
        // to us (and can be consumed). Global key monitors cannot swallow events, and
        // an accessory app that never activates never receives local key monitors —
        // keystrokes would land in whatever text field was focused before. The screen
        // is already frozen, so briefly activating is safe.
        NSApp.activate(ignoringOtherApps: true)

        let keyOverlay =
            built.first { $0.screenFrame.contains(cursor) }
            ?? built.first
        for overlay in built {
            if overlay.window === keyOverlay?.window {
                overlay.window.makeKeyAndOrderFront(nil)
                overlay.window.makeFirstResponder(overlay.view)
            } else {
                overlay.window.orderFront(nil)
            }
        }

        overlays = built
        installKeyMonitor()
        NSCursor.crosshair.set()

        refresh(atAppKit: cursor)
        onPresented?()
    }

    private func finish(_ color: PickedColor?) {
        // Let the host reopen the panel under the loupe (typically on cancel) before
        // the overlay goes away — otherwise the live desktop flashes through.
        onWillDismiss?(color)

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        NSCursor.arrow.set()
        for overlay in overlays {
            overlay.window.orderOut(nil)
        }
        overlays = []
        frames = []
        currentColor = nil
        formatProvider = { .hex }
        magnificationProvider = { PickShortcut.magnificationDefault }
        radiusProvider = { PickShortcut.loupeRadiusDefault }
        showPixelGridProvider = { true }
        onMagnificationChange = nil
        onRadiusChange = nil
        onPresented = nil
        onWillDismiss = nil
        let callback = onResult
        onResult = nil
        callback?(color)
    }

    /// Local monitor only — requires us to be the active/key app (see present()).
    /// Consumes every keyDown so nothing leaks to the previously focused field.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            _ = self?.handleKey(event)
            return nil
        }
    }

    /// Returns true when the key mapped to a loupe action.
    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        switch Int(event.keyCode) {
        case 53:  // Esc
            cancel()
            return true
        case 27, 78:  // "-" / keypad minus
            if command {
                nudgeLoupeRadius(-PickShortcut.loupeRadiusStep)
            } else {
                nudgeMagnification(-PickShortcut.magnificationStep)
            }
            return true
        case 24, 69:  // "=" / keypad plus (`+` is Shift+=, same keyCode 24)
            if command {
                nudgeLoupeRadius(PickShortcut.loupeRadiusStep)
            } else {
                nudgeMagnification(PickShortcut.magnificationStep)
            }
            return true
        default:
            return false
        }
    }

    private func nudgeMagnification(_ delta: Double) {
        let next = AppSettings.clampMagnification(magnification + delta)
        guard next != magnification else { return }
        magnification = next
        onMagnificationChange?(next)
        for overlay in overlays {
            overlay.view.magnification = next
            overlay.view.needsDisplay = true
        }
    }

    private func nudgeLoupeRadius(_ delta: Double) {
        let next = AppSettings.clampLoupeRadius(loupeRadius + delta)
        guard next != loupeRadius else { return }
        loupeRadius = next
        onRadiusChange?(next)
        for overlay in overlays {
            overlay.view.loupeRadius = next
            overlay.view.needsDisplay = true
        }
    }

    // MARK: Sample / commit

    private func refresh(atAppKit point: CGPoint) {
        // Keep key window on the screen under the cursor so Esc / − / = stay delivered.
        if let target = overlays.first(where: { $0.screenFrame.contains(point) }),
            target.window !== NSApp.keyWindow
        {
            target.window.makeKey()
            target.window.makeFirstResponder(target.view)
        }

        guard let color = Self.color(at: point, in: frames) else {
            currentColor = nil
            for overlay in overlays {
                overlay.view.update(
                    cursor: point, color: nil, label: nil, frames: frames)
            }
            return
        }
        currentColor = color
        let label = color.string(for: formatProvider())
        for overlay in overlays {
            overlay.view.update(
                cursor: point, color: color, label: label, frames: frames)
        }
    }

    private func commit() {
        finish(currentColor)
    }

    /// Sample one pixel from the frozen frame that contains `point` (AppKit global).
    static func color(at point: CGPoint, in frames: [FrozenFrame]) -> PickedColor? {
        guard
            let frame = frames.first(where: { $0.screenFrame.contains(point) })
        else { return nil }

        let localX = (point.x - frame.screenFrame.minX) * frame.scale
        let localY = (frame.screenFrame.maxY - point.y) * frame.scale
        let px = Int(localX.rounded(.down))
        let py = Int(localY.rounded(.down))
        guard px >= 0, py >= 0, px < frame.image.width, py < frame.image.height else {
            return nil
        }
        guard let ns = pixelColor(in: frame.image, x: px, y: py) else { return nil }
        return PickedColor(nsColor: ns)
    }

    private static func pixelColor(in image: CGImage, x: Int, y: Int) -> NSColor? {
        guard let provider = image.dataProvider, let data = provider.data else { return nil }
        let ptr = CFDataGetBytePtr(data)
        let bytesPerPixel = max(image.bitsPerPixel / 8, 1)
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel
        let length = CFDataGetLength(data)
        guard offset + 2 < length else { return nil }

        // ScreenCaptureKit typically delivers BGRA.
        let alphaInfo = image.alphaInfo
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst:
            // BGRA
            b = CGFloat(ptr![offset]) / 255
            g = CGFloat(ptr![offset + 1]) / 255
            r = CGFloat(ptr![offset + 2]) / 255
        default:
            // RGBA
            r = CGFloat(ptr![offset]) / 255
            g = CGFloat(ptr![offset + 1]) / 255
            b = CGFloat(ptr![offset + 2]) / 255
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Overlay view

@MainActor
final class LoupeOverlayView: NSView {
    private(set) var cursorPoint: CGPoint = .zero
    private var color: PickedColor?
    private var label: String?
    private var frames: [ColorSampler.FrozenFrame] = []
    private var tracking: NSTrackingArea?

    /// AppKit global frame of the screen this view covers.
    var screenFrame: CGRect = .zero

    var onMove: ((CGPoint) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onKey: ((NSEvent) -> Bool)?
    var magnification: CGFloat = PickShortcut.magnificationDefault
    var loupeRadius: CGFloat = PickShortcut.loupeRadiusDefault
    /// When false, skip the zoom-gated pixel boundary grid.
    var showPixelGrid = true

    /// Odd count so the hovered pixel stays centered in the loupe.
    private let gridCount = 11

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let options: NSTrackingArea.Options = [
            .activeAlways, .mouseMoved, .inVisibleRect, .cursorUpdate,
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    func update(
        cursor: CGPoint, color: PickedColor?, label: String?,
        frames: [ColorSampler.FrozenFrame]
    ) {
        self.cursorPoint = cursor
        self.color = color
        self.label = label
        self.frames = frames
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        onMove?(NSEvent.mouseLocation)
        NSCursor.crosshair.set()
    }

    override func mouseDragged(with event: NSEvent) {
        onMove?(NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        onCommit?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        if onKey?(event) != true {
            // Still swallow — never forward into the previously focused app.
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        // NSImage.draw respects AppKit orientation — raw CGContext.draw + a manual
        // Y-flip was mirroring the freeze frame on ScreenCaptureKit bitmaps.
        for frame in frames where frame.screenFrame == screenFrame {
            let local = CGRect(origin: .zero, size: bounds.size)
            let ns = NSImage(cgImage: frame.image, size: local.size)
            ns.draw(
                in: local, from: .zero, operation: .copy, fraction: 1.0,
                respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        }

        guard screenFrame.contains(cursorPoint) else { return }
        let localCursor = CGPoint(
            x: cursorPoint.x - screenFrame.minX,
            y: cursorPoint.y - screenFrame.minY)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawLoupe(in: ctx, at: localCursor)
        drawLabel(at: localCursor)
    }

    private func drawLoupe(in ctx: CGContext, at center: CGPoint) {
        let r = loupeRadius
        let loupeRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let srcSide = sourceSide()

        redrawMagnifiedContent(in: ctx, loupeRect: loupeRect, srcSide: srcSide)

        if showPixelGrid, magnification >= PickShortcut.pixelGridMinMagnification {
            drawPixelGrid(in: ctx, loupeRect: loupeRect, srcSide: srcSide)
        }

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: loupeRect.insetBy(dx: 1, dy: 1))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: loupeRect)

        let cell = loupeRect.width / srcSide
        let cross = cell
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: center.x - cross, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + cross, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - cross))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + cross))
        ctx.strokePath()

        let pixel = CGRect(
            x: center.x - cell / 2, y: center.y - cell / 2, width: cell, height: cell)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(pixel)
        ctx.restoreGState()

        if let color {
            let swatch = CGRect(x: center.x - 18, y: loupeRect.minY - 28, width: 36, height: 18)
            ctx.setFillColor(
                NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: 1).cgColor)
            let path = CGPath(
                roundedRect: swatch, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(path)
            ctx.strokePath()
        }
    }

    /// How many source pixels are packed into the loupe diameter at the current zoom.
    private func sourceSide() -> CGFloat {
        max(CGFloat(gridCount) * (12 / max(magnification, 1)), 3)
    }

    /// Magnified pixel patch inside the loupe circle. Source window shrinks as
    /// magnification rises so −/= visibly change zoom.
    private func redrawMagnifiedContent(in ctx: CGContext, loupeRect: CGRect, srcSide: CGFloat) {
        guard
            let frame = frames.first(where: { $0.screenFrame.contains(cursorPoint) })
        else { return }

        let half = srcSide / 2
        let srcX = (cursorPoint.x - frame.screenFrame.minX) * frame.scale - half
        let srcY = (frame.screenFrame.maxY - cursorPoint.y) * frame.scale - half
        guard
            let cropped = frame.image.cropping(
                to: CGRect(x: srcX, y: srcY, width: srcSide, height: srcSide))
        else { return }

        ctx.saveGState()
        ctx.addEllipse(in: loupeRect)
        ctx.clip()
        let ns = NSImage(cgImage: cropped, size: loupeRect.size)
        ns.draw(
            in: loupeRect, from: .zero, operation: .copy, fraction: 1.0,
            respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        ctx.restoreGState()
    }

    /// Hairline pixel boundaries — only from 8× up, when cells are large enough to read.
    private func drawPixelGrid(in ctx: CGContext, loupeRect: CGRect, srcSide: CGFloat) {
        let count = max(Int(srcSide.rounded()), 2)
        let step = loupeRect.width / CGFloat(count)

        ctx.saveGState()
        ctx.addEllipse(in: loupeRect)
        ctx.clip()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
        ctx.setLineWidth(1)
        for i in 1..<count {
            let offset = CGFloat(i) * step
            ctx.move(to: CGPoint(x: loupeRect.minX + offset, y: loupeRect.minY))
            ctx.addLine(to: CGPoint(x: loupeRect.minX + offset, y: loupeRect.maxY))
            ctx.move(to: CGPoint(x: loupeRect.minX, y: loupeRect.minY + offset))
            ctx.addLine(to: CGPoint(x: loupeRect.maxX, y: loupeRect.minY + offset))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawLabel(at center: CGPoint) {
        guard let label, !label.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: label, attributes: attrs)
        let size = text.size()
        let padX: CGFloat = 10
        let padY: CGFloat = 5
        let box = CGRect(
            x: center.x - (size.width + padX * 2) / 2,
            y: center.y - loupeRadius - 52,
            width: size.width + padX * 2,
            height: size.height + padY * 2)

        let path = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.72).setFill()
        path.fill()
        text.draw(at: CGPoint(x: box.minX + padX, y: box.minY + padY))
    }
}
