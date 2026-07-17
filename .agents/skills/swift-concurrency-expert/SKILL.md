---
name: swift-concurrency-expert
description: Swift concurrency guidance for Picker — MainActor UI, async FontLoader work, and Sendable across sampling boundaries.
---

# Swift Concurrency Expert

Use for actor isolation, `Sendable`, async/await, or Swift 6 concurrency diagnostics in Picker.

## Invariants

- UI and AppKit panel/status-item ownership stay on the **MainActor**.
- Font download/registration (`FontLoader`) may be async — hop back to the main actor before updating specimen UI or stores.
- Do not block the main thread on network or font registration.
- Event-tap and AX callbacks must not assume unconstrained isolation; marshal UI updates explicitly.
- Prefer structured concurrency over detached unstructured tasks for feature work unless lifetime is truly fire-and-forget and documented.

## Checklist

- Are `@MainActor` boundaries clear at SwiftUI/AppKit edges?
- Is shared mutable state (stores, panel flags) isolated?
- Do cancellation paths tear down overlays/taps without races on dismiss?

## Related

- UI structure → `macos-app-engineering`
- FontLoader failures → `debugging-diagnostics`
