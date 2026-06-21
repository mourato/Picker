import SwiftUI
import AppKit

// MARK: - Panel
//
// The instrument's face. Vertical rhythm reads top-to-bottom as a story:
// the latest pick (hero) → its readable values → the action that creates more →
// the palette of everything grabbed so far.

struct PanelView: View {
    @ObservedObject var store: ColorStore
    @ObservedObject var app: AppState
    var onPick: () -> Void

    @State private var copied: String?
    @State private var copyToken = 0

    private let width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HeroCard(picked: store.latest, isSampling: app.isSampling) { copy($0) }
                .animation(Motion.settle, value: store.latest)

            if let latest = store.latest {
                formatsCard(latest)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            EyedropperButton(isSampling: app.isSampling, action: onPick)

            if !store.colors.isEmpty {
                SwatchStrip(store: store) { copy($0) }
                    .transition(.opacity)
            }
        }
        .padding(Space.lg)
        .frame(width: width)
        .background(panelSurface)
        .overlay(alignment: .bottom) { toast }
        .animation(Motion.settle, value: store.colors.isEmpty)
    }

    // MARK: Formats

    private func formatsCard(_ c: PickedColor) -> some View {
        VStack(spacing: 0) {
            FormatRow(label: "HEX", value: c.hex) { copy(c.hex) }
            divider
            FormatRow(label: "RGB", value: c.rgbString) { copy(c.rgbString) }
            divider
            FormatRow(label: "HSL", value: c.hslString) { copy(c.hslString) }
        }
        .padding(.vertical, Space.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Hairline.soft, lineWidth: 1)
                )
        )
    }

    private var divider: some View {
        Rectangle().fill(Hairline.soft).frame(height: 1).padding(.horizontal, Space.md)
    }

    // MARK: Panel surface — the liquid glass

    private var panelSurface: some View {
        RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
            .fill(.clear)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                    .stroke(Hairline.medium, lineWidth: 1)
            )
    }

    // MARK: Copy feedback

    private var toast: some View {
        Group {
            if let copied {
                HStack(spacing: Space.xs) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Copied \(copied)")
                        .font(TypeScale.caption)
                }
                .foregroundStyle(Ink.primary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 7)
                .glassEffect(.regular, in: Capsule())
                .overlay(Capsule().stroke(Hairline.medium, lineWidth: 1))
                .padding(.bottom, Space.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.arrive, value: copied)
    }

    private func copy(_ string: String) {
        Clipboard.copy(string)
        Haptics.confirm()
        copied = string
        copyToken += 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if token == copyToken { copied = nil }
        }
    }
}

// MARK: - Hero card

private struct HeroCard: View {
    var picked: PickedColor?
    var isSampling: Bool
    var onCopy: (String) -> Void

    @State private var hovering = false
    @State private var justCopied = false
    @State private var copyToken = 0

    var body: some View {
        Group {
            if let picked {
                filled(picked)
            } else {
                empty
            }
        }
        .frame(height: 146)
        .frame(maxWidth: .infinity)
    }

    private func filled(_ c: PickedColor) -> some View {
        let ink = c.prefersDarkInk ? Color.black : Color.white
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let showIcon = hovering || justCopied
        return Button {
            copy(c.hex)
        } label: {
            ZStack(alignment: .bottomLeading) {
                shape.fill(c.color)   // pure color, no border or sheen

                HStack(alignment: .center, spacing: 10) {
                    Text(c.hex)
                        .font(TypeScale.heroHex)
                        .foregroundStyle(ink)
                        .contentTransition(.numericText())
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ink.opacity(justCopied ? 1 : 0.85))
                        .contentTransition(.symbolEffect(.replace))
                        .opacity(showIcon ? 1 : 0)
                        .offset(x: showIcon ? 0 : -6)
                        .animation(.easeOut(duration: 0.18), value: hovering)
                        // Icon-swap timing, adapted from transitions-dev (200ms ease-in-out),
                        // nudged a touch faster so the copy→check morph feels snappier.
                        .animation(.easeInOut(duration: 0.16), value: justCopied)
                    Spacer(minLength: 0)
                }
                .padding(Space.lg)
            }
            .contentShape(shape)
        }
        .pressable(scale: 0.99)
        .pointerStyle(.link)
        .onHover { hovering = $0 }
    }

    /// Copy, flip the icon to a checkmark, then let it fade back / away shortly after.
    private func copy(_ hex: String) {
        onCopy(hex)
        justCopied = true
        copyToken += 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if token == copyToken { justCopied = false }
        }
    }


    private var empty: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.primary.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(
                            Hairline.medium,
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 5])
                        )
                )
            VStack(spacing: Space.sm) {
                Image(systemName: isSampling ? "loupe" : "eyedropper")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Ink.tertiary)
                    .symbolEffect(.pulse, isActive: isSampling)
                Text(isSampling ? "Pick a pixel…" : "No color yet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                Text(isSampling ? "Click anywhere on screen" : "Grab one to begin your palette")
                    .font(TypeScale.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }
}

// MARK: - Primary action

private struct EyedropperButton: View {
    var isSampling: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: isSampling ? "loupe" : "eyedropper.halffull")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolEffect(.pulse, isActive: isSampling)
                Text(isSampling ? "Sampling…" : "Pick a Color")
                    .font(TypeScale.button)
            }
            .foregroundStyle(Ink.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .overlay(Capsule().stroke(Hairline.soft, lineWidth: 1))
        .scaleEffect(hovering && !isSampling ? 1.012 : 1)
        .brightness(hovering && !isSampling ? 0.04 : 0)
        .animation(Motion.micro, value: hovering)
        .onHover { hovering = $0 }
        .disabled(isSampling)
    }
}

// MARK: - Format row

private struct FormatRow: View {
    var label: String
    var value: String
    var onCopy: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: Space.md) {
                Text(label)
                    .font(TypeScale.caption)
                    .foregroundStyle(Ink.tertiary)
                    .frame(width: 34, alignment: .leading)
                Text(value)
                    .font(TypeScale.valueStrong)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Ink.tertiary)
                    .opacity(hovering ? 1 : 0)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Radius.chip - 3, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.05 : 0))
                    .padding(.horizontal, Space.xs)
            )
        }
        .buttonStyle(.plain)
        .animation(Motion.micro, value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Saved palette

private struct SwatchStrip: View {
    @ObservedObject var store: ColorStore
    var onCopy: (String) -> Void

    @State private var clearHover = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                Text("PALETTE")
                    .font(TypeScale.sectionTitle)
                    .tracking(1.2)
                    .foregroundStyle(Ink.tertiary)
                Text("\(store.colors.count)")
                    .font(TypeScale.caption)
                    .foregroundStyle(Ink.faint)
                    .contentTransition(.numericText())
                Spacer()
                clearButton
            }

            WheelHScroll {
                HStack(spacing: Space.sm) {
                    ForEach(store.colors) { c in
                        SwatchChip(
                            color: c,
                            onCopy: { onCopy(c.hex) },
                            onDelete: { store.remove(c) }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.4).combined(with: .opacity),
                            removal: .scale(scale: 0.6).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.vertical, 6)
                .padding(.leading, 2)
                .padding(.trailing, 24)   // empty room so the last chip clears the fade
                .animation(Motion.arrive, value: store.colors)
            }
            .frame(height: 58)
            // Soft trailing fade instead of a hard edge where the row overflows.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var clearButton: some View {
        Button {
            store.clear()
        } label: {
            HStack(spacing: Space.xs) {
                Image(systemName: "trash")
                    .font(.system(size: 9, weight: .semibold))
                Text("Clear")
                    .font(TypeScale.caption)
            }
            .foregroundStyle(clearHover ? Ink.secondary : Ink.tertiary)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(clearHover ? 0.07 : 0)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Motion.micro, value: clearHover)
        .onHover { clearHover = $0 }
    }
}

private struct SwatchChip: View {
    var color: PickedColor
    var onCopy: () -> Void
    var onDelete: () -> Void

    @State private var hovering = false

    private let size: CGFloat = 46

    var body: some View {
        // Copy chip and delete button are SIBLINGS layered in a ZStack — never a
        // button nested in another button's label, which would swallow the tap.
        ZStack(alignment: .topTrailing) {
            Button(action: onCopy) {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(color.color)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .stroke(Hairline.onColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(hovering ? 0.18 : 0),
                            radius: hovering ? 6 : 0, x: 0, y: hovering ? 2 : 0)
                    .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
            .pressable(scale: 0.92)

            deleteButton
                .allowsHitTesting(hovering)   // only intercepts while shown
        }
        .frame(width: size, height: size)
        .offset(y: hovering ? -3 : 0)
        .animation(Motion.micro, value: hovering)
        .onHover { hovering = $0 }
        .help(color.hex)
    }

    private var deleteButton: some View {
        // Original look (overhanging the top-right corner). The fix was structural —
        // it lives as a sibling with hit-testing gated to hover — not visual.
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(Circle().fill(.black.opacity(0.55)))
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(x: 5, y: -5)
        .opacity(hovering ? 1 : 0)
        .scaleEffect(hovering ? 1 : 0.6)
    }
}

// MARK: - Wheel-friendly horizontal scroller
//
// A horizontal scroller that also moves on a plain vertical mouse wheel (no Shift
// needed) whenever the cursor is over it. Real trackpad horizontal swipes pass
// straight through to native handling.

private struct WheelHScroll<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = HorizontalWheelScrollView()
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .allowed
        scroll.contentView.drawsBackground = false

        let host = NSHostingView(rootView: AnyView(content))
        host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        scroll.documentView = host

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            host.bottomAnchor.constraint(equalTo: scroll.contentView.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor)
        ])
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        (scroll.documentView as? NSHostingView<AnyView>)?.rootView = AnyView(content)
    }
}

private final class HorizontalWheelScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // A deliberate horizontal gesture (trackpad swipe) → native behavior.
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            super.scrollWheel(with: event)
            return
        }
        guard let documentView else { return }
        let maxX = max(0, documentView.frame.width - contentView.bounds.width)
        guard maxX > 0 else { return }

        // Mouse wheels report coarse line deltas; scale them so a notch travels a
        // sensible distance. Trackpads already report precise point deltas.
        let step = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaY
            : event.scrollingDeltaY * 16
        var origin = contentView.bounds.origin
        origin.x = min(max(0, origin.x - step), maxX)
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }
}
