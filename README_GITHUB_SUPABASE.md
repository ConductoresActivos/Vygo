# VYGO Flutter + Supabase

## Supabase
Project URL already configured in `lib/config.dart`:
`https://jlpxiphqpwfpzsqiutfh.supabase.co`

Open Supabase → Project Settings → API Keys. Copy the **Publishable** key (or legacy `anon`) into `supabaseAnonKey` in `lib/config.dart`.

**Never use `service_role` in Flutter or commit it to GitHub.**

The existing database has these nine tables: `profiles`, `driver_profiles`, `vehicles`, `trips`, `trip_offers`, `trip_events`, `driver_locations`, `trip_ratings`, `admin_audit_log`.

Since those tables already exist, do not rerun the initial schema. Run only `supabase/vygo_driver_trips_policy.sql` in Supabase → SQL Editor.

## GitHub upload
1. Create a repository named `VYGO`.
2. Upload the CONTENTS of this folder to the repository root.
3. Check that `pubspec.yaml`, `lib/`, `supabase/`, and `.github/` are at the root.

## Build Android APK on GitHub
Open GitHub → Actions → **Build VYGO Android APK** → Run workflow. When it finishes, download the `vygo-android-release` artifact from that run.

## Local run
```bash
flutter create --platforms=android .
flutter pub get
flutter run
```

## Scope and limitations
Includes email/password auth, profile-role routing, initial passenger trip requests, driver offers, and a basic admin dashboard/driver approval. Maps/GPS, push notifications, payments, and server-side atomic offer acceptance are not included yet. Test RLS and workflows before production.

The existing admin role remains in `profiles.role = 'admin'`. The app does not allow users to self-register as admin.
