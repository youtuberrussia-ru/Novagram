-- Let channel owners permanently delete their own channels.
-- Related members and posts are removed by their foreign-key cascades.
drop policy if exists "Owners delete channels" on public.channels;
create policy "Owners delete channels"
on public.channels for delete to authenticated
using (owner_id = auth.uid());
