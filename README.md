# Novagram — Android-first Flutter messenger

Novagram is a Flutter messenger using Supabase for email/password authentication, profiles, direct and group chats, realtime messages, and private media storage.

## Implemented in the current code

- Email/password registration and sign-in.
- Optional email confirmation through Supabase Auth.
- Profiles with display name, username, and bio.
- User search, direct chats, and group creation.
- Realtime text messages.
- Voice-message recording, private upload, and playback.
- Short video-circle recording with the front camera and in-chat playback.
- Private photo attachments from the gallery with in-chat previews.
- PostgreSQL migrations and Row Level Security policies.
- GitHub Actions debug APK build.

## Required Supabase setup

1. In **Authentication → Providers → Email**, enable Email.
2. Add GitHub Actions variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
3. Apply both SQL files in `supabase/migrations/` in chronological order using the Supabase SQL Editor:
   - `20261109000000_initial_schema.sql`
   - `20261110000000_chat_media.sql`
   - `20261111000000_chat_images.sql`
4. The media migration creates a private `chat-media` Storage bucket. Do not make this bucket public.

Email authentication does not require an SMS provider. Never put a database password or service-role key in app code, the APK, or a public repository.

## Build the Android APK

The GitHub Actions workflow **Build Novagram Android APK** runs on pushes to app code and can also be started from **Actions → Build Novagram Android APK → Run workflow**. A successful run uploads the `novagram-debug-apk` artifact.

## Not implemented yet

Live audio/video calls, background incoming-call notifications, push notifications, end-to-end encryption, channels, moderation, AI tools, and app-store release signing are not implemented. Video circles are short recorded clips, not live calls. These features require additional services and security work before a public launch.
