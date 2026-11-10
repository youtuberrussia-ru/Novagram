-- Enforce the privacy controls and block list introduced in migration 140.
-- The helper runs with the table owner's privileges so RLS on chat_members
-- does not hide the other participant from the check.
create or replace function public.can_send_chat_message(p_chat_id uuid, p_sender_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chats c
    join public.chat_members mine
      on mine.chat_id = c.id and mine.user_id = p_sender_id
    where c.id = p_chat_id
      and p_sender_id = auth.uid()
      and (
        c.is_group
        or not exists (
          select 1
          from public.chat_members other_member
          where other_member.chat_id = c.id
            and other_member.user_id <> p_sender_id
            and public.is_blocked_between(p_sender_id, other_member.user_id)
        )
      )
  );
$$;
revoke all on function public.can_send_chat_message(uuid, uuid) from public;
grant execute on function public.can_send_chat_message(uuid, uuid) to authenticated;

drop policy if exists "Members send messages" on public.messages;
create policy "Members send messages"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and public.can_send_chat_message(chat_id, sender_id)
);

-- Respect the profile visibility preference in the public user search RPC.
create or replace function public.search_profiles(p_query text)
returns table(id uuid, username text, display_name text, avatar_url text)
language sql
stable
security invoker
set search_path = public
as $$
  select p.id, p.username, p.display_name, p.avatar_url
  from public.profiles p
  left join public.user_privacy_settings s on s.user_id = p.id
  where char_length(trim(coalesce(p_query, ''))) >= 2
    and coalesce(s.profile_visibility, 'everyone') <> 'nobody'
    and (
      p.username ilike '%' || trim(p_query) || '%'
      or p.display_name ilike '%' || trim(p_query) || '%'
    )
  order by p.display_name
  limit 30;
$$;
revoke all on function public.search_profiles(text) from public;
grant execute on function public.search_profiles(text) to authenticated;

-- Prevent creating a new direct chat when the recipient disabled incoming DMs.
create or replace function public.create_direct_chat(p_other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_chat_id uuid;
  v_message_permissions text;
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

  select coalesce(s.message_permissions, 'everyone')
    into v_message_permissions
  from public.user_privacy_settings s
  where s.user_id = p_other_user;
  if coalesce(v_message_permissions, 'everyone') = 'nobody' then
    raise exception 'This user does not accept new messages';
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
