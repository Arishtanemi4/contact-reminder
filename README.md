# Contact Reminder

Android app that imports contacts from a multi-sheet .xlsx (one sheet per
group), lets you call / WhatsApp / SMS them, edit and export contacts, and
reminds you of birthdays, anniversaries and other important dates.

Plans: [docs/plan/PROJECT_PLAN.md](docs/plan/PROJECT_PLAN.md) (what) and
[docs/plan/EXECUTE.md](docs/plan/EXECUTE.md) (build steps).

## Features

- **Import contacts from .xlsx** — one sheet per group (e.g. "Friends",
  "Relatives"); bad rows are reported, not silently dropped.
- **Export contacts to .xlsx** in the same format, for backup or editing in
  a spreadsheet app.
- **Call / SMS / WhatsApp** a contact's phone numbers directly from the app.
- **Reminders** for birthdays, anniversaries and up to 3 other custom events
  per contact, with a lead-time and daily notification time you choose in
  Settings.
- **Edit contacts and groups** in-app after import.
- Light/dark theme, works fully offline.

## How to build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) and
Android SDK/platform-tools.

```
cd app
flutter pub get
flutter build apk --release      # installable .apk
flutter build appbundle --release  # .aab, for Play Store-style distribution
```

**Release signing:** the release build looks for `app/android/key.properties`
(gitignored). Copy `app/android/key.properties.example` to
`app/android/key.properties` and fill in your own keystore details:

```
cd app/android
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

If `key.properties` doesn't exist, the release build falls back to the debug
signing key (so `flutter run --release` still works, e.g. on CI) but the
result should not be distributed as-is.

## xlsx import/export format

One sheet per group; the sheet name becomes the group name. Row 1 is the
header row with these exact column titles (case/whitespace-insensitive on
import):

| Column | Required | Notes |
|---|---|---|
| First Name* | yes | |
| Surname | no | |
| Phone 1* | yes | at least one phone is required |
| Phone 2 | no | |
| Phone 3 | no | |
| Date of Birth | no | |
| Marriage Anniversary | no | |
| Event 1 Name | no | paired with Event 1 Date |
| Event 1 Date | no | |
| Event 2 Name | no | paired with Event 2 Date |
| Event 2 Date | no | |
| Event 3 Name | no | paired with Event 3 Date |
| Event 3 Date | no | |
| Email | no | |
| Address | no | |

Dates accept `dd-MMM-yyyy` (e.g. `15-Aug-1990`), `dd/MM/yyyy`, `dd-MM-yyyy`,
ISO `yyyy-MM-dd`, or a native Excel date cell. The year is optional (e.g.
`05-Mar` for a birthday you don't want a year attached to). Phone numbers are
parsed assuming India (`+91`) as the default region if no country code is
given; include a `+<country code>` prefix for other countries.

Use **Download blank template** in the Contacts screen (toolbar icon) to get
a correctly-headed, empty .xlsx to fill in, or **Export** to get your current
contacts in the same format.

## Privacy

All data (contacts, groups, events, settings) is stored locally on-device in
a SQLite database. Nothing is sent to a server or synced to the cloud — the
app has no backend and does not require network access to function
(WhatsApp/SMS/call actions hand off to the respective installed apps, which
have their own network and privacy behavior).

## Known limitations

- **WhatsApp cannot start voice/video calls from another app.** The
  WhatsApp button opens a chat with the contact (via `wa.me`); it cannot
  initiate a WhatsApp call — that's a WhatsApp platform restriction, not
  something this app can work around.
- **OEM background limits.** Some Android manufacturers (Xiaomi, Oppo,
  Vivo, etc.) aggressively kill scheduled background work to save battery,
  which can delay or drop reminder notifications. If reminders stop firing,
  disable battery optimization for this app in Android's system settings.
- **No way to add a first contact without importing a file.** On a brand
  new install there are no groups yet, and contacts can only be added inside
  a group, so you must import (or download the blank template, fill it in,
  and import it) before you can add anyone by hand. Tracked as a backlog
  item for a future version — see
  [docs/plan/EXECUTE.md](docs/plan/EXECUTE.md).
