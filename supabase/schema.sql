-- Novagram database schema.
-- Safe to re-run from Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text not null default 'Пользователь',
  avatar_url text,
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Phone numbers stay in auth.users and are never exposed by public profile reads.
alter table public.profiles drop column if exists phone;

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  title text,
  is_group boolean not null default false,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 10000),
  created_at timestamptz not null default now(),
  edited_at timestamptz
);

create index if not exists chat_members_user_id_idx
  on public.chat_members(user_id);
create index if not exists messages_chat_created_idx
  on public.messages(chat_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists chats_set_updated_at on public.chats;
create trigger chats_set_updated_at before update on public.chats
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, 'Пользователь')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "Profiles are visible to signed-in users"
  on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select to authenticated using (true);

drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
on public.profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Members read their chats" on public.chats;
create policy "Members read their chats"
on public.chats for select to authenticated
using (
  exists (
    select 1 from public.chat_members m
    where m.chat_id = chats.id and m.user_id = auth.uid()
  )
);

drop policy if exists "Members read membership" on public.chat_members;
create policy "Members read membership"
on public.chat_members for select to authenticated
using (user_id = auth.uid());

drop policy if exists "Members read messages" on public.messages;
create policy "Members read messages"
on public.messages for select to authenticated
using (
  exists (
    select 1 from public.chat_members m
    where m.chat_id = messages.chat_id and m.user_id = auth.uid()
  )
);

drop policy if exists "Members send messages" on public.messages;
create policy "Members send messages"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.chat_members m
    where m.chat_id = messages.chat_id and m.user_id = auth.uid()
  )
);

create or replace function public.search_profiles(p_query text)
returns table(id uuid, username text, display_name text, avatar_url text)
language sql
stable
security invoker
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_url
  from public.profiles p
  where char_length(trim(coalesce(p_query, ''))) >= 2
    and (
      p.username ilike '%' || trim(p_query) || '%'
      or p.display_name ilike '%' || trim(p_query) || '%'
    )
  order by p.display_name
  limit 30;
$$;

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
  if v_me is null then
    raise exception 'Authentication required';
  end if;
  if p_other_user is null or p_other_user = v_me then
    raise exception 'Invalid recipient';
  end if;
  if not exists (
    select 1 from public.profiles where id = p_other_user
  ) then
    raise exception 'User not found';
  end if;

  select c.id into v_chat_id
  from public.chats c
  where c.is_group = false
    and exists (
      select 1 from public.chat_members a
      where a.chat_id = c.id and a.user_id = v_me
    )
    and exists (
      select 1 from public.chat_members b
      where b.chat_id = c.id and b.user_id = p_other_user
    )
    and (
      select count(*) from public.chat_members x
      where x.chat_id = c.id
    ) = 2
  limit 1;

  if v_chat_id is not null then
    return v_chat_id;
  end if;

  insert into public.chats (is_group, created_by)
  values (false, v_me)
  returning id into v_chat_id;

  insert into public.chat_members (chat_id, user_id)
  values (v_chat_id, v_me), (v_chat_id, p_other_user);

  return v_chat_id;
end;
$$;

revoke all on function public.search_profiles(text) from public;
revoke all on function public.create_direct_chat(uuid) from public;
grant execute on function public.search_profiles(text) to authenticated;
grant execute on function public.create_direct_chat(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end
$$;


-- Allow each signed-in user to create only their own profile row.
drop policy if exists "Users insert own profile" on public.profiles;
create policy "Users insert own profile"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

-- Return a personalized title for direct chats without exposing phone numbers
-- or allowing clients to inspect other members' private membership rows.
create or replace function public.get_my_chats()
returns table(
  id uuid,
  title text,
  is_group boolean,
  updated_at timestamptz,
  other_display_name text,
  other_username text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id,
    c.title,
    c.is_group,
    c.updated_at,
    case when c.is_group then null else p.display_name end,
    case when c.is_group then null else p.username end
  from public.chats c
  join public.chat_members mine
    on mine.chat_id = c.id and mine.user_id = auth.uid()
  left join public.chat_members other_member
    on other_member.chat_id = c.id
    and other_member.user_id <> auth.uid()
    and not c.is_group
  left join public.profiles p
    on p.id = other_member.user_id
  where auth.uid() is not null
  order by c.updated_at desc;
$$;

revoke all on function public.get_my_chats() from public;
grant execute on function public.get_my_chats() to authenticated;
