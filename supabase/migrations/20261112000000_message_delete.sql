-- Allow users to delete only messages they authored.
drop policy if exists "Users delete own messages" on public.messages;
create policy "Users delete own messages"
on public.messages for delete to authenticated
using (sender_id = auth.uid());
