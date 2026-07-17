import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

// MARK: - Shared UI state

@MainActor
final class AppState: ObservableObject {
    /// True while the freeze loupe is on screen. Drives the button's live state
    /// and tells the dismiss monitor to leave the panel open.
    @Published var isSampling = false

    /// True while the font-picking overlay is up.
    @Published var isPickingFont = false

    /// Transient toast payload (font grab, screen-recording gate, etc.). The token
    /// lets the same message fire twice in a row and still register as a change.
    struct Feedback: Equatable {
        var text: String
        var ok: Bool
        var token: Int
    }
    @Published var feedback: Feedback?
    private var feedbackCount = 0

    func say(_ text: String, ok: Bool) {
        feedbackCount += 1
        feedback = Feedback(text: text, ok: ok, token: feedbackCount)
    }

    /// Alias kept for call sites that are font-specific.
    func sayFont(_ text: String, ok: Bool) { say(text, ok: ok) }
}

// MARK: - Floating panel
//
// A borderless, non-activating panel so the glass face can hover beneath the
// menu-bar item without stealing focus from the app you're sampling from.

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - App delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ColorStore()
    let fonts = FontStore()
    let settings = AppSettings()
    let app = AppState()
    let fontPicker = FontPicker()
    let colorSampler = ColorSampler()
    let fontLoader = FontLoader()
    private let pickHotKey = GlobalHotKey()

    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var hosting: NSHostingController<PanelView>!
    private var globalMonitor: Any?
    private var isDemo = false
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Keep the process out of App Nap. A status-bar accessory with no ordinary
        // window is a prime candidate for suspension, which can swallow the first
        // click after the app has been idle. This keeps it responsive without
        // blocking system sleep.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Menu-bar panel stays responsive")

        setupStatusItem()
        setupPanel()
        store.onChange = { [weak self] in self?.resizeIfVisible() }
        fonts.onChange = { [weak self] in self?.resizeIfVisible() }
        settings.onChange = { [weak self] in self?.registerPickHotKey() }
        registerPickHotKey()

        // Dev affordance: `Picker --demo` seeds swatches and opens the panel so the
        // rendered UI can be inspected without clicking the menu-bar item.
        if CommandLine.arguments.contains("--demo") {
            isDemo = true
            store.persistenceEnabled = false
            fonts.persistenceEnabled = false
            settings.persistenceEnabled = false
            for (r, g, b) in [
                (0.286, 0.314, 0.875), (0.953, 0.451, 0.396),
                (0.290, 0.776, 0.612), (0.945, 0.769, 0.298),
                (0.553, 0.357, 0.969), (0.180, 0.690, 0.890),
                (0.937, 0.353, 0.580), (0.404, 0.776, 0.353),
                (0.176, 0.204, 0.255), (0.890, 0.110, 0.200),
            ] {
                store.add(PickedColor(r: r, g: g, b: b))
            }
            for (fam, size, weight) in [
                ("Avenir Next", 16.0, "Medium"),
                ("Inter", 16.0, "Medium"),
                ("Playfair Display", 22.0, "Bold"),
                ("Pacifico", 24.0, "Regular"),
                ("Lobster", 28.0, "Regular"),
                ("Bricolage Grotesque", 20.0, "Medium"),  // variable font — exercises renderName
            ] {
                fonts.add(
                    PickedFont(
                        family: fam, pointSize: size, weightName: weight,
                        sampleSnippet: "The quick brown fox"))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.togglePanel()
            }
        }
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        button.image = NSImage(
            systemSymbolName: "eyedropper.halffull",
            accessibilityDescription: "Picker")?
            .withSymbolConfiguration(config)
        button.image?.isTemplate = true
        button.action = #selector(statusButtonClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Left click toggles the panel; right- or control-click shows Quit, since the
    /// in-panel menu is gone and an accessory app has no Dock item to quit from.
    @objc private func statusButtonClicked() {
        let event = NSApp.currentEvent
        let isSecondary =
            event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Quit Picker", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 5),
            in: button)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Panel

    private func setupPanel() {
        let root = PanelView(
            store: store, fonts: fonts, settings: settings, app: app, fontLoader: fontLoader,
            onPick: { [weak self] in self?.beginSampling() },
            onGrabFont: { [weak self] in self?.pickFont() },
            onResize: { [weak self] in self?.resizeIfVisible() })
        hosting = NSHostingController(rootView: root)
        // No automatic preferredContentSize resizing — it fires the moment the
        // section content swaps and cancels the pill's slide. The panel is sized
        // manually (layoutPanel / resizeIfVisible).

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false

        // Clip the window's backing to the panel radius so the square window
        // corners can't peek out around the rounded glass; the server-side
        // window shadow then traces the rounded silhouette, not the box.
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = Radius.panel
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }

        self.panel = panel
    }

    @objc private func togglePanel() {
        // Only treat the panel as open if it is *actually* on screen. After a screen
        // lock or sleep, `isVisible` can stay true while the panel is occluded, which
        // made every click "close" an already-invisible panel. The occlusion check
        // self-heals that stuck state.
        let onScreen = panel.isVisible && panel.occlusionState.contains(.visible)
        if onScreen { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        showPanel(animated: true)
    }

    private func showPanel(animated: Bool) {
        layoutPanel()
        positionPanel()
        if animated {
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            panel.invalidateShadow()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            // Stay under the loupe (.screenSaver) — only reveal once the overlay goes away.
            panel.orderFrontRegardless()
            panel.invalidateShadow()
        }
        if !isDemo { installGlobalMonitor() }
    }

    private func hidePanel() {
        hidePanel(animated: true)
    }

    private func hidePanel(animated: Bool) {
        removeGlobalMonitor()
        if animated {
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.12
                    panel.animator().alphaValue = 0
                },
                completionHandler: { [weak self] in
                    MainActor.assumeIsolated {
                        self?.panel.orderOut(nil)
                    }
                })
        } else {
            panel.alphaValue = 0
            panel.orderOut(nil)
        }
    }

    private func layoutPanel() {
        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        panel.setContentSize(NSSize(width: 320, height: max(fitting.height, 1)))
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let w = panel.frame.width
        let h = panel.frame.height
        var x = onScreen.midX - w / 2
        var y = onScreen.minY - h - 8
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            x = min(max(vf.minX + 8, x), vf.maxX - w - 8)
            if y < vf.minY + 8 { y = vf.minY + 8 }
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Grow/shrink to fit content while pinning the top edge. `animate: false` so a
    /// section switch (which resizes the panel) snaps instantly to the new page's
    /// height rather than animating, leaving the pill slide as the only motion.
    private func resizeIfVisible() {
        guard panel != nil, panel.isVisible else { return }
        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        let newSize = NSSize(width: 320, height: max(fitting.height, 1))
        let top = panel.frame.maxY
        var frame = panel.frame
        frame.size = newSize
        frame.origin.y = top - newSize.height
        panel.setFrame(frame, display: true, animate: false)
        panel.invalidateShadow()
    }

    // MARK: Sampling

    private func registerPickHotKey() {
        pickHotKey.register(shortcut: settings.pickShortcut) { [weak self] in
            guard let self else { return }
            if self.app.isSampling || self.app.isPickingFont { return }
            self.beginSampling()
        }
    }

    /// Freeze-loupe color pick. Gate on Screen Recording before hiding the panel
    /// so a missing grant doesn't vanish the UI with no explanation.
    private func beginSampling() {
        guard !app.isSampling, !colorSampler.isSampling else { return }

        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            app.say("Turn on Picker under Screen Recording, then click again", ok: false)
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            {
                NSWorkspace.shared.open(url)
            }
            // Show the panel so the toast is visible when invoked via hotkey.
            if !panel.isVisible { showPanel() }
            return
        }

        // Capture while the panel can stay up (excluded from the freeze), then
        // present the overlay and only then tuck the panel away — no desktop flash.
        app.isSampling = true

        Task { @MainActor in
            let outcome = await colorSampler.start(
                freezeScope: self.settings.freezeScope,
                formatProvider: { [weak self] in
                    self?.settings.colorDisplayFormat ?? .hex
                },
                magnificationProvider: { [weak self] in
                    self?.settings.loupeMagnification ?? PickShortcut.magnificationDefault
                },
                radiusProvider: { [weak self] in
                    self?.settings.loupeRadius ?? PickShortcut.loupeRadiusDefault
                },
                showPixelGridProvider: { [weak self] in
                    self?.settings.showPixelGrid ?? true
                },
                onMagnificationChange: { [weak self] value in
                    self?.settings.loupeMagnification = value
                },
                onRadiusChange: { [weak self] value in
                    self?.settings.loupeRadius = value
                },
                onPresented: { [weak self] in
                    self?.hidePanel(animated: false)
                },
                onWillDismiss: { [weak self] in
                    self?.showPanel(animated: false)
                }
            ) { [weak self] picked in
                guard let self else { return }
                self.app.isSampling = false
                if let picked {
                    self.store.add(picked)
                    Haptics.confirm()
                }
                // Panel already revealed under the loupe in onWillDismiss.
            }

            if case .needsPermission = outcome {
                app.isSampling = false
                if !panel.isVisible { showPanel() }
                app.say("Turn on Picker under Screen Recording, then click again", ok: false)
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: Font picking

    /// Drop the full-screen pick overlay so the user can click any text on screen
    /// and grab its font. The panel hides while picking so the page is visible,
    /// then returns to show the result.
    private func pickFont() {
        guard !fontPicker.isPicking else { return }

        // Gate on Accessibility permission BEFORE hiding the panel — otherwise the
        // panel just vanishes with no visible explanation. Keep it up, show the
        // toast, fire the system prompt, and jump straight to the right settings pane.
        guard AXIsProcessTrusted() else {
            let key = "AXTrustedCheckOptionPrompt" as NSString
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
            app.sayFont("Turn on Picker under Accessibility, then click again", ok: false)
            if let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            {
                NSWorkspace.shared.open(url)
            }
            return
        }

        let wasVisible = panel.isVisible
        if wasVisible { hidePanel() }
        app.isPickingFont = true

        let outcome = fontPicker.start { [weak self] picked in
            guard let self else { return }
            self.app.isPickingFont = false
            if let picked {
                if picked.family == "Unknown" {
                    // Chromium browsers need their page JS opened up for us to read the
                    // family (their accessibility tree doesn't expose it).
                    self.app.sayFont(
                        "Couldn't read the font. In Chrome: View ▸ Developer ▸ Allow "
                            + "JavaScript from Apple Events", ok: false)
                } else {
                    self.fonts.add(picked)
                    Haptics.confirm()
                    self.app.sayFont("Saved \(picked.family)", ok: true)
                }
            }
            self.showPanel()
        }

        if case .needsPermission = outcome {
            app.isPickingFont = false
            if wasVisible { showPanel() }
            app.sayFont("Turn on Picker under Accessibility, then click again", ok: false)
        }
    }

    // MARK: Dismiss-on-outside-click

    private func installGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown,
        ]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.app.isSampling { return }  // don't fight the loupe
                if self.app.isPickingFont { return }  // don't fight the font overlay
                self.hidePanel()
            }
        }
    }

    private func removeGlobalMonitor() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }
}

// MARK: - Entry point

@main
enum PickerMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
