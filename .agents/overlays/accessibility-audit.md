---
kind: project-overlay
extends: accessibility-audit
project: Picker
precedence: project
---

# Picker accessibility overlay

- Preserve YIQ ink contrast (`0.299·R + 0.587·G + 0.114·B`) for swatches.
- Grab Font uses a click-through, accessibility-invisible overlay so
  system-wide AX hit testing reaches the source application.
- Resolve the deepest `AXStaticText` leaf so the highlight hugs the text run.
- Grab Font requires Accessibility permission; Chrome/Chromium also requires
  Automation and “Allow JavaScript from Apple Events”.
- Permission denial must remain visible through a clear toast and settings
  path; sampling must preserve the source app’s focus.
