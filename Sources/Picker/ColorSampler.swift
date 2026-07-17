import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - Color sampling
//
// Custom freeze loupe (replaces NSColorSampler). Captures every display once,
// paints the frozen frames into a full-screen overlay that owns the mouse, and
// samples pixels from those bitmaps while the cursor moves — so the label can
// show HEX / RGB / HSL / HSB from AppSettings. Requires Screen Recording only
// (no event tap / Accessibility): the overlay is opaque and receives clicks.

@MainActor
final class ColorSampler {

    enum Start { case began, needsPermission }

    private var window: NSWindow?
    private var view: LoupeOverlayView?
    private var escMonitors: [Any] = []
    private var onResult: ((PickedColor?) -> Void)?
    private var frames: [FrozenFrame] = []
    private var formatProvider: () -> ColorDisplayFormat = { .hex }
    private var magnificationProvider: () -> Double = { PickShortcut.magnificationDefault }
    private var onMagnificationChange: ((Double) -> Void)?
    private var currentColor: PickedColor?
    private var magnification: Double = PickShortcut.magnificationDefault

    var isSampling: Bool { window != nil }

    struct FrozenFrame {
        /// Screen frame in AppKit global coordinates (bottom-left origin).
        var screenFrame: CGRect
        var image: CGImage
        /// Backing-scale of the capture (pixels / points).
        var scale: CGFloat
    }

    /// Begins a freeze-loupe session. Returns `.needsPermission` when Screen
    /// Recording hasn't been granted yet (and triggers the system prompt).
    func start(
        formatProvider: @escaping () -> ColorDisplayFormat,
        magnificationProvider: @escaping () -> Double,
        onMagnificationChange: @escaping (Double) -> Void,
        onResult: @escaping (PickedColor?) -> Void
    ) async -> Start {
        guard ensureScreenAccess() else { return .needsPermission }
        guard !isSampling else { return .began }

        do {
            let captured = try await Self.captureAllDisplays()
            guard !captured.isEmpty else { return .needsPermission }
            self.formatProvider = formatProvider
            self.magnificationProvider = magnificationProvider
            self.onMagnificationChange = onMagnificationChange
            self.magnification = AppSettings.clampMagnification(magnificationProvider())
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

    private static func captureAllDisplays() async throws -> [FrozenFrame] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        var frames: [FrozenFrame] = []

        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingWindows: [])
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

    private static func scaleForDisplay(_ display: SCDisplay) -> CGFloat {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber,
                CGDirectDisplayID(num.uint32Value) == display.displayID
            {
                return screen.backingScaleFactor
            }
        }
        return NSScreen.main?.backingScaleFactor ?? 2
    }

    /// AppKit global frame for an SCDisplay (bottom-left origin).
    private static func screenFrame(for display: SCDisplay) -> CGRect {
        for screen in NSScreen.screens {
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber,
                CGDirectDisplayID(num.uint32Value) == display.displayID
            {
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
        let frame = Self.unionFrame()
        let win = NSWindow(
            contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = true
        win.backgroundColor = .black
        win.hasShadow = false
        win.level = .screenSaver
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.acceptsMouseMovedEvents = true

        let v = LoupeOverlayView(frame: CGRect(origin: .zero, size: frame.size))
        v.magnification = magnification
        v.onMove = { [weak self] global in self?.refresh(atAppKit: global) }
        v.onCommit = { [weak self] in self?.commit() }
        v.onCancel = { [weak self] in self?.cancel() }
        win.contentView = v
        v.setAccessibilityElement(false)
        win.orderFrontRegardless()
        // Become key so we receive mouse-moved and Esc without activating other apps'
        // focus permanently — the panel is non-activating; this window is temporary.
        win.makeKey()

        window = win
        view = v
        installKeyMonitors()
        NSCursor.crosshair.set()

        refresh(atAppKit: NSEvent.mouseLocation)
    }

    private func finish(_ color: PickedColor?) {
        escMonitors.forEach { NSEvent.removeMonitor($0) }
        escMonitors = []
        NSCursor.arrow.set()
        window?.orderOut(nil)
        window = nil
        view = nil
        frames = []
        currentColor = nil
        formatProvider = { .hex }
        magnificationProvider = { PickShortcut.magnificationDefault }
        onMagnificationChange = nil
        let callback = onResult
        onResult = nil
        callback?(color)
    }

    private func installKeyMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleKey(event) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if self?.handleKey(event) == true { return nil }
            return event
        }
        escMonitors = [global, local].compactMap { $0 }
    }

    /// Returns true when the key was handled (and should be consumed locally).
    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 53:  // Esc
            cancel()
            return true
        case 27, 78:  // "-" / keypad minus
            nudgeMagnification(-PickShortcut.magnificationStep)
            return true
        case 24, 69:  // "=" / keypad plus (`+` is Shift+=, same keyCode 24)
            nudgeMagnification(PickShortcut.magnificationStep)
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
        view?.magnification = next
        view?.needsDisplay = true
    }

    // MARK: Sample / commit

    private func refresh(atAppKit point: CGPoint) {
        guard let color = Self.color(at: point, in: frames) else {
            currentColor = nil
            view?.update(cursor: point, color: nil, label: nil, frames: frames)
            return
        }
        currentColor = color
        view?.update(
            cursor: point,
            color: color,
            label: color.string(for: formatProvider()),
            frames: frames)
    }

    private func commit() {
        finish(currentColor)
    }

    /// Sample one pixel from the frozen frame that contains `point` (AppKit global).
    static func color(at point: CGPoint, in frames: [FrozenFrame]) -> PickedColor? {
        guard
            let frame = frames.first(where: { $0.screenFrame.contains(point) })
                ?? frames.first
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

    private static func unionFrame() -> CGRect {
        NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
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

    var onMove: ((CGPoint) -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var magnification: CGFloat = PickShortcut.magnificationDefault

    private let loupeRadius: CGFloat = 72
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

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(bounds)

        guard let win = window else { return }
        for frame in frames {
            let local = convert(win.convertFromScreen(frame.screenFrame), from: nil)
            ctx.saveGState()
            // CGImage is top-left; flip vertically into AppKit coords.
            ctx.translateBy(x: local.minX, y: local.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(frame.image, in: CGRect(origin: .zero, size: local.size))
            ctx.restoreGState()
        }

        let localCursor = convert(win.convertPoint(fromScreen: cursorPoint), from: nil)
        drawLoupe(in: ctx, at: localCursor)
        drawLabel(at: localCursor)
    }

    private func drawLoupe(in ctx: CGContext, at center: CGPoint) {
        let r = loupeRadius
        let loupeRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        ctx.saveGState()
        ctx.addEllipse(in: loupeRect)
        ctx.clip()

        if let frame = frames.first(where: { $0.screenFrame.contains(cursorPoint) })
            ?? frames.first
        {
            let half = CGFloat(gridCount) / 2
            let srcSide = CGFloat(gridCount)
            let srcX = (cursorPoint.x - frame.screenFrame.minX) * frame.scale - half
            let srcY = (frame.screenFrame.maxY - cursorPoint.y) * frame.scale - half
            if let cropped = frame.image.cropping(
                to: CGRect(x: srcX, y: srcY, width: srcSide, height: srcSide))
            {
                ctx.translateBy(x: loupeRect.midX, y: loupeRect.midY)
                ctx.scaleBy(x: magnification, y: -magnification)
                ctx.draw(
                    cropped,
                    in: CGRect(
                        x: -srcSide / 2, y: -srcSide / 2, width: srcSide, height: srcSide))
            }
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: loupeRect.insetBy(dx: 1, dy: 1))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: loupeRect)

        let cell = (r * 2) / CGFloat(gridCount)
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
