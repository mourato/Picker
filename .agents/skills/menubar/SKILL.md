---
name: menubar
description: Menu bar invariants for Picker — NSStatusItem ownership, left/right click, and non-activating NSPanel behavior.
---

# Menu Bar

Use this skill for `NSStatusItem`, status-item click behavior, floating panel ownership, and menu-bar-only app style.

## Invariants

- Register the status item once; keep its lifetime explicit in the app shell (`App.swift`).
- **Left-click** toggles the floating panel; **right-click** quits. Do not conflate the two.
- Host UI in a borderless, **non-activating** `NSPanel` anchored under the status item — **not** `MenuBarExtra`. The panel must stay open while color sampling or font grabbing runs.
- Panel style should include non-activating / borderless behavior so the sampled app keeps focus.
- No Dock icon (`LSUIElement = true` via `build.sh` Info.plist). Do not introduce a regular activating main window for normal use.
- Closing/opening the panel repeatedly must not create duplicate controllers, status items, or event taps.

## Review Checklist

- Does the app remain menu-bar-only after the change?
- Can the status item recover cleanly after relaunch?
- Does the panel stay open during `NSColorSampler` / Grab Font sessions?
- Is activation/deactivation consistent (no unexpected Dock bounce or focus steal)?

## Manual Checks

- Left-click open/close repeatedly.
- Start Pick a Color / Grab Font with the panel open; confirm the source app stays usable.
- Right-click quit.
- Relaunch after Accessibility grant and confirm status item still appears.
