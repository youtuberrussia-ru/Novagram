-- Secure Novagram owner console and reserved official handle.
create table if not exists public.novagram_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now()
);
alter table public.novagram_admins enable row level security;

create or replace function public.is_novagram_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.novagram_admins a where a.user_id = auth.uid());
$$;
revoke all on function public.is_novagram_admin() from public;
grant execute on function public.is_novagram_admin() to authenticated;

create or replace function public.protect_official_username()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if lower(coalesce(new.username, '')) = 'novagram'
     and not exists (select 1 from public.novagram_admins a where a.user_id = new.id) then
    raise exception 'This username is reserved for the official Novagram account';
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_protect_official_username on public.profiles;
create trigger profiles_protect_official_username before insert or update of username
on public.profiles for each row execute function public.protect_official_username();

create or replace function public.novagram_admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path = public
as $$
declare v_result jsonb;
begin
  if not public.is_novagram_admin() then raise exception 'Administrator access required'; end if;
  select jsonb_build_object(
    'users', (select count(*) from auth.users),
    'chats', (select count(*) from public.chats),
    'messages', (select count(*) from public.messages),
    'channels', (select count(*) from public.channels),
    'pending_reports', (select count(*) from public.user_reports where status = 'new'),
    'reports', coalesce((
      select jsonb_agg(row_to_json(r)) from (
        select ur.id, ur.category, ur.details, ur.status, ur.created_at,
          coalesce(p.display_name, 'Удалённый пользователь') as reporter_name,
          coalesce(target.display_name, 'Не указан') as reported_name
        from public.user_reports ur
        left join public.profiles p on p.id = ur.reporter_id
        left join public.profiles target on target.id = ur.reported_user_id
        order by ur.created_at desc limit 50
      ) r
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.novagram_admin_dashboard() from public;
grant execute on function public.novagram_admin_dashboard() to authenticated;

create or replace function public.novagram_admin_update_report(p_report_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_novagram_admin() then raise exception 'Administrator access required'; end if;
  if p_status not in ('reviewing', 'resolved', 'dismissed') then raise exception 'Invalid report status'; end if;
  update public.user_reports set status = p_status where id = p_report_id;
  if not found then raise exception 'Report not found'; end if;
end;
$$;
revoke all on function public.novagram_admin_update_report(uuid, text) from public;
grant execute on function public.novagram_admin_update_report(uuid, text) to authenticated;
