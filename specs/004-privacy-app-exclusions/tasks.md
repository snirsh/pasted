# Tasks: Privacy & App Exclusions

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Data Model**: [data-model.md](./data-model.md)
**Date**: 2026-04-09
**Dependencies**: spec 001 (Clipboard History), spec 002 (OCR cascade delete), spec 003 (iCloud Sync)

---

## Phase 1: Setup

- [ ] T001 [P] Create directory `Pasted/Services/Privacy/`
- [ ] T002 [P] Create directory `PastedTests/` (if not present)

---

## Phase 2: Foundational — AppExclusion Model, ExclusionLookup, DefaultExclusionList

- [ ] T003 Write test for `DefaultExclusionList` — verify list is non-empty, all bundle IDs are reverse-DNS format, no duplicates, all 9 entries present in `PastedTests/DefaultExclusionListTests.swift`
- [ ] T004 Implement `DefaultExclusionList` enum with static entries array and `bundleIdentifiers` computed Set in `Pasted/Services/Privacy/DefaultExclusionList.swift`
- [ ] T005 Run and pass `DefaultExclusionListTests`
- [ ] T006 Write test for `AppExclusion` @Model — create, save, query by bundleIdentifier, verify unique constraint on bundleIdentifier in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T007 Implement `AppExclusion` @Model class with id, bundleIdentifier (.unique), displayName, iconData, isDefault, dateAdded in `Pasted/Models/AppExclusion.swift`
- [ ] T008 Register `AppExclusion` in SwiftData ModelContainer schema alongside `ClipboardItem` in `Pasted/PastedApp.swift`
- [ ] T009 Run and pass `AppExclusion` model tests
- [ ] T010 Write test for `ExclusionLookup` — rebuild from [AppExclusion], isExcluded returns true/false correctly, empty set returns false in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T011 Implement `ExclusionLookup` class with `excludedBundleIDs: Set<String>`, `rebuild(from:)`, and `isExcluded(_:) -> Bool` in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T012 Run and pass `ExclusionLookup` tests
- [ ] T013 Write test for `AppExclusionService` — seeding defaults on first launch, add/remove exclusion, lookup delegation, idempotent add of duplicate bundleIdentifier in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T014 Implement `AppExclusionService` with seed logic (check if already seeded), add/remove methods updating SwiftData + in-memory Set, isExcluded delegation in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T015 Run and pass `AppExclusionService` tests

---

## Phase 3: US1 — Auto-Exclude Password Managers (P1) MVP

- [ ] T016 [US1] Write test for ClipboardMonitor pre-capture gate — mock AppExclusionService with excluded bundleID, simulate clipboard change from excluded app, verify no ClipboardItem created in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T017 [US1] Write test for ClipboardMonitor — simulate clipboard change from non-excluded app, verify ClipboardItem IS created in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T018 [US1] Add pre-capture gate to `ClipboardMonitor.swift`: get `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`, call `appExclusionService.isExcluded(bundleID)`, return early if excluded in `Pasted/Services/ClipboardMonitor.swift`
- [ ] T019 [US1] Inject `AppExclusionService` dependency into `ClipboardMonitor` init in `Pasted/Services/ClipboardMonitor.swift`
- [ ] T020 [US1] Run and pass ClipboardMonitor exclusion integration tests
- [ ] T021 [US1] End-to-end verification: launch app, copy from 1Password (excluded) -> not captured, copy from Safari (not excluded) -> captured

---

## Phase 4: US2 — User-Configurable Exclusions (P1)

- [ ] T022 [US2] Write test for add exclusion flow — AppExclusionService.add creates AppExclusion, rebuilds lookup Set, isExcluded returns true immediately in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T023 [US2] Write test for remove exclusion flow — AppExclusionService.remove deletes AppExclusion, rebuilds lookup Set, isExcluded returns false immediately in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T024 [US2] Write test for removing a default exclusion — verify default apps can be removed, isDefault flag preserved on display in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T025 [US2] Implement `PrivacyPreferencesView` — list of excluded apps with icon + name + "Default" badge, "Add App..." button, remove button per entry in `Pasted/Views/Preferences/PrivacyPreferencesView.swift`
- [ ] T026 [US2] Implement `AppPickerView` — running apps list filtered to `.activationPolicy == .regular`, "Browse..." button opening NSOpenPanel for `/Applications`, selection calls AppExclusionService.add in `Pasted/Views/Preferences/AppPickerView.swift`
- [ ] T027 [US2] Extract icon data (32x32 PNG) from selected app bundle for `iconData` field in `Pasted/Views/Preferences/AppPickerView.swift`
- [ ] T028 [US2] Wire PrivacyPreferencesView into existing Preferences window/tab in `Pasted/Views/Preferences/`
- [ ] T029 [US2] Run and pass add/remove exclusion tests
- [ ] T030 [US2] Manual verification: add Notes to exclusion list -> copy from Notes -> not captured; remove Notes -> copy from Notes -> captured

---

## Phase 5: US4 — Clear History on Demand (P2)

- [ ] T031 [US4] Write test for individual item deletion — `modelContext.delete(item)` removes ClipboardItem from local store in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T032 [US4] Write test for clear all history — batch delete all ClipboardItem records, verify store is empty in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T033 [US4] Implement Delete key binding on selected strip item — call `modelContext.delete(item)` with synced deletion tombstone for iCloud in `Pasted/Views/` (strip view handling)
- [ ] T034 [US4] Implement "Clear All History..." button in PrivacyPreferencesView with confirmation alert (warn: permanent, no undo) in `Pasted/Views/Preferences/PrivacyPreferencesView.swift`
- [ ] T035 [US4] Implement batch delete: `modelContext.delete(model: ClipboardItem.self)` for clear all, plus CloudKit zone reset for iCloud propagation in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T036 [US4] Implement empty state view with helpful message when strip has no items after clearing in `Pasted/Views/`
- [ ] T037 [US4] Run and pass deletion tests
- [ ] T038 [US4] Manual verification: copy 5 items, delete one from strip -> gone; clear all -> strip shows empty state

---

## Phase 6: US3 — Concealed Content Detection (P3)

- [ ] T039 [US3] Write test for `ConcealedContentDetector.isConcealed` — mock pasteboard with `org.nspasteboard.ConcealedType` present -> returns true in `PastedTests/ConcealedContentDetectorTests.swift`
- [ ] T040 [US3] Write test for `ConcealedContentDetector` with concealed type absent -> returns false in `PastedTests/ConcealedContentDetectorTests.swift`
- [ ] T041 [US3] Write test for `ConcealedContentDetector` with UserDefaults toggle disabled -> returns false even when concealed type present in `PastedTests/ConcealedContentDetectorTests.swift`
- [ ] T042 [US3] Define `NSPasteboard.PasteboardType.concealed` extension for `"org.nspasteboard.ConcealedType"` in `Pasted/Services/Privacy/ConcealedContentDetector.swift`
- [ ] T043 [US3] Implement `ConcealedContentDetector` enum with static `isConcealed(_ pasteboard:) -> Bool` checking types + UserDefaults toggle in `Pasted/Services/Privacy/ConcealedContentDetector.swift`
- [ ] T044 [US3] Register UserDefaults default value `concealedDetectionEnabled = true` in `Pasted/PastedApp.swift`
- [ ] T045 [US3] Add concealed content check to ClipboardMonitor pre-capture gate (after app exclusion check, before content read) in `Pasted/Services/ClipboardMonitor.swift`
- [ ] T046 [US3] Add "Detect concealed clipboard content" toggle bound to `concealedDetectionEnabled` in `Pasted/Views/Preferences/PrivacyPreferencesView.swift`
- [ ] T047 [US3] Run and pass `ConcealedContentDetectorTests`
- [ ] T048 [US3] Manual verification: programmatically set pasteboard with concealed type -> not captured; disable toggle -> captured

---

## Phase 7: Polish — Sync, Accessibility, Edge Cases

- [ ] T049 [P] Include `AppExclusion` in CloudKit sync scope so exclusion list syncs across devices via iCloud (spec 003 integration) in `Pasted/Services/` (sync configuration)
- [ ] T050 [P] Rebuild `ExclusionLookup` Set on receiving remote exclusion list changes from iCloud in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T051 [P] Write test verifying exclusion list rebuild on remote iCloud change notification in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T052 [P] Add accessibility labels to all PrivacyPreferencesView controls (exclusion list, add/remove buttons, toggles) in `Pasted/Views/Preferences/PrivacyPreferencesView.swift`
- [ ] T053 [P] Add accessibility labels to AppPickerView controls (running apps list, browse button) in `Pasted/Views/Preferences/AppPickerView.swift`
- [ ] T054 [P] Ensure full keyboard navigation in PrivacyPreferencesView — tab between list, buttons, toggles; Delete key removes selected exclusion in `Pasted/Views/Preferences/PrivacyPreferencesView.swift`
- [ ] T055 [P] Ensure full keyboard navigation in AppPickerView — arrow keys in running apps list, Return to select, Escape to dismiss in `Pasted/Views/Preferences/AppPickerView.swift`
- [ ] T056 Handle edge case: duplicate bundle ID add is idempotent (no-op, no error) in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T057 Handle edge case: remove non-existent bundle ID is a no-op (no error) in `Pasted/Services/Privacy/AppExclusionService.swift`
- [ ] T058 Handle edge case: frontmostApplication returns nil (no bundle ID) — skip exclusion check, allow capture in `Pasted/Services/ClipboardMonitor.swift`
- [ ] T059 Write test for nil bundleIdentifier edge case — verify capture proceeds normally in `PastedTests/AppExclusionServiceTests.swift`
- [ ] T060 [P] Verify iCloud deletion propagation: delete item on device A, confirm removal on device B within 30 seconds (spec 003 integration)
- [ ] T061 [P] Verify iCloud clear-all propagation: CloudKit zone reset on device A, confirm empty history on device B (spec 003 integration)
- [ ] T062 Final review: run full test suite, verify all acceptance scenarios from spec.md pass
