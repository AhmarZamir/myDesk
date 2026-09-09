# myDesk

myDesk is a cross-platform personal and shared life workspace built with Flutter for web and mobile from one codebase.

The product is designed around one rule: a user should only see the documents, bills, tasks, desks, and responsibilities that are relevant to them.

## Implemented product flows

- Email/password sign up and sign in
- Email confirmation feedback
- Forgot-password and password recovery flow
- Editable user profile
- Personal live dashboard with actionable counts
- Shared Desk creation and invite-code joining
- Owner / admin / member / viewer roles
- Member directory and role management
- Invite-code rotation
- Leave desk and delete desk flows
- Secure document upload to Supabase Storage
- Image preview in-app and external opening for other file types
- Document expiry dates and dashboard reminders
- Document access modes:
  - Only me
  - Whole Shared Desk
  - Selected people
- Per-person document access enforced in PostgreSQL RLS and Storage policies
- Bill creation, assignment, due dates, paid/unpaid state
- Task creation, assignment, priority, due date, pending/in-progress/completed state
- Personal Khata tracking and settlement
- Responsive Flutter UI for web and mobile
- Vercel deployment configuration
- GitHub Actions checks with `flutter analyze` and `flutter test`

## Architecture

```text
Flutter Web + Flutter Mobile
           |
           v
     Supabase Client
           |
     +-----+------------------+
     |                        |
 Supabase Auth          PostgreSQL + RLS
                              |
                       Supabase Storage
                              |
      Profiles / Shared Desks / Documents / Bills / Tasks / Khata
```

## 1. Flutter setup

The repo contains the Flutter web runner. If you also want Android/iOS project runners locally, generate them once after cloning:

```bash
flutter create --platforms=android,web .
```

On macOS, iOS can be added with:

```bash
flutter create --platforms=ios .
```

Then install packages:

```bash
flutter pub get
```

## 2. Supabase setup

Create a Supabase project and copy:

- Project URL
- Publishable / anon client key

Never commit a Supabase service-role key into Flutter or GitHub.

## 3. Run all database migrations

For a new Supabase project, run every file in `supabase/migrations` in numeric order:

```text
001_initial_schema.sql
002_auth_and_shared_desks.sql
003_fix_rls_membership.sql
004_workspace_modules.sql
005_shared_document_storage_access.sql
006_backfill_profiles.sql
007_ensure_current_profile.sql
008_fix_invite_code_generator.sql
009_document_access_control.sql
010_product_readiness.sql
011_security_followup.sql
012_transfer_ownership_and_cleanup.sql
```

If your database already has migrations `001` through `009`, only apply `010`, `011`, and `012` now.

## 4. Supabase Auth settings

For password-reset and email-confirmation links, configure the deployed myDesk URL in Supabase:

1. Open **Authentication → URL Configuration**.
2. Set **Site URL** to the production Vercel URL.
3. Add the same production URL to **Redirect URLs**.
4. If using preview deployments, add the preview pattern you intentionally support.

Without this, Supabase may send confirmation/reset links to the wrong destination.

## 5. Run locally

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 6. Vercel deployment

Add these Environment Variables to Vercel:

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
```

The Vercel build intentionally fails when either variable is missing. The build script also runs `flutter analyze` before creating the production web build.

## Permission model

### Documents

A document owner chooses one of three access modes during upload:

- `private`: only the owner
- `desk`: every current member of the selected Shared Desk
- `custom`: only specifically selected current members

Removing a person from a Shared Desk immediately removes their effective access to custom document grants as well.

### Bills

A user sees a bill when they:

- created it,
- are responsible for it, or
- manage the related Shared Desk.

### Tasks

A user sees a task when they:

- created it,
- are assigned to it, or
- manage the related Shared Desk.

### Shared Desk roles

- `owner`: full control over the desk and roles
- `admin`: manages members and invite codes
- `member`: normal collaboration
- `viewer`: limited participant; cannot create desk-linked content

Invite codes are returned only to owners/admins through the secure RPC used by the app.

## User acceptance checklist

Before calling a production deployment complete, test these flows with at least three accounts:

1. **Account A** signs up, confirms email, signs in, edits profile, signs out/in.
2. Account A creates a Family Desk.
3. Account B joins using the invite code.
4. Account A uploads a private document → only A sees it.
5. A uploads a Whole Desk document → A and B see it.
6. Account C joins the desk.
7. A uploads a Selected People document for B only → B sees it; C does not.
8. Remove B from the desk → B loses access to desk/custom documents.
9. Assign a bill to C → C sees and updates it; unrelated members do not.
10. Assign a task to C → C can move it through pending/in-progress/completed.
11. Create due dates and an expiring document → Home surfaces them when relevant.
12. Rotate the invite code → the old code stops working.
13. A non-owner leaves a desk → desk-only content disappears for that user.
14. Owner/admin controls only appear to users with those roles.
15. Forgot-password email returns to myDesk and allows setting a new password.
16. Verify image preview renders inside myDesk and non-image files open externally.
17. Verify desktop and mobile-width layouts expose the same functionality.

## Automated checks

GitHub Actions runs on pushes and pull requests:

```bash
flutter pub get
flutter analyze
flutter test
```

There is also a startup smoke test to ensure the Flutter app can boot without runtime credentials.

## Production notes

- Keep the Supabase Storage `documents` bucket private.
- Use only the publishable client key in Vercel/Flutter.
- Do not weaken RLS policies to fix UI errors; fix the user flow or RPC instead.
- Test migrations against a staging Supabase project before applying future destructive schema changes to production.
