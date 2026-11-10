-- Complete public channel lifecycle: channel owner membership, subscribe and leave.
create or replace function public.add_channel_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.channel_members(channel_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (channel_id, user_id) do update set role = 'owner';
  return new;
end;
$$;

drop trigger if exists channels_add_owner_membership on public.channels;
create trigger channels_add_owner_membership
after insert on public.channels
for each row execute function public.add_channel_owner_membership();

create or replace function public.join_public_channel(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.channels
    where id = p_channel_id and is_public = true
  ) then raise exception 'Public channel not found'; end if;
  insert into public.channel_members(channel_id, user_id, role)
  values (p_channel_id, v_me, 'subscriber')
  on conflict (channel_id, user_id) do nothing;
end;
$$;
revoke all on function public.join_public_channel(uuid) from public;
grant execute on function public.join_public_channel(uuid) to authenticated;

create or replace function public.leave_channel(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  delete from public.channel_members
  where channel_id = p_channel_id and user_id = v_me and role <> 'owner';
  if exists (
    select 1 from public.channel_members
    where channel_id = p_channel_id and user_id = v_me and role = 'owner'
  ) then raise exception 'Channel owner cannot leave; transfer ownership first'; end if;
end;
$$;
revoke all on function public.leave_channel(uuid) from public;
grant execute on function public.leave_channel(uuid) to authenticated;

-- Channel creators can only create public handles with a normalized safe name.
create or replace function public.normalize_channel_username()
returns trigger
language plpgsql
as $$
begin
  if new.username is not null then
    new.username := lower(trim(both '@' from trim(new.username)));
    if new.username !~ '^[a-z0-9_]{4,32}$' then
      raise exception 'Channel username must be 4-32 letters, numbers or underscores';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists channels_normalize_username on public.channels;
create trigger channels_normalize_username
before insert or update of username on public.channels
for each row execute function public.normalize_channel_username();
