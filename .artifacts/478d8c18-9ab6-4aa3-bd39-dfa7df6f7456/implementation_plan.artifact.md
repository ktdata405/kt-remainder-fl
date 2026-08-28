# Implementation Plan: Default Local DB Saving Off

The goal is to change the default behavior of the app so that data is not saved to the local database or synced to Google Sheets unless the user explicitly enables it in the settings.

## Proposed Changes

### [Settings Service]
#### [MODIFY] [settings_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/services/settings_service.dart)
- Change the default value of `useLocalStorage` from `true` to `false`.

### [Reminder Service]
#### [MODIFY] [reminder_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_service.dart)
- Update `scheduleReminder`, `completeReminder`, `snoozeReminder`, `_applySnooze`, and `cancelReminder` to only perform remote sync if `useLocalStorage` is enabled.
- Update `rescheduleActiveRemindersFromSheet` to only perform remote sync if `useLocalStorage` is enabled.

### [Settings Screen]
#### [MODIFY] [settings_screen.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/settings/settings_screen.dart)
- (Optional) Update the setting label to reflect that it controls both local storage and cloud sync.

## Verification Plan

### Manual Verification
1.  **Fresh Install / Clear Data**: Verify that "Use Local Storage" is OFF by default in Settings.
2.  **Add Reminder (OFF)**: Add a reminder. Check that it is NOT saved to the local database (restart app to verify it's gone) and NOT synced to Google Sheets.
3.  **Enable Setting (ON)**: Turn ON "Use Local Storage".
4.  **Add Reminder (ON)**: Add a reminder. Check that it IS saved to the local database and IS synced to Google Sheets.
5.  **Actions (ON)**: Complete/Snooze a reminder and verify it updates in both local DB and Google Sheets.
