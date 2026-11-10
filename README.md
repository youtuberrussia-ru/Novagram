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
- Deletion of your own messages for all chat participants.
- PostgreSQL migrations and Row Level Security policies.
- GitHub Actions debug APK build.

## Required Supabase setup

1. In **Authentication → Providers → Email**, enable Email.
2. Add GitHub Actions variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
3. Apply all four SQL files in `supabase/migrations/` in chronological order using the Supabase SQL Editor:
   - `20261109000000_initial_schema.sql`
   - `20261110000000_chat_media.sql`
   - `20261111000000_chat_images.sql`
   - `20261112000000_message_delete.sql`
4. The media migration creates a private `chat-media` Storage bucket. Do not make this bucket public.

Email authentication does not require an SMS provider. Never put a database password or service-role key in app code, the APK, or a public repository.

## Build the Android APK

The GitHub Actions workflow **Build Novagram Android APK** runs on pushes to app code and can also be started from **Actions → Build Novagram Android APK → Run workflow**. A successful run uploads the `novagram-debug-apk` artifact.

## Owner setup and administration

The admin console is protected by database-side authorization. Applying the migration does **not** grant admin rights to every signed-in user. After your own account has been registered, open Supabase SQL Editor and run the following after replacing the email with the email used for your Novagram account:

```sql
insert into public.novagram_admins (user_id)
select id from auth.users where lower(email) = lower('YOUR_SIGNUP_EMAIL')
on conflict (user_id) do nothing;

update public.profiles
set username = 'novagram'
where id = (select id from auth.users where lower(email) = lower('YOUR_SIGNUP_EMAIL'));
```

This reserves **@Novagram** for the official owner account. Do not put a service-role key or database password in the app. The admin console includes service counters and a protected report queue; only accounts in `novagram_admins` can read or change moderation data.

## Not implemented yet

Live audio/video calls, background incoming-call notifications, push notifications, end-to-end encryption, channels, moderation, AI tools, and app-store release signing are not implemented. Video circles are short recorded clips, not live calls. These features require additional services and security work before a public launch.
