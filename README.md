# myDesk

myDesk is a cross-platform personal and shared life-management workspace built with Flutter for mobile and web.

The product is designed around one idea: everything a user can do on mobile should also be available on the web from the same codebase.

## Core modules

- Personal dashboard
- Document vault
- Shared desks (Family, Business, Roommates, etc.)
- Bills and payment tracking
- Tasks and responsibility assignment
- Khata / shared expense tracking
- Activity and reminders
- Member roles and permissions

## Current architecture

```text
Flutter (Android / iOS / Web)
        |
        v
Shared application layer
        |
        v
Backend/API + PostgreSQL + object storage (next implementation stage)
```

## Run locally

1. Install Flutter.
2. Run `flutter pub get`.
3. Run on Chrome with `flutter run -d chrome`.
4. Run on a connected Android/iOS device with `flutter run`.

The current project contains the responsive application shell and initial MVP screens using local demo data so the product flow can be developed before wiring persistence and authentication.
