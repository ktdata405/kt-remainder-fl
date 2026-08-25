# Battery Optimization & Local Persistence Implementation Plan

This plan aims to reduce battery consumption by minimizing device wake-ups and network activity. We will implement inexact alarms, a local database for "Offline First" functionality, and a lazy sync strategy.

## Proposed Changes

### 1. Dependency Updates
We need to add `sqflite` and `path` for local database support.

#### [MODIFY] [pubspec.yaml](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/pubspec.yaml)
- Add `sqflite: ^2.3.0`
- Add `path: ^1.9.0`

---

### 2. Local Persistence (Option 2)
Create a database layer to store reminders locally.

#### [NEW] [database_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/services/database_service.dart)
- Implement `DatabaseService` using `sqflite`.
- Define table schema for `reminders`.
- Methods for CRUD operations.

---

### 3. Battery Efficiency (Option 1)
Modify notification scheduling to be more system-friendly.

#### [MODIFY] [reminder_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_service.dart)
- Change `AndroidScheduleMode.exactAllowWhileIdle` to `AndroidScheduleMode.inexactAllowWhileIdle`.
- This allows Android to batch your alarms with others, significantly reducing CPU wake-ups.

---

### 4. Efficient Sync Strategy (Option 3)
Refactor `ReminderService` to prioritize local data and minimize network radio usage.

#### [MODIFY] [reminder_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_service.dart)
- **Initialize**: Load from local DB first, then fetch from Sheet in the background.
- **Actions (Schedule/Complete/Snooze)**: Update local DB immediately for instant UI feedback, then push to Google Sheets.
- **Network Optimization**: Ensure network calls don't block the UI and handle failures gracefully.

---

## Verification Plan

### Automated Tests
- I will attempt to run `flutter pub get` to verify dependencies.
- (Manual check) Verify that the app still functions correctly (scheduling/completing reminders).

### Manual Verification
- Verify that reminders are saved locally and persist across app restarts without network.
- Observe the **Energy Profiler** in Android Studio to confirm reduced network/CPU spikes when performing actions.
