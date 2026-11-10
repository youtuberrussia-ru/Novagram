-- Enforce group-invite preferences and tighten channel post updates.
create or replace function public.create_group_chat(
  p_title text,
  p_user_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_title text := trim(coalesce(p_title, ''));
  v_chat_id uuid;
  v_user_count integer;
begin
  if v_me is null then
    raise exception 'Authentication required';
  end if;
  if char_length(v_title) < 2 or char_length(v_title) > 50 then
    raise exception 'Group name must be between 2 and 50 characters';
  end if;

  select count(distinct selected.user_id) into v_user_count
  from unnest(coalesce(p_user_ids, array[]::uuid[])) as selected(user_id)
  where selected.user_id <> v_me;

  if v_user_count < 1 or v_user_count > 49 then
    raise exception 'Choose between 1 and 49 other members';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_user_ids, array[]::uuid[])) as selected(user_id)
    left join public.profiles p on p.id = selected.user_id
    where selected.user_id <> v_me and p.id is null
  ) then
    raise exception 'One or more users were not found';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_user_ids, array[]::uuid[])) as selected(user_id)
    join public.user_privacy_settings settings
      on settings.user_id = selected.user_id
    where selected.user_id <> v_me
      and settings.allow_group_invites = false
  ) then
    raise exception 'One or more users do not accept group invitations';
  end if;

  insert into public.chats (title, is_group, created_by)
  values (v_title, true, v_me)
  returning id into v_chat_id;

  insert into public.chat_members (chat_id, user_id)
  select v_chat_id, members.user_id
  from (
    select v_me as user_id
    union
    select distinct selected.user_id
    from unnest(coalesce(p_user_ids, array[]::uuid[])) as selected(user_id)
    where selected.user_id <> v_me
  ) members;

  return v_chat_id;
end;
$$;

revoke all on function public.create_group_chat(text, uuid[]) from public;
grant execute on function public.create_group_chat(text, uuid[]) to authenticated;

drop policy if exists "Authors edit own channel posts" on public.channel_posts;
create policy "Authors edit own channel posts"
on public.channel_posts for update to authenticated
using (
  author_id = auth.uid()
  and exists (
    select 1 from public.channel_members cm
    where cm.channel_id = channel_posts.channel_id
      and cm.user_id = auth.uid()
      and cm.role in ('owner', 'admin')
  )
)
with check (
  author_id = auth.uid()
  and exists (
    select 1 from public.channel_members cm
    where cm.channel_id = channel_posts.channel_id
      and cm.user_id = auth.uid()
      and cm.role in ('owner', 'admin')
  )
);

-- Ensure every new account has its default privacy row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', 'Пользователь'))
  on conflict (id) do nothing;

  insert into public.user_privacy_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

insert into public.user_privacy_settings (user_id)
select u.id from auth.users u
on conflict (user_id) do nothing;
