# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PDM Rutine — Flutter mobile app for technical maintenance management. Single-user, offline-first.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Run on specific device
flutter run -d <device-id>

# List available devices
flutter devices

# Build APK (release)
flutter build apk --release

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Generate Riverpod code (run after editing @riverpod annotated files)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs
```

## Architecture

Feature-first structure under `lib/`:

```
lib/
  main.dart                     # Entry point: DB init, notifications, ProviderScope
  core/
    database/database_helper.dart   # SQLite singleton with full schema
    theme/app_theme.dart            # Material 3 light/dark themes
    router/app_router.dart          # go_router config + route constants
  features/
    shell/shell_screen.dart         # NavigationBar shell wrapping all tabs
    clients/                        # Client CRUD module
    calendar/                       # table_calendar monthly view
    maintenance/                    # Maintenance record forms
    templates/                      # Reusable maintenance templates
```

Each feature follows the same internal layout:
- `data/` — repository (raw SQL operations via DatabaseHelper)
- `models/` — plain Dart model class with `fromMap`/`toMap`
- `providers/` — Riverpod providers (state + async operations)
- `screens/` — Widget screens

## Key Decisions

- **State**: Riverpod (`flutter_riverpod` + `riverpod_annotation`). Use `@riverpod` code generation for new providers.
- **Database**: SQFlite via `DatabaseHelper.instance.database`. Schema defined in `_onCreate`. Foreign keys are enabled (`PRAGMA foreign_keys = ON`).
- **Navigation**: `go_router` with a `ShellRoute` for the bottom tab bar. Route constants (`kClientsPath`, etc.) live in `app_router.dart`.
- **Notifications**: `flutter_local_notifications` instance exposed as `notificationsPlugin` global in `main.dart`. `timezone` package initialized at startup.
- **PDF**: `pdf` + `printing` packages for generation and preview/share.
- **Email**: `flutter_email_sender` for sending PDFs as attachments.

## Database Schema

Four tables: `clients`, `appointments`, `templates`, `maintenance_records`.
`appointments.notification_id` stores the integer ID used by `flutter_local_notifications` to cancel/update scheduled alerts.
`maintenance_records` can reference both an `appointment` and a `template` (both nullable with `ON DELETE SET NULL`).

## Android Setup Required

For `flutter_local_notifications` (scheduled notifications), add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

For `flutter_email_sender`, a `FileProvider` entry is needed in `AndroidManifest.xml` to attach PDFs — see package README.
