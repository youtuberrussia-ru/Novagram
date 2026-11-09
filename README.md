# Novagram — Flutter messenger foundation

Novagram is an Android-first Flutter messenger foundation using Supabase for email/password authentication, profiles, direct chats, group chats, and realtime text messages.

## Implemented

- Email/password registration and sign-in.
- Optional email confirmation through Supabase Auth.
- Auth state gate and sign-out.
- Automatic profile creation after a new account is created.
- Editable profiles with display name, unique username, and short bio.
- User search, direct chats, and group creation with participant selection.
- Realtime text-message stream with timestamps and message composer.
- PostgreSQL schema and Row Level Security policies.
- GitHub Actions workflow that analyzes the Dart project, builds a debug APK, and uploads it as an artifact.

Voice/video calls, media sharing, push notifications, end-to-end encryption, moderation, and AI tools are not implemented yet.

## 1. Configure Supabase

1. Create or open your Supabase project.
2. In **Authentication → Providers → Email**, make sure Email provider is enabled.
3. Decide whether email confirmation should be required. If enabled, users must confirm their email before signing in.
4. Apply the database schema using the repository's **Apply Supabase database migrations** workflow.

Email authentication does not require an SMS provider. Phone-number sign-in is not used by this version.

## 2. Configure GitHub Actions

In **Settings → Secrets and variables → Actions → Variables**, add:

- `SUPABASE_URL` — your Supabase project URL.
- `SUPABASE_PUBLISHABLE_KEY` — your public publishable key.

The database migration workflow also needs `SUPABASE_DB_URL` stored as an Actions secret. Never put the database password or a Supabase service-role key in app code, the APK, or chat.

## 3. Build the Android APK

1. Open **Actions**.
2. Select **Build Novagram Android APK**.
3. Tap **Run workflow**.
4. When the run succeeds, download the `novagram-debug-apk` artifact.

## Current limitations

This is an early messenger foundation, not a finished commercial messenger. Email registration does not itself provide voice/video calls. Calls require a separate WebRTC/signaling implementation; reliable incoming-call notifications also require push notification infrastructure.
