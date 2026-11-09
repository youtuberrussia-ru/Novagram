# Novagram — Flutter messenger foundation

Novagram is an Android-first Flutter messenger foundation using Supabase for phone OTP authentication, profiles, direct chats, and realtime text messages.

## Implemented in this milestone

- Phone-number sign-in with SMS one-time codes through Supabase Auth.
- Auth state gate and sign-out.
- Automatic profile creation after a new account is created.
- Editable profiles with display name, unique username, and short bio.
- User search, direct chats, and group creation with participant selection.
- Personalized chat titles and latest-message previews.
- Realtime text-message stream with timestamps and improved message composer.
- PostgreSQL schema and Row Level Security policies.
- GitHub Actions workflow that generates Android platform files when needed, analyzes the Dart project, builds a debug APK, and uploads it as an artifact.

This is an early foundation, not a finished commercial messenger. Advanced group administration, media sharing, voice/video calls, push notifications, end-to-end encryption, moderation, and AI tools are not implemented yet.

## 1. Configure Supabase

1. Create a Supabase project.
2. In **Authentication → Providers → Phone**, enable phone authentication.
3. Configure an SMS provider. SMS delivery may have a cost.
4. The database schema can be installed automatically from GitHub Actions using the **Apply Supabase database migrations** workflow. Add the three required Supabase secrets described below, then run that workflow. You do not need to paste SQL into the dashboard.
5. In project API settings, copy the project URL and the public publishable/publishable key.

Only use the public client key in the app. Never put the Supabase `service_role` key in the repository, GitHub Actions variables, or APK.

## 2. Configure GitHub Actions

### APK build variables

In this repository open **Settings → Secrets and variables → Actions → Variables** and add:

- `SUPABASE_URL` — your Supabase project URL.
- `SUPABASE_PUBLISHABLE_KEY` — your public publishable/publishable key.

Do not paste these values into chat. The public client key is intended for client apps, but the database must be protected by the included RLS policies.

### Database migration secrets

In **Settings → Secrets and variables → Actions → Secrets**, add these three secrets:

- `SUPABASE_ACCESS_TOKEN` — a Supabase personal access token.
- `SUPABASE_PROJECT_REF` — the project reference from the Supabase project URL.
- `SUPABASE_DB_PASSWORD` — the database password chosen when creating the Supabase project.

Never put these secrets in repository files or send them in chat. Then open **Actions → Apply Supabase database migrations → Run workflow**. This applies the versioned SQL migration in `supabase/migrations/`.

If the schema was already run manually in SQL Editor, do not run this migration workflow until the migration history is reconciled; otherwise the CLI may report that the database schema already exists.

## 3. Build the Android APK

1. Open the **Actions** tab.
2. Select **Build Novagram Android APK**.
3. Run the workflow with **Run workflow**, or push a Dart change to `main`.
4. When the run finishes, open it and download the `novagram-debug-apk` artifact.

The workflow creates the Android platform folder if it is absent, runs `flutter pub get`, `flutter analyze`, and builds a debug APK.

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

## Security and limitations

- Database access is protected with Row Level Security.
- SMS verification confirms control of a phone number; it is not end-to-end encryption.
- Do not describe messages as end-to-end encrypted until a separately reviewed cryptographic protocol and key-management system are implemented.
- Configure Supabase Auth rate limits and SMS provider limits before inviting real users.
