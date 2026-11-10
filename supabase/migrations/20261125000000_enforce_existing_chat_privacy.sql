-- Enforce direct-message privacy on every message, not only when a chat is created.
-- This closes the gap where an existing conversation could still receive messages
-- after the recipient changed "Who can write" to Nobody.
create or replace function public.can_send_chat_message(
  p_chat_id uuid,
  p_sender_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chats c
    join public.chat_members sender_member
      on sender_member.chat_id = c.id
     and sender_member.user_id = p_sender_id
    where c.id = p_chat_id
      and p_sender_id = auth.uid()
      and (
        c.is_group
        or (
          not exists (
            select 1
            from public.chat_members other_member
            where other_member.chat_id = c.id
              and other_member.user_id <> p_sender_id
              and public.is_blocked_between(p_sender_id, other_member.user_id)
          )
          and not exists (
            select 1
            from public.chat_members recipient
            join public.user_privacy_settings privacy
              on privacy.user_id = recipient.user_id
            where recipient.chat_id = c.id
              and recipient.user_id <> p_sender_id
              and privacy.message_permissions = 'nobody'
          )
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

-- Keep the message list query efficient as the number of chats grows.
create index if not exists messages_chat_created_id_idx
  on public.messages(chat_id, created_at desc, id desc);
