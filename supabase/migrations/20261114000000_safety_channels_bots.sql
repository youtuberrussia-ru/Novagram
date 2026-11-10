-- Novagram safety, privacy, channels and bot directory foundation.
-- All user-generated records are protected by RLS; privileged moderation actions
-- must be performed by a trusted server, never by the mobile client.

create table if not exists public.user_privacy_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  profile_visibility text not null default 'everyone'
    check (profile_visibility in ('everyone', 'contacts', 'nobody')),
  message_permissions text not null default 'everyone'
    check (message_permissions in ('everyone', 'contacts', 'nobody')),
  show_online boolean not null default true,
  read_receipts boolean not null default true,
  allow_group_invites boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.user_privacy_settings enable row level security;
drop policy if exists "Users read own privacy settings" on public.user_privacy_settings;
create policy "Users read own privacy settings"
on public.user_privacy_settings for select to authenticated
using (user_id = auth.uid());
drop policy if exists "Users insert own privacy settings" on public.user_privacy_settings;
create policy "Users insert own privacy settings"
on public.user_privacy_settings for insert to authenticated
with check (user_id = auth.uid());
drop policy if exists "Users update own privacy settings" on public.user_privacy_settings;
create policy "Users update own privacy settings"
on public.user_privacy_settings for update to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked_id_idx
  on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;
drop policy if exists "Users view their own blocks" on public.user_blocks;
create policy "Users view their own blocks"
on public.user_blocks for select to authenticated
using (blocker_id = auth.uid());
drop policy if exists "Users block accounts" on public.user_blocks;
create policy "Users block accounts"
on public.user_blocks for insert to authenticated
with check (blocker_id = auth.uid());
drop policy if exists "Users unblock accounts" on public.user_blocks;
create policy "Users unblock accounts"
on public.user_blocks for delete to authenticated
using (blocker_id = auth.uid());

create or replace function public.is_blocked_between(p_first uuid, p_second uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_first and b.blocked_id = p_second)
       or (b.blocker_id = p_second and b.blocked_id = p_first)
  );
$$;
revoke all on function public.is_blocked_between(uuid, uuid) from public;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  chat_id uuid references public.chats(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  category text not null check (category in
    ('harassment', 'doxxing', 'threats', 'spam', 'impersonation', 'other')),
  details text not null default '' check (char_length(details) <= 2000),
  status text not null default 'new'
    check (status in ('new', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);
create index if not exists user_reports_created_at_idx
  on public.user_reports(created_at desc);
alter table public.user_reports enable row level security;
drop policy if exists "Users submit reports" on public.user_reports;
create policy "Users submit reports"
on public.user_reports for insert to authenticated
with check (reporter_id = auth.uid());
drop policy if exists "Users view reports they submitted" on public.user_reports;
create policy "Users view reports they submitted"
on public.user_reports for select to authenticated
using (reporter_id = auth.uid());
-- No client-side update/delete policy: report status is trusted-moderator-only.

-- Public channel directory and posts. Channel membership is private.
create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 60),
  username text unique,
  description text not null default '' check (char_length(description) <= 500),
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.channel_members (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'subscriber'
    check (role in ('owner', 'admin', 'subscriber')),
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);
create table if not exists public.channel_posts (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 10000),
  created_at timestamptz not null default now(),
  edited_at timestamptz
);
create index if not exists channel_posts_feed_idx
  on public.channel_posts(channel_id, created_at desc);
alter table public.channels enable row level security;
alter table public.channel_members enable row level security;
alter table public.channel_posts enable row level security;
drop policy if exists "Public channels are discoverable" on public.channels;
create policy "Public channels are discoverable"
on public.channels for select to authenticated
using (is_public or owner_id = auth.uid());
drop policy if exists "Users create own channels" on public.channels;
create policy "Users create own channels"
on public.channels for insert to authenticated
with check (owner_id = auth.uid());
drop policy if exists "Owners update channels" on public.channels;
create policy "Owners update channels"
on public.channels for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "Members read channel membership" on public.channel_members;
create policy "Members read channel membership"
on public.channel_members for select to authenticated
using (user_id = auth.uid() or exists (
  select 1 from public.channels c where c.id = channel_id and c.owner_id = auth.uid()
));
drop policy if exists "Channel owners add members" on public.channel_members;
create policy "Channel owners add members"
on public.channel_members for insert to authenticated
with check (exists (
  select 1 from public.channels c where c.id = channel_id and c.owner_id = auth.uid()
));
drop policy if exists "Users leave channels" on public.channel_members;
create policy "Users leave channels"
on public.channel_members for delete to authenticated
using (user_id = auth.uid() or exists (
  select 1 from public.channels c where c.id = channel_id and c.owner_id = auth.uid()
));
drop policy if exists "Members read channel posts" on public.channel_posts;
create policy "Members read channel posts"
on public.channel_posts for select to authenticated
using (exists (
  select 1 from public.channel_members cm
  where cm.channel_id = channel_id and cm.user_id = auth.uid()
) or exists (
  select 1 from public.channels c
  where c.id = channel_id and c.is_public
));
drop policy if exists "Channel admins publish posts" on public.channel_posts;
create policy "Channel admins publish posts"
on public.channel_posts for insert to authenticated
with check (
  author_id = auth.uid() and exists (
    select 1 from public.channel_members cm
    where cm.channel_id = channel_id and cm.user_id = auth.uid()
      and cm.role in ('owner', 'admin')
  )
);
drop policy if exists "Authors edit own channel posts" on public.channel_posts;
create policy "Authors edit own channel posts"
on public.channel_posts for update to authenticated
using (author_id = auth.uid() and exists (
  select 1 from public.channel_members cm
  where cm.channel_id = channel_id and cm.user_id = auth.uid()
    and cm.role in ('owner', 'admin')
))
with check (author_id = auth.uid());

-- Bot directory only. Running bot code and issuing API tokens require a separate
-- trusted backend/Edge Function and are intentionally not exposed to clients.
create table if not exists public.bot_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 40),
  username text not null unique check (username ~ '^[a-zA-Z0-9_]{4,32}$'),
  description text not null default '' check (char_length(description) <= 500),
  avatar_url text,
  is_public boolean not null default false,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.bot_profiles enable row level security;
drop policy if exists "Public bot directory" on public.bot_profiles;
create policy "Public bot directory"
on public.bot_profiles for select to authenticated
using (is_public or owner_id = auth.uid());
drop policy if exists "Users register own bot profiles" on public.bot_profiles;
create policy "Users register own bot profiles"
on public.bot_profiles for insert to authenticated
with check (owner_id = auth.uid() and is_verified = false);
drop policy if exists "Owners update own bot profiles" on public.bot_profiles;
create policy "Owners update own bot profiles"
on public.bot_profiles for update to authenticated
using (owner_id = auth.uid()) with check (owner_id = auth.uid() and is_verified = false);

-- Blocked relationships stop new direct conversations and messages in either direction.
drop policy if exists "Members send messages" on public.messages;
create policy "Members send messages"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.chat_members mine
    join public.chat_members other_member
      on other_member.chat_id = mine.chat_id
     and other_member.user_id <> mine.user_id
    where mine.chat_id = messages.chat_id
      and mine.user_id = auth.uid()
      and not public.is_blocked_between(mine.user_id, other_member.user_id)
  )
);

create or replace function public.create_direct_chat(p_other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_chat_id uuid;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  if p_other_user is null or p_other_user = v_me then
    raise exception 'Invalid recipient';
  end if;
  if not exists (select 1 from public.profiles where id = p_other_user) then
    raise exception 'User not found';
  end if;
  if public.is_blocked_between(v_me, p_other_user) then
    raise exception 'This conversation is unavailable';
  end if;

  select c.id into v_chat_id
  from public.chats c
  where c.is_group = false
    and exists (select 1 from public.chat_members a
      where a.chat_id = c.id and a.user_id = v_me)
    and exists (select 1 from public.chat_members b
      where b.chat_id = c.id and b.user_id = p_other_user)
    and (select count(*) from public.chat_members x
      where x.chat_id = c.id) = 2
  limit 1;
  if v_chat_id is not null then return v_chat_id; end if;

  insert into public.chats (is_group, created_by)
  values (false, v_me) returning id into v_chat_id;
  insert into public.chat_members (chat_id, user_id)
  values (v_chat_id, v_me), (v_chat_id, p_other_user);
  return v_chat_id;
end;
$$;
revoke all on function public.create_direct_chat(uuid) from public;
grant execute on function public.create_direct_chat(uuid) to authenticated;
