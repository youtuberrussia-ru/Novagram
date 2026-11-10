-- Make profile visibility effective for direct profile reads and search.
create or replace function public.is_profile_discoverable(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select s.profile_visibility <> 'nobody'
     from public.user_privacy_settings s
     where s.user_id = p_user_id),
    true
  );
$$;
revoke all on function public.is_profile_discoverable(uuid) from public;
grant execute on function public.is_profile_discoverable(uuid) to authenticated;

drop policy if exists "Profiles are visible to signed-in users" on public.profiles;
create policy "Profiles are visible to signed-in users"
on public.profiles for select to authenticated
using (id = auth.uid() or public.is_profile_discoverable(id));

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
    and public.is_profile_discoverable(p.id)
    and (
      p.username ilike '%' || trim(p_query) || '%'
      or p.display_name ilike '%' || trim(p_query) || '%'
    )
  order by p.display_name
  limit 30;
$$;
revoke all on function public.search_profiles(text) from public;
grant execute on function public.search_profiles(text) to authenticated;

-- Until a contacts graph exists, reject the reserved 'contacts' mode rather
-- than silently treating it as public access.
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
  if coalesce(v_message_permissions, 'everyone') <> 'everyone' then
    raise exception 'This user does not accept new messages from everyone';
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
