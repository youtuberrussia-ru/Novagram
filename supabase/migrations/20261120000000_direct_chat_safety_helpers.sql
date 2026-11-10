create or replace function public.get_direct_chat_partner(p_chat_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select other_member.user_id
  from public.chats c
  join public.chat_members mine
    on mine.chat_id = c.id and mine.user_id = auth.uid()
  join public.chat_members other_member
    on other_member.chat_id = c.id and other_member.user_id <> auth.uid()
  where c.id = p_chat_id and c.is_group = false
  limit 1;
$$;
revoke all on function public.get_direct_chat_partner(uuid) from public;
grant execute on function public.get_direct_chat_partner(uuid) to authenticated;
