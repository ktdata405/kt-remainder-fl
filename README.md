# Reminders — Flutter Web App

A Flutter web app that schedules reminders synced to a Google Sheet via a free Google Apps Script Web API.

## Architecture

| Layer | File | Purpose |
|---|---|---|
| Config | `lib/config/app_config.dart` | Runtime config (gitignored) |
| Model | `lib/remainder/reminder_model.dart` | `Reminder` data class |
| Service | `lib/remainder/reminder_service.dart` | HTTP ↔ Apps Script, local notifications |
| UI | `lib/remainder/reminder_screen.dart` | List screen + add bottom sheet |
| Entry | `lib/main.dart` | App bootstrap, light/dark theme |
| Script | `scripts/apps_script.gs` | Google Apps Script source to deploy |

## Setup (one-time, completely free)

### 1 — Deploy the Apps Script

1. Open your Google Sheet
2. Click **Extensions → Apps Script**
3. Delete any existing code and paste the full contents of `scripts/apps_script.gs`
4. Click **Deploy → New deployment → Web app**
   - Execute as: **Me**
   - Who has access: **Anyone**
not fee5. Click **Deploy** and copy the **Web app URL**

### 2 — Add your config file

Create `lib/config/app_config.dart` (gitignored):

```dart
const String kWebAppUrl = 'PASTE_YOUR_WEB_APP_URL_HERE';
```

### 3 — Run

```bash
flutter pub get
flutter run -d chrome
```

## Features

- Reminder list loaded from Google Sheet on startup and pull-to-refresh
- Add reminders via FAB → bottom sheet form (title, description, date/time, repeat)
- Repeat options: none, daily, weekly, monthly
- Cancel active reminders (keeps history in sheet with `isActive=false`)
- Local notifications on Android (best-effort, skipped on web)
- Light and dark theme toggle

## Sheet columns

`id` · `title` · `body` · `scheduledTime` · `repeatFrequency` · `isActive`