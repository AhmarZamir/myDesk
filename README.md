# myDesk

myDesk is a cross-platform personal and shared life-management workspace built with Flutter for mobile and web from one product codebase.

The core principle is feature parity: anything a user can manage on mobile should also be manageable from the web.

## Core modules

- Personal dashboard
- Document vault
- Shared Desks for Family, Business, Roommates and trusted groups
- Bills and payment tracking
- Tasks and responsibility assignment
- Khata / shared expense tracking
- Activity and reminders
- Member roles and permissions

## Current implementation

The repository now includes:

- Responsive authenticated Flutter shell
- Email/password sign up and sign in with Supabase Auth
- Automatic profile creation after signup
- Persistent session handling
- Shared Desk creation
- Invite-code based Shared Desk joining
- Desk roles (`owner`, `admin`, `member`, `viewer`)
- PostgreSQL schema and RLS policies
- Security-definer membership helpers to avoid recursive RLS policies
- Runtime Supabase configuration via `--dart-define`

Documents, Bills, Tasks and Khata are represented in the database schema and are the next CRUD/storage implementation layer.

## Architecture

```text
Flutter Web + Flutter Mobile
           |
           v
     Supabase Client
           |
     +-----+----------------+
     |                      |
 Supabase Auth          Postgres + RLS
                            |
                       Shared Desks
                            |
              Documents / Bills / Tasks / Khata
```

## 1. Generate Flutter platform scaffolding

Because this repository started as an empty GitHub repository, generate Flutter's standard platform files once after cloning:

```bash
flutter create --platforms=android,web .
```

This preserves the existing `lib/` application code and creates the Android and Web runner files required by Flutter.

If you later build iOS from macOS, add the iOS runner with:

```bash
flutter create --platforms=ios .
```

## 2. Create a Supabase project

Create a Supabase project and copy its:

- Project URL
- Publishable key

Do not commit private service-role keys to this repository.

## 3. Run database migrations

Run these SQL migrations in order in the Supabase SQL editor or with the Supabase CLI:

```text
supabase/migrations/001_initial_schema.sql
supabase/migrations/002_auth_and_shared_desks.sql
supabase/migrations/003_fix_rls_membership.sql
```

## 4. Install dependencies

```bash
flutter pub get
```

## 5. Run on web

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 6. Run on Android

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Shared Desk flow

1. User creates an account.
2. Supabase automatically creates the matching `profiles` row.
3. User creates a Family, Business, Roommates or custom Desk.
4. The creator becomes the Desk owner automatically.
5. myDesk generates an invite code.
6. Another authenticated user enters that code to join the same Desk.
7. Both web and mobile read the same Desk and membership data.

## Security

The client only receives the Supabase publishable key. Access to user and Desk data is restricted by PostgreSQL Row Level Security policies. Sensitive service-role keys must never be embedded in Flutter builds.
