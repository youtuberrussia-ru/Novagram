-- Include malicious emergency-call / swatting threats in the safety report flow.
alter table public.user_reports
  drop constraint if exists user_reports_category_check;
alter table public.user_reports
  add constraint user_reports_category_check
  check (category in (
    'harassment', 'doxxing', 'threats', 'swatting',
    'spam', 'impersonation', 'other'
  ));
