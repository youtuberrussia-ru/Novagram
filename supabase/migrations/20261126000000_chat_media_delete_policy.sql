-- Allow users to remove only their own private chat-media objects.
-- Message deletion already checks sender_id; this policy keeps storage cleanup
-- aligned with that ownership boundary.
drop policy if exists "Users delete own chat media" on storage.objects;
create policy "Users delete own chat media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat-media'
  and (storage.foldername(name))[2] = auth.uid()::text
  and exists (
    select 1
    from public.chat_members m
    where m.chat_id::text = (storage.foldername(name))[1]
      and m.user_id = auth.uid()
  )
);
