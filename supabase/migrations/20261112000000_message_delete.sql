-- Allow users to delete only messages they authored in chats they belong to.
drop policy if exists "Users delete own messages" on public.messages;
create policy "Users delete own messages"
on public.messages for delete to authenticated
using (
  sender_id = auth.uid()
  and exists (
    select 1 from public.chat_members m
    where m.chat_id = messages.chat_id and m.user_id = auth.uid()
  )
);

-- Permit cleanup of only the caller's own media objects in their chats.
drop policy if exists "Users delete own chat media" on storage.objects;
create policy "Users delete own chat media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[2] = auth.uid()::text
  and exists (
    select 1 from public.chat_members m
    where m.chat_id::text = (storage.foldername(name))[1]
      and m.user_id = auth.uid()
  )
);
