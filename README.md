# Munshi

*Your money's munshi — a private, offline-first personal finance & expense tracker for Android.*

Munshi (मुंशी — the traditional bookkeeper) keeps your ledger: quick 2-tap expense logging,
budgets, analytics, recurring entries, reminders, and Excel export with native charts — all
stored locally on your device, no account, no cloud.

## Status

🚧 Early development. See [`PLAN.md`](./PLAN.md) for the full implementation plan.

## Stack

- **Flutter + Dart** — Android APK
- **drift** (SQLite) for local reactive data
- **fl_chart** for in-app analytics
- **syncfusion_flutter_xlsio** for `.xlsx` export with embedded charts
- **flutter_local_notifications** for reminders

## Build

```bash
flutter pub get
flutter build apk --release
```

## Privacy

Offline-first. All financial data stays on-device in a local SQLite database.
No login, no bank linking, no cloud sync.
