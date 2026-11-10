-- Prevent report flooding while allowing urgent safety reports.
create or replace function public.limit_user_report_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recent_count integer;
begin
  select count(*) into v_recent_count
  from public.user_reports r
  where r.reporter_id = new.reporter_id
    and r.created_at > now() - interval '10 minutes';
  if v_recent_count >= 5 then
    raise exception 'Too many reports. Please wait before submitting another.';
  end if;
  return new;
end;
$$;

drop trigger if exists user_reports_rate_limit on public.user_reports;
create trigger user_reports_rate_limit
before insert on public.user_reports
for each row execute function public.limit_user_report_rate();
