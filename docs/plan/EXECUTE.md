# EXECUTE.md – Step-by-step build runbook

Companion to `PROJECT_PLAN.md` (the *what*). This file is the *how, in order*.

## Working rules (read before every step)
1. Do **one step at a time**, in order. Do not start step N+1 until step N's "Done when" is met.
2. Each step ends with: run the checks → tick the box `[x]` here → commit (once git exists) → short report to the user.
3. If a check fails: fix the root cause, don't skip it. If blocked after 2–3 attempts, stop and ask.
4. Keep each step small: ≤ ~1 focused change set. Split a step rather than let it sprawl.
5. Tests come with the code they cover (same step), not later.
6. Ask the user before: choosing something that changes scope, installing global tools, or anything outward-facing (pushing, publishing, signing keys).
7. Never edit PROJECT_PLAN.md silently; if a decision changes, record it in the "Decision log" at the bottom.
8. Commit format: `<step id>: <summary>`; end with the attribution line from the session.

## Open decisions (resolve at Step 0.2)
- [x] Other-events columns: name+date pairs ×3.
- [x] Re-import default: Merge.
- [x] Rust core: yes, in Phase 6.
- [x] Country codes: support ALL countries (user-selectable default region in Settings, initial value from device locale, en-IN → +91); numbers entered with `+` parse for any country. Package id: `com.example.contactreminder` (change before any Play Store release).

---

## Phase 0 – Environment & repo
### [x] 0.1 Check toolchain
- Do: `flutter --version`, `flutter doctor -v`, `java -version`, `adb --version`, list AVDs (`emulator -list-avds`). Later (Phase 6) also `rustc --version`, `cargo --version`.
- Done when: Flutter stable + Android SDK + a working emulator or connected device are confirmed. Missing tools are listed to the user with install instructions (user installs; do not silently install global tools).

### [x] 0.2 Resolve open decisions
- Do: ask the user the open decisions above; record answers in the Decision log.
- Done when: all four boxes above are ticked.

### [x] 0.3 Repo init
- Do: `git init` in `E:\dev\contact-reminder`; add root `.gitignore` (Flutter, Android, Rust `target/`, IDE files); add `README.md` (one paragraph + link to docs/plan).
- Done when: `git status` clean after first commit `0.3: init repo`.

---

## Phase 1 – Scaffold & data (Milestone 1)
### [x] 1.1 Create Flutter project
- Do: `flutter create --org <org> --project-name contact_reminder --platforms android app`; set minSdk 23 (raise to what plugins need), compileSdk latest; remove template counter code.
- Done when: `flutter analyze` clean; `flutter run` shows a blank Material 3 app on emulator.

### [x] 1.2 Dependencies & folder skeleton
- Do: add `flutter_riverpod`, `drift`, `drift_flutter` (or `sqlite3_flutter_libs`), `path_provider`, `path`; dev: `drift_dev`, `build_runner`, `flutter_lints`. Create `lib/{core,data,features/{contacts,events,import_export,settings}}`.
- Done when: `flutter pub get` OK; `flutter analyze` clean.

### [x] 1.3 Database schema
- Do: drift tables `groups`, `contacts`, `contact_phones`, `contact_events`, `settings` exactly as in PROJECT_PLAN; foreign keys ON with cascade delete; unique `(group_id, position)` where relevant; schema version 1 with `MigrationStrategy`; run `dart run build_runner build`.
- Done when: generated code compiles; `analyze` clean.

### [x] 1.4 Repositories + tests
- Do: `GroupRepository`, `ContactRepository` (create/update/delete/watch by group/search, with phones+events in one transaction), `SettingsRepository`. Validation: first name required, ≥1 phone, ≤3 phones.
- Tests (in-memory drift): CRUD, cascade delete, search, validation errors, group ordering.
- Done when: `flutter test` green.

---

## Phase 2 – Contacts UI (Milestone 2)
### [x] 2.1 App shell & theme
- Do: `MaterialApp` (M3, light/dark), Riverpod `ProviderScope`, bottom nav/drawer: Contacts, Today, Settings (placeholders).
- Done when: app runs; navigation works; dark mode follows system.

### [x] 2.2 Group tabs + contact list
- Do: `TabBar` built from `groups` stream; per-tab list with search; empty state ("Import a file or add a contact"); seed-data debug helper (debug builds only).
- Tests: widget test with seeded in-memory DB shows tabs and list; search filters.
- Done when: tests green; manually verified on emulator.

### [x] 2.3 Contact detail screen
- Do: shows name, phones, events (age/years shown only if year known), email, address; action buttons are stubs for now.
- Done when: widget test + manual check.

### [x] 2.4 Add / Edit form
- Do: form with validation; up to 3 phones; date picker with "no year" toggle for DOB, anniversary, other events (dynamic list); group picker with "new group"; delete with confirm.
- Tests: validation (missing first name/phone), saving with/without year, edit round-trip.
- Done when: tests green; add→list→edit→delete works on emulator.

---

## Phase 3 – Actions (Milestone 3)
### [x] 3.1 Phone number normalisation
- Do: `PhoneNormalizer` (default country code from settings, strips spaces/dashes, handles leading 0 / +). Prefer `phone_numbers_parser` package; wrap behind an interface (Rust replacement later).
- Tests: ≥15 cases incl. `+91 98765-43210`, `09876543210`, already-E.164, garbage.
- Done when: tests green; `number_e164` populated on save.

### [x] 3.2 Call / SMS / WhatsApp launchers
- Do: `url_launcher`; `tel:` (dialer, no CALL_PHONE permission), `sms:` (+ optional body), `https://wa.me/<digits>?text=`; add `<queries>` for tel/sms/https/WhatsApp in `AndroidManifest.xml`; graceful snackbar if no handler / WhatsApp missing.
- Tests: URI builder unit tests (encoding, body).
- Done when: on a device/emulator each button opens the right app with the right number; failure paths show a message.

### [x] 3.3 Wire actions into UI
- Do: buttons on detail screen per phone; long-press/swipe quick actions on list tiles.
- Done when: manual check of all three actions from list and detail.

---

## Phase 4 – Import / Export (Milestone 4)
### [x] 4.1 Spreadsheet interface + fixtures
- Do: define `SpreadsheetService { ImportResult parse(bytes); Uint8List build(data); Uint8List template(); }`, domain types (`ParsedSheet`, `ParsedRow`, `RowIssue`). Create fixture `.xlsx` files in `test/fixtures/` (valid multi-sheet, missing required, bad dates, dates as text and as date cells, extra columns, mixed-case headers, empty sheet).
- Done when: interface + fixtures committed; fixtures generated by a documented script (`tool/make_fixtures.dart`).

### [x] 4.2 Date parsing
- Do: `FlexibleDateParser` → `(month, day, year?)`; accepts Excel serials, `dd-MMM`, `dd/MM`, `dd-MM-yyyy`, ISO; validates day/month (Feb 29 allowed); rejects garbage with a reason.
- Tests: table-driven, ≥20 cases.
- Done when: tests green.

### [x] 4.3 Dart xlsx parser (import)
- Do: implement with the `excel` package: one sheet → one group; header match case-insensitive/trimmed; required `First Name`, `Phone 1`; per-row issues collected, never dropped silently.
- Tests: run against every fixture; assert imported rows + issue list.
- Done when: tests green.

### [x] 4.4 Import use-case (merge / replace)
- Do: `ImportService` applying parsed data to DB in a single transaction; Merge key = group + first name + surname + phone 1 (normalised); Replace clears then inserts; returns a summary (added/updated/skipped/issues).
- Tests: merge twice = idempotent; replace; rollback on failure.
- Done when: tests green.

### [ ] 4.5 Import UI
- Do: `file_picker` (SAF, no storage permission), preview screen (sheets, counts, issues list), choose Merge/Replace, confirm, result summary.
- Done when: importing a fixture on the emulator creates tabs + contacts; issues visible.

### [ ] 4.6 Export + template
- Do: implement `build` and `template`; export via `share_plus` and/or SAF "save as"; "Download blank template" action.
- Tests: round-trip — import fixture → export → re-import → equal data.
- Done when: tests green; exported file opens in Excel/Sheets with correct layout.

---

## Phase 5 – Events & notifications (Milestone 5)
### [ ] 5.1 EventCalculator
- Do: pure Dart `nextOccurrence(month, day, from)` (Feb 29 → Feb 28 in non-leap years), `eventsOn(date)`, `ageOrYears(year?, date)`; interface for later Rust swap.
- Tests: year rollover, leap day, same-day, no-year, timezone/DST-insensitive (date-only).
- Done when: tests green.

### [ ] 5.2 Today & Tomorrow screen
- Do: query all events, group into Today / Tomorrow; show type icon, name, age/years if known; "Send wishes" (WhatsApp/SMS with prefilled text); empty state.
- Tests: widget test with seeded dates and a fake clock (inject `Clock`).
- Done when: tests green; manual check.

### [ ] 5.3 Notification permissions & channel
- Do: `flutter_local_notifications`, `timezone`, `flutter_timezone`; manifest permissions (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, exact-alarm handling); notification channel; permission request flow with rationale screen; settings page shows status + deep link to system settings.
- Done when: a "test notification" button in Settings shows a notification on Android 13+ emulator.

### [ ] 5.4 Scheduler
- Do: `ReminderScheduler.rebuild()` — cancel all, schedule rolling 30-day window of daily summaries at user time (+ optional day-before); exact alarm if permitted else inexact; call rebuild on: app start, any contact/event change, settings change.
- Tests: unit test scheduling plan (which dates/messages) with fake clock; scheduler behind interface with fake.
- Done when: tests green; on emulator, set an event for tomorrow, advance via `adb shell` / change time, notification appears (`adb shell dumpsys alarm | findstr contactreminder` shows entries).

### [ ] 5.5 Background top-up & reboot
- Do: `workmanager` daily periodic task calling `rebuild()`; boot receiver (`ScheduledNotificationBootReceiver`) config; settings for notify time and lead days.
- Done when: after `adb reboot`, pending alarms are restored; worker runs (`adb shell cmd jobscheduler run ...` or WorkManager logs).

### [ ] 5.6 Battery-optimisation guidance
- Do: settings screen section explaining OEM background limits with button to open battery settings (`disable_battery_optimizations` / app settings intent).
- Done when: screen present; intent opens on emulator.

---

## Phase 6 – Rust core (Milestone 6, optional per decision)
### [ ] 6.1 Rust toolchain check
- Do: verify `rustup`, `cargo`, Android NDK, `cargo-ndk`, targets `aarch64-linux-android armv7-linux-androideabi x86_64-linux-android`; user installs if missing.
- Done when: `cargo ndk --version` works.

### [ ] 6.2 Bridge skeleton
- Do: `rust_core/` crate; `flutter_rust_bridge_codegen integrate` (v2); a trivial `ping()` function called from Dart; wire Gradle build of the Rust lib.
- Done when: debug APK builds and `ping()` returns from Rust on emulator.

### [ ] 6.3 Port event logic
- Do: Rust `next_occurrence`, `events_on`; expose via FRB; `RustEventCalculator` implements the Dart interface; re-run the **same** Dart tests against it + `cargo test`.
- Done when: both suites green; provider switch flips implementation.

### [ ] 6.4 Port phone normalisation
- Do: Rust `phonenumber` crate implementation; same test table.
- Done when: green.

### [ ] 6.5 Port xlsx (calamine + rust_xlsxwriter)
- Do: implement `SpreadsheetService` in Rust; run all fixtures + round-trip against it; compare with Dart output.
- Done when: identical results on all fixtures; release build size checked (report to user).

### [ ] 6.6 Switch default
- Do: make Rust impls the default; keep Dart impls only if the user wants a fallback, otherwise delete.
- Done when: full test suite + manual smoke on emulator green.

---

## Phase 7 – Polish & release (Milestone 7)
### [ ] 7.1 Settings screen completion (notify time, lead days, default country code, theme).
### [ ] 7.2 Accessibility & UX pass (labels, tap targets ≥48dp, large-font check, empty/error states, loading states).
### [ ] 7.3 App icon, app name, splash.
### [ ] 7.4 Full regression: `flutter analyze`, `flutter test`, `cargo test`, manual checklist on Android 12/13/14 (import, add/edit, call/SMS/WhatsApp, Today/Tomorrow, notification after reboot).
### [ ] 7.5 Release build: R8/minify, signing config (**ask the user; never generate/commit keys without approval**), build AAB/APK, install-test the release artifact.
### [ ] 7.6 Docs: update README (features, how to build, xlsx format with sample), privacy note (data stays on device), known limitations (WhatsApp cannot start calls; OEM background limits).
- Done when (each): checks in that line pass and are reported to the user.

---

## Manual test checklist (used in 7.4)
- [ ] Import 3-sheet file → 3 tabs, correct counts, issue report shown for bad rows
- [ ] Re-import (Merge) → no duplicates; (Replace) → replaced
- [ ] Add/edit/delete contact; DOB without year; Feb 29
- [ ] Call, SMS, WhatsApp from list and detail; WhatsApp not installed message
- [ ] Today/Tomorrow correct at midnight rollover
- [ ] Notification fires at set time; survives reboot; works with permission denied gracefully
- [ ] Export → open in Excel → re-import equal

## Decision log
| Date | Decision | Reason |
|---|---|---|
| 2026-09-18 | Flutter + SQLite(drift), no backend, Rust core in Phase 6 | See PROJECT_PLAN.md |
| 2026-09-19 | Other events = Name+Date pairs x3; Merge is default re-import | User choice |
| 2026-09-19 | All country codes supported: selectable default region in Settings (`settings.default_country_code` holds region/dial code), `+` numbers parse for any country | User: "include all possible country codes" |
| 2026-09-19 | Package id `com.example.contactreminder` | User choice |
| 2026-09-19 | Primary test device: Samsung Galaxy S24 (SM S921B, Android 16) over USB; SDK at E:\software\Android\Sdk; emulator Pixel_8 (API 34) optional | Device connected, licences accepted |
