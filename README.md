# myDesk

myDesk is a cross-platform personal and shared life workspace built with Flutter for web and mobile from one codebase.

The product is designed around one rule: a user should only see the documents, bills, tasks, desks, Buddies, notifications, and responsibilities that are relevant to them.

## Implemented product flows

- Email/password sign up and sign in
- Email confirmation feedback
- Forgot-password and password recovery flow
- Editable user profile with profile photo/avatar
- Personal live dashboard with actionable counts
- Assigned tasks surfaced directly on Home
- Live unread badges on Tasks and Khata
- Database-generated notifications for task assignment/status changes and Buddy Khata changes
- **myDesk Buddies** for reusable person-to-person connections
- Referral link / referral code Buddy onboarding
- Direct document sharing with a Buddy without creating a group
- Add an existing Buddy into any Shared Desk you manage
- Bilateral Buddy Khata: creator can edit; Buddy sees the same ledger read-only from their own inflow/outflow perspective
- Shared Desk creation and invite-code joining
- Owner / admin / member / viewer roles
- Member directory and role management
- Invite-code rotation
- Leave desk, ownership transfer, and delete desk flows
- Secure document upload to Supabase Storage
- Image preview in-app and external opening for other file types
- Document expiry dates and dashboard reminders
- Document access modes: private, whole Shared Desk, or selected people
- Per-person document access enforced in PostgreSQL RLS and Storage policies
- Bill creation, assignment, due dates, paid/unpaid state
- Task creation, assignment, priority, due date, pending/in-progress/completed state
- Personal and Buddy-aware Khata tracking and settlement
- Black + electric-blue Material 3 theme across web and mobile
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
 Profiles / Buddies / Notifications / Shared Desks / Documents / Bills / Tasks / Khata
```

## Supabase migrations

For a new project, run every file in `supabase/migrations` in numeric order through:

```text
014_notifications_and_avatars.sql
```

If your production database already has `001` through `013`, apply only:

```text
014_notifications_and_avatars.sql
```

Migration `014` adds:

- `notifications`
- task assignment/status notification triggers
- Buddy Khata notification triggers
- unread notification count helpers
- Realtime notification publication
- the `avatars` Storage bucket and owner-only avatar write policies

## Buddy model

A Buddy is a trusted one-to-one connection independent of any Shared Desk.

- A user generates a referral link or referral code.
- The other user opens the link, signs in if necessary, and myDesk opens the Buddies area automatically.
- Once connected, both users retain each other in their Buddy list.
- A Buddy can be reused for direct document sharing, Buddy Khata, or adding into a Shared Desk.
- Removing a Buddy does not silently remove them from Shared Desks they already joined.

### Direct documents

A file can be shared directly with a Buddy without creating a Shared Desk. The recipient sees the document through the same private Storage/RLS access model and cannot change the owner's access settings.

### Buddy Khata

A Khata entry may remain a private manual note or be attached to a Buddy.

For a Buddy-linked entry:

- the creator owns the entry and can settle/delete it;
- the Buddy receives read-only access;
- both see the same amount/note/status;
- the direction is automatically inverted for the Buddy, so “they owe me” for the creator appears as “you owe them” for the Buddy;
- each user gets their own inflow/outflow summary based on their perspective;
- the Buddy receives an unread Khata notification when a shared entry is created/updated.

## Notifications

Notifications are created server-side so clients cannot forge assignment alerts.

- Assigning a task to another user creates a Task notification for that assignee.
- Changing task status can notify the relevant creator/assignee.
- Creating/updating Buddy Khata creates a Khata notification for the connected Buddy.
- Unread counts appear as badges/dots on Tasks and Khata navigation items.
- Opening the corresponding module marks that category as read.
- Assigned unfinished tasks also appear directly on Home regardless of whether they have a due date.

## Profile photos

Users can upload JPG, PNG or WebP profile images up to 5 MB from the account dialog. The image is stored under the user's own folder in the `avatars` bucket and the resulting URL is stored in `profiles.avatar_url`.

## Supabase Auth settings

For password-reset, confirmation, and Buddy referral links, configure the deployed myDesk URL in Supabase:

1. Open **Authentication → URL Configuration**.
2. Set **Site URL** to the production Vercel URL.
3. Add the same production URL to **Redirect URLs**.

## Local run

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Vercel

Set:

```text
SUPABASE_URL
SUPABASE_PUBLISHABLE_KEY
```

The build script runs analysis before producing the release web build.

## User acceptance checklist

Test with at least three accounts:

1. Account A signs up, uploads a profile photo, refreshes, and sees it retained.
2. A creates a Buddy referral link and B connects.
3. A assigns a task to B → B sees a Task badge and the task appears on B's Home under **Assigned to you**.
4. B opens Tasks → Task badge clears.
5. B changes task status → the relevant user receives a task update notification.
6. A creates a Buddy Khata entry for B → B sees a Khata badge and the same ledger read-only from B's perspective.
7. B opens Khata → Khata badge clears.
8. A directly shares a document with B without a Shared Desk → B sees it; C does not.
9. Verify private / whole-desk / selected-person document sharing still works.
10. Verify the black + blue theme remains readable across desktop and mobile widths.

## Automated checks

GitHub Actions runs:

```bash
flutter pub get
flutter analyze
flutter test
```

Never weaken RLS to fix a UI error; keep access decisions enforced in the database and Storage policies.
