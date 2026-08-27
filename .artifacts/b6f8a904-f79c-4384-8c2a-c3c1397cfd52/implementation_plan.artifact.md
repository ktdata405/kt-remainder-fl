# Implementation Plan - Toggle Local Storage

Add a toggle in the settings to enable or disable local storage for reminders. If disabled, the app will rely solely on Google Sheets for storage, while maintaining full functionality (scheduling, snoozing, completing).

## User Review Required

> [!IMPORTANT]
> When "Local Storage" is disabled, the app will fetch data from Google Sheets on every reload. Offline functionality will be limited as there will be no local cache. Notifications will still be scheduled on the device based on the data fetched from the sheet.

## Proposed Changes

### [Settings Component]

#### [MODIFY] [settings_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/services/settings_service.dart)
- Add `_kUseLocalStorage` key.
- Add `useLocalStorage` getter (defaulting to `true`).
- Add `setUseLocalStorage` setter that notifies listeners and clears the local database if set to `false` (optional, but cleaner).

#### [MODIFY] [settings_screen.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/settings/settings_screen.dart)
- Add a "Use Local Storage" switch in the "Reminders" section.

### [Reminder Component]

#### [MODIFY] [reminder_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_service.dart)
- Update `scheduleReminder`, `completeReminder`, `snoozeReminder`, `cancelReminder` to check `SettingsService.instance.useLocalStorage`.
- If `useLocalStorage` is `false`:
    - Skip `DatabaseService` (local DB) writes.
    - For `completeReminder` and `snoozeReminder`, fetch the reminder data from Google Sheets first (or use a runtime cache) to perform calculations like `advancedForCompletion`.
- Update `rescheduleActiveRemindersFromSheet` to skip local DB sync if `useLocalStorage` is `false`.
- Update `_findReminderById` to fetch from Sheets if not found in local DB or if local storage is disabled.

#### [MODIFY] [reminder_screen.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_screen.dart)
- Update `_reload` and `_initialize` to bypass `getLocalReminders()` if `useLocalStorage` is `false`.

## Verification Plan

### Manual Verification
1.  **Toggle ON (Default)**:
    *   Create a reminder.
    *   Verify it appears in the list immediately (from local DB).
    *   Verify it syncs to Google Sheets.
    *   Close and reopen the app; verify reminder is still there.
2.  **Toggle OFF**:
    *   Change setting to OFF.
    *   Verify the list reloads from Google Sheets.
    *   Create a reminder.
    *   Verify it syncs to Google Sheets.
    *   Verify it appears in the list (after fetch).
    *   Complete/Snooze a reminder and verify it updates on Google Sheets.
    *   Clear app cache/data (or just reinstall/reopen) and verify reminders are fetched from Sheets.
