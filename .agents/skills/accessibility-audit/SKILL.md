---
name: accessibility-audit
description: Accessibility review for Picker — YIQ ink contrast, VoiceOver labels, Grab Font AX overlay, and permission prompts.
---

# Accessibility Audit

Use when changing the panel UI, copy affordances, Grab Font overlay, contrast ink, or permission/toast flows.

## Minimum Bar

- Interactive controls need useful accessibility labels.
- Color is not the only state signal (copy confirmation, section switch, empty states).
- Transient UI dismisses predictably with `Esc` where applicable (font picker overlay).
- Respect Reduce Motion, Reduce Transparency, Bold Text, Increase Contrast.

## Picker Focus

- **YIQ ink** (`0.299·R + 0.587·G + 0.114·B`) chooses black/white text on swatches — do not silently replace with WCAG luminance alone.
- Grab Font overlay is **click-through and accessibility-invisible** so system-wide AX hit-testing reads *through* it to the target text.
- Highlight must hug the `AXStaticText` run, not a surrounding container.
- Until Accessibility is granted, Grab Font shows a clear toast — do not fail silently.
- Status item and panel actions should remain understandable with VoiceOver.

## Review Checklist

- Can the user open the panel, copy a format, and dismiss without a pointer?
- Does Esc / right-click / non-text click cancel Grab Font cleanly?
- Are permission and Chrome Automation requirements discoverable in UI or docs when flows fail?
- Do saturated reds/blues still get readable ink?

## Related

- Overlay / status item → `menubar`
- Diagnostics for AX failures → `debugging-diagnostics`
