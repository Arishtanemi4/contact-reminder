# Contact Reminder (Android) – Plan

## Context
Build an Android app that imports contacts from a multi-sheet .xlsx (one sheet = one group: Friends, Relatives, Office…), shows each group as a tab, lets the user call / WhatsApp / SMS a contact, add/edit contacts, export back to .xlsx, notify on important dates, and show today's and tomorrow's birthdays/anniversaries. The directory is empty (greenfield). On approval, this plan is copied to `E:\dev\contact-reminder\docs\plan\PROJECT_PLAN.md` (the only deliverable of this step; no app code yet).

## Stack recommendation

**No backend.** Data is personal, single-user, and must work offline; notifications must fire without a server. A server adds hosting, auth, privacy and sync problems with no requirement to justify them. "Backend" = an on-device core layer.

| Layer | Choice | Why |
|---|---|---|
| Database | **SQLite** (Flutter: `drift`) | Yes, SQLite. Relational, typed queries, migrations, on-device. |
| Frontend | **Flutter** (Dart) | One codebase, tabs/lists/forms are first-class, best plugin coverage for local notifications, url_launcher, file picker. Chosen over React Native because the Rust bridge (below) is mature for Flutter (`flutter_rust_bridge`), and over Kotlin/Compose because you may want iOS later. |
| Core logic | **Rust (optional but recommended for learning)** via `flutter_rust_bridge` v2 | xlsx parsing (`calamine`), xlsx writing (`rust_xlsxwriter`), date/next-occurrence logic, phone normalisation. Pure functions with no UI = ideal first Rust project: easy to unit-test, well-bounded FFI surface. |
| Notifications | `flutter_local_notifications` + `timezone`, WorkManager for daily refresh | |
| Java | Not used. | Rust replaces it for the "backend" role; Java/Kotlin gives no advantage here. |

**Honest cost of Rust:** needs `cargo-ndk`, Android NDK and 3–4 ABI targets; Windows toolchain setup is the fiddly part. Mitigation: define a Dart interface `SpreadsheetService` with a Dart implementation (`excel` package) first, then swap in the Rust one in its own milestone. If Rust setup blocks, the app still ships.

## Key design decisions

**Data model (SQLite)**
- `groups(id, name, sort_order)` – from sheet names.
- `contacts(id, group_id, first_name NOT NULL, surname, email, address, created_at, updated_at)`
- `contact_phones(id, contact_id, position 1..3, number_raw, number_e164)` – ≥1 required.
- `contact_events(id, contact_id, type[birthday|anniversary|other], label, month, day, year NULL)` – year optional, so store month/day separately; age/years-married shown only when year is known. Feb 29 → observed on Feb 28 in non-leap years.
- `settings(notify_time, default_country_code, lead_days)`.

**xlsx format** (header row, case-insensitive matching, extra columns ignored):
`First Name*`, `Surname`, `Phone 1*`, `Phone 2`, `Phone 3`, `Date of Birth`, `Marriage Anniversary`, `Event 1 Name`, `Event 1 Date`, `Event 2 Name`, `Event 2 Date`, `Event 3 Name`, `Event 3 Date`, `Email`, `Address`.
- Dates accepted as Excel date cells or text: `dd-MMM`, `dd/MM`, `dd-MM-yyyy`, ISO. Missing year allowed.
- Import returns a per-row report (imported / skipped with reason: missing first name, no phone, bad date) shown to user; never silently drops rows.
- Re-import: user chooses *Merge* (match on group + first name + surname + phone 1; update) or *Replace all*. Default Merge.
- Export writes the same layout, one sheet per group, so the file round-trips. Provide "Download blank template".
- Open question for user: the "other events" columns above (name+date pairs, up to 3) is my interpretation; alternative is a single cell `Name: dd-MMM; Name: dd-MMM`.

**Calling / messaging**
- Phone call: `tel:` intent opens the dialer (no `CALL_PHONE` permission, Play-policy friendly). Direct-call is not needed.
- SMS: `sms:` URI with optional prefilled body.
- WhatsApp call/message: `https://wa.me/<E.164 digits>` (chat opens; the user taps call). WhatsApp has no public deep link that starts a voice call directly – stated as a limitation. Check `queryIntentActivities`/`<queries>` for WhatsApp and WhatsApp Business installed.
- Numbers normalised to E.164 using a default country code setting (needed for wa.me).

**Notifications (the riskiest Android area)**
- Daily reminder at user-set time (default 08:00): "Birthdays/anniversaries today: …" plus optional day-before reminder.
- Schedule a rolling window (next ~30 days) of notifications instead of one per event forever (some OEMs cap pending alarms ~50–500). WorkManager periodic job (daily) tops the window up; a boot receiver reschedules after reboot.
- Android 13+: runtime `POST_NOTIFICATIONS`. Android 12+: exact alarms need `SCHEDULE_EXACT_ALARM`; fall back to inexact alarms if denied (a few minutes' drift is acceptable for birthdays).
- Battery-optimisation guidance screen for aggressive OEMs (Xiaomi, Oppo, etc.).
- Optional: home-screen widget for today's events (later phase).

**Screens**
1. Home: `TabBar` of groups (from sheet names) → searchable contact list; FAB add.
2. Contact detail: phones with call/WhatsApp/SMS buttons, events, email, address; edit/delete.
3. Add/Edit form with validation (first name + phone 1 required, date pickers with "no year" toggle).
4. Today & Tomorrow: birthdays/anniversaries/other events, quick "Send wishes" (WhatsApp/SMS with prefilled text).
5. Import/Export: pick file via Storage Access Framework (no storage permission), preview + row report, export via share/save.
6. Settings: notify time, lead days, default country code, theme.

**Architecture:** feature-first folders; Riverpod for state; repository layer over drift; `SpreadsheetService` and `EventCalculator` behind interfaces (Dart impl → Rust impl). Contacts DB is the source of truth; xlsx is import/export format only.

## Project layout
```
contact-reminder/
  docs/plan/PROJECT_PLAN.md
  app/            # Flutter project
    lib/{core,data,features/{contacts,events,import_export,settings}}
  rust_core/      # Rust crate (Phase 5): xlsx + events + phone
```

## Milestones
1. **Scaffold & data** – Flutter project, drift schema, migrations, seed data, repository tests.
2. **Contacts UI** – group tabs, list/search, detail, add/edit/delete.
3. **Actions** – call, SMS, WhatsApp, number normalisation, missing-app handling.
4. **Import/Export** – xlsx (Dart `excel` impl), row report, merge/replace, template, export.
5. **Events & notifications** – next-occurrence logic, Today/Tomorrow screen, scheduling, boot/WorkManager, permissions flows.
6. **Rust core** – port xlsx + event logic to Rust via flutter_rust_bridge; keep Dart tests as the contract; cross-check outputs on the same fixtures.
7. **Polish & release** – battery-optimisation guide, dark mode, accessibility, app icon, signed release APK/AAB, privacy note (data stays on device).

## Testing / verification
- Unit: date parsing (no year, Feb 29, text vs date cells), next-occurrence, E.164 normalisation, import row validation (fixture .xlsx with multiple sheets, missing required fields, bad dates).
- Round trip: import fixture → export → re-import → identical data.
- Integration: drift in-memory DB; widget tests for tabs and forms.
- Device/emulator: `flutter run` on Android 12, 13, 14 emulator; verify `tel:`/`sms:`/`wa.me` launch; set a birthday to tomorrow and confirm the notification via `adb shell dumpsys alarm` and after reboot; test on a real Xiaomi/Samsung device for background reliability.

## Risks
- OEM background killers may delay notifications → daily WorkManager top-up + user guidance.
- WhatsApp cannot be forced to place a call → documented limitation.
- Rust/NDK toolchain on Windows → isolated in Milestone 6 with Dart fallback.

## Next step on approval
Create `docs/plan/` and write this content (expanded per section) to `docs/plan/PROJECT_PLAN.md`. No code scaffolding until you confirm the stack.
