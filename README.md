# Novagram — starter 0.1.0

Novagram is a modular Flutter messenger foundation. This starter establishes phone-number
authentication, a Supabase-backed profile/chat data model, private database policies,
and a GitHub Actions Android APK build.

## Current milestone

- Phone-number sign-in with SMS OTP through Supabase Auth.
- Auth state gate and sign-out.
- Profile records created automatically when a user registers.
- Chat list, user search, direct-chat creation, and realtime message stream foundation.
- PostgreSQL schema and Row Level Security policies.
- Android APK build workflow.

This is a foundation, not a claim that every planned feature is already implemented.
Voice/video calls, push notifications, file uploads, end-to-end encryption, channels,
AI features, and the 1,000-feature roadmap are later modules.

## 1. Create a Supabase project

1. Create a project in Supabase.
2. In **Authentication → Providers → Phone**, enable phone authentication.
3. Configure an SMS provider in Supabase. SMS delivery may have a cost.
4. Open **SQL Editor**, paste `supabase/schema.sql`, and run it.
5. Copy the project URL and the publishable/anon client key from project API settings.

## 2. Run locally

Install Flutter, then run:

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Use the public anon/publishable key only. Never put the `service_role` key in the app,
GitHub repository, or APK.

## 3. Build APK using GitHub Actions

1. Upload this project to a GitHub repository.
2. Open **Actions** and run **Build Novagram Android APK**.
3. Download `novagram-debug-apk` from the completed workflow run's Artifacts.
4. The workflow accepts `SUPABASE_URL` and `SUPABASE_ANON_KEY` as repository Actions
   variables. Add them under **Settings → Secrets and variables → Actions → Variables**.
   The values are passed as Dart compile-time definitions.

If variables are not configured, the app will still build but show the setup screen.

## Security notes

- Database tables have Row Level Security enabled.
- Users can only read chats they belong to and messages in those chats.
- The client never receives the Supabase service-role key.
- SMS OTP is account verification, not end-to-end encryption.
- Do not advertise end-to-end encryption until a separately reviewed cryptographic
  protocol and key management implementation exist.

## Project structure

```text
lib/
  app.dart
  main.dart
  core/
    config/app_config.dart
    theme/app_theme.dart
  features/
    auth/
      data/auth_service.dart
      presentation/auth_gate.dart
      presentation/phone_auth_page.dart
    chats/
      data/chat_repository.dart
      domain/chat.dart
      presentation/chat_list_page.dart
      presentation/chat_page.dart
    profile/
      presentation/profile_page.dart
supabase/
  schema.sql
.github/workflows/
  android.yml
```
