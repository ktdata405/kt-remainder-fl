# Battery Usage Analysis & Optimization for kt-remainder-fl

This document outlines how to diagnose battery consumption and provides specific optimizations for the current Flutter/Android implementation.

## 1. How to Get Battery Usage Data & Stacks

### A. Android Studio Energy Profiler (Internal Tool)
The fastest way to see real-time battery impact:
1.  Connect your device and run the app.
2.  Open **View > Tool Windows > Profiler**.
3.  Click the **+** icon to start a session for your app.
4.  Select the **Energy** row. It monitors:
    *   **CPU**: High spikes suggest heavy UI loops or background processing.
    *   **Network**: Frequent radio wake-ups are a primary battery drainer.
    *   **GPS**: Location tracking (if used).

### B. Battery Historian (Advanced System-wide)
For a deep dive into "Doze" mode and wake locks:
1.  Reset stats: `adb shell dumpsys batterystats --reset`
2.  Use the app for 10–20 minutes.
3.  Generate report: `adb bugreport bugreport.zip`
4.  Upload to [Battery Historian](https://github.com/google/battery-historian).

### C. CPU Stacks (Finding the Code)
If you see high CPU usage in the profiler:
1.  In the **Profiler**, click the **CPU** timeline.
2.  Click **Record** to capture a method trace.
3.  For Flutter logic, use **Flutter DevTools > CPU Profiler** to see which Dart functions are taking the most time.

---

## 2. Identified Battery "Hotspots" in Your Code

Based on the analysis of [reminder_service.dart](file:///Users/kalyanthammineni/Downloads/ktdata405/kt-remainder-fl/lib/remainder/reminder_service.dart):

### 🚨 Hotspot 1: Exact Alarms While Idle
The app uses `AndroidScheduleMode.exactAllowWhileIdle`.
- **Problem**: This forces the Android system to wake up the device even during **Doze mode** (deep sleep). If a user has many reminders, the device never enters a low-power state.
- **Evidence**: `ReminderService#_scheduleNotification` line 259.

### 🚨 Hotspot 2: Aggressive Network Polling & Sync
Every action (Complete, Snooze, Schedule) triggers an immediate `http.get` call to a Google Apps Script URL.
- **Problem**: Turning on the mobile radio for small, frequent requests is extremely expensive.
- **Evidence**: `_upsertRemote` and `fetchRemindersFromSheet` are called frequently.

### 🚨 Hotspot 3: Lack of Local Persistence
The app fetches everything from the remote sheet on every initialization/boot.
- **Problem**: Intensive network activity immediately after device boot.

---

## 3. Proposed Optimizations

### Optimization A: Use Inexact Alarms
Change `exactAllowWhileIdle` to `inexactAllowWhileIdle` or just `exact` (without `whileIdle`) if precision isn't strictly necessary for all reminders. Android can then batch these alarms together, reducing wake-ups.

```dart
// lib/remainder/reminder_service.dart
androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
```

### Optimization B: Implement Local Caching (Offline First)
Use a local database (e.g., `sqflite` or `hive`) to store reminders.
- Perform UI updates immediately using local data.
- Sync with the Google Sheet in batches or using a **WorkManager** task that only runs when the device is charging or on Wi-Fi.

### Optimization C: Network Batching
Instead of calling the network on every `completeReminder` or `snoozeReminder`, queue these changes and push them once every few minutes or when the app is backgrounded.

### Optimization D: Lifecycle-Aware Sync
In `main.dart` or `ReminderService`, ensure that background loops (like the 30s timer for Web) are strictly disabled on Android when the app is in the background.

---

## Next Steps
Would you like me to help you implement the **Local Caching** or switch to **Inexact Alarms** to reduce the battery footprint?
