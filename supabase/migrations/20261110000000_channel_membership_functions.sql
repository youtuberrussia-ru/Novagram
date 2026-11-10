-- Keep channel ownership represented in membership so owners can publish.
create or replace function public.add_channel_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.channel_members (channel_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (channel_id, user_id) do update set role = 'owner';
  return new;
end;
$$;

drop trigger if exists channel_owner_membership_after_insert on public.channels;
create trigger channel_owner_membership_after_insert
after insert on public.channels
for each row execute function public.add_channel_owner_membership();

-- Backfill owners of channels created before this migration.
insert into public.channel_members (channel_id, user_id, role)
select id, owner_id, 'owner' from public.channels
on conflict (channel_id, user_id) do update set role = 'owner';

create or replace function public.join_public_channel(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.channels
    where id = p_channel_id and is_public = true
  ) then
    raise exception 'Public channel not found';
  end if;
  insert into public.channel_members (channel_id, user_id, role)
  values (p_channel_id, v_me, 'subscriber')
  on conflict (channel_id, user_id) do nothing;
end;
$$;

create or replace function public.leave_channel(p_channel_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'Authentication required';
  end if;
  delete from public.channel_members
  where channel_id = p_channel_id
    and user_id = v_me
    and role = 'subscriber';
end;
$$;

revoke all on function public.add_channel_owner_membership() from public;
revoke all on function public.join_public_channel(uuid) from public, anon;
revoke all on function public.leave_channel(uuid) from public, anon;
grant execute on function public.join_public_channel(uuid) to authenticated;
grant execute on function public.leave_channel(uuid) to authenticated;
