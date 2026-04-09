<!--
Sync Impact Report
- Version change: 0.0.0 → 1.0.0
- Modified principles: none (initial creation)
- Added sections: Core Principles (5), Technology Constraints, Development Workflow, Governance
- Removed sections: none
- Templates requiring updates: ✅ spec-template.md (no changes needed) | ✅ plan-template.md (no changes needed) | ✅ tasks-template.md (no changes needed)
- Follow-up TODOs: none
-->

# Pasted Constitution

## Core Principles

### I. Privacy-First

All user data MUST remain on-device or within the user's private iCloud account. No telemetry, analytics, or data collection of any kind. No external servers, no phone-home behavior, no crash reporting that transmits clipboard content. Users MUST have full control over what is stored and for how long. Password manager content and user-excluded apps MUST never be captured.

### II. Native macOS Citizen

Pasted MUST be built with SwiftUI and native Apple frameworks (AppKit, Vision, CloudKit, SwiftData). No Electron, no web wrappers, no cross-platform abstraction layers. The app MUST feel indistinguishable from a first-party Apple application — respecting system appearance, accessibility settings, keyboard navigation conventions, and macOS Human Interface Guidelines. Target: macOS 14 Sonoma and later.

### III. Keyboard-First UX

Every feature MUST be reachable via keyboard shortcuts. Mouse/trackpad interaction is supported but never required. The primary invocation (Shift+Cmd+V), navigation (arrow keys), search (type-ahead), and pasting (Return) MUST work without touching the mouse. Custom shortcut binding MUST be supported for power users.

### IV. Open Source Transparency

Pasted is MIT-licensed open source software. All code, build processes, and dependencies MUST be publicly auditable. No hidden monetization, tracking, or proprietary components. Community contributions are welcomed and governed by standard open source practices (issues, PRs, code review). Binary releases MUST be reproducible from the public source.

### V. Simplicity Over Features

Ship fewer features that work flawlessly rather than many that are half-baked. Every new feature MUST justify its complexity cost. Start with the minimum viable clipboard experience (history, search, sync) and expand only when the foundation is solid. Avoid premature abstraction — direct, readable code is preferred over clever indirection. YAGNI applies unless evidence contradicts it.

## Technology Constraints

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (macOS 14+)
- **Data Persistence**: SwiftData for local clipboard history
- **Cloud Sync**: CloudKit for iCloud synchronization
- **OCR**: Apple Vision framework (VNRecognizeTextRequest)
- **Minimum Deployment Target**: macOS 14.0 (Sonoma)
- **Package Management**: Swift Package Manager
- **Testing**: XCTest + Swift Testing framework
- **No external runtime dependencies** — all frameworks are Apple-provided

## Development Workflow

- **Test-First**: Write tests before implementation. Red-Green-Refactor cycle enforced for all features.
- **Spec-Driven**: Every feature starts as a specification (this project uses spec-kit). Code serves specs, not the other way around.
- **Incremental Delivery**: Each user story MUST be independently shippable. No feature branches that live longer than one spec cycle.
- **Code Review**: All changes require review. Constitution compliance is a review gate.
- **Accessibility**: VoiceOver support is not optional. Every UI element MUST have accessibility labels and actions.

## Governance

This constitution supersedes all other project documentation when conflicts arise. Amendments require:

1. A written proposal explaining the change and its rationale.
2. Update to this document with version bump per semantic versioning:
   - **MAJOR**: Principle removed, redefined, or made backward-incompatible.
   - **MINOR**: New principle or section added, or existing guidance materially expanded.
   - **PATCH**: Clarifications, wording improvements, non-semantic refinements.
3. All existing specs and plans MUST be reviewed for compliance after any MAJOR or MINOR amendment.

All PRs and code reviews MUST verify compliance with this constitution. Complexity beyond what a principle allows MUST be justified in writing.

**Version**: 1.0.0 | **Ratified**: 2026-04-09 | **Last Amended**: 2026-04-09
