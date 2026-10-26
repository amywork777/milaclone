# Native source review, 2026-10-25

Scope: source-level Impeccable native audit, device-SDK build, subsequent signed build and successful installation on the paired iPhone 15 Pro. No simulator, device rendering, or accessibility runtime evidence is available. Native defaults are an implementation choice; they do not establish tested usability.

- Platform structure: SwiftUI NavigationStack, List, Form, sheet, Menu, native alert, PhotosPicker, file importer, and Quick Look. System back navigation and safe areas remain intact. iPhone is the only target device family.
- Typography and appearance: system text styles and semantic surfaces/text; one plum tint with light/dark variants. No fixed text sizes, decorative animation, sound, web controls, or external fonts. The small static loop retains the existing notebook identity.
- Interaction: named SF Symbols, 44-point custom interactive frames, explicit deletion confirmation, disabled editing during sync, empty/loading/error/conflict states, saved-per-edit fields. Columns become vertical sections. The task loop is add, write, return to the board.
- Data and security: raw JSON mutation preserves schema fields; atomic saves and request failures retain local edits; Keychain pairing; HTTPS exact certificate pinning; redirect rejection; explicit conflict recovery. Model and real loopback transport tests pass.
- Open P1 verification: actual-device local-network prompt, lifecycle/reconnect, picker access and end-to-end sync against a running Mac. No runtime accessibility, Dynamic Type, dark-mode, or screenshot verification. Do not describe this as hardware-tested or shipped.
- Open P2 performance: large attachment snapshots are encoded/written synchronously on edits. Thumbnail decoding is bounded/cached, but storage performance at the maximum attachment budget remains unmeasured.
- Open P3 distribution: custom app icon is not configured; development signing and device installation succeeded. The color catalog is excluded from build to avoid the unavailable asset-compiler runtime; the native theme supplies equivalent tint values.

Taste finish checklist: existing project palette and native operating mode retained; one loop detail; no ornamental motion/sound or vetoed UI styling. Native layout should reflow, but 390-point, landscape, large text, and VoiceOver checks remain unverified. This is a working foundation with source and transport validation, not a visual approval.
