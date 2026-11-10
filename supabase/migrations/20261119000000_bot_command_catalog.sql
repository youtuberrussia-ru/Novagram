-- Safe declarative bot command catalog. Commands are data, never executable code.
create table if not exists public.bot_commands (
  id uuid primary key default gen_random_uuid(),
  bot_id uuid not null references public.bot_profiles(id) on delete cascade,
  command text not null check (command ~ '^/[a-z0-9_]{1,32}$'),
  description text not null default '' check (char_length(description) <= 120),
  response_text text not null check (char_length(response_text) between 1 and 2000),
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (bot_id, command)
);
create index if not exists bot_commands_bot_id_idx
  on public.bot_commands(bot_id);
alter table public.bot_commands enable row level security;

drop policy if exists "Public commands for listed bots" on public.bot_commands;
create policy "Public commands for listed bots"
on public.bot_commands for select to authenticated
using (exists (
  select 1 from public.bot_profiles b
  where b.id = bot_id and (b.is_public or b.owner_id = auth.uid())
));

drop policy if exists "Bot owners create commands" on public.bot_commands;
create policy "Bot owners create commands"
on public.bot_commands for insert to authenticated
with check (exists (
  select 1 from public.bot_profiles b
  where b.id = bot_id and b.owner_id = auth.uid()
));

drop policy if exists "Bot owners update commands" on public.bot_commands;
create policy "Bot owners update commands"
on public.bot_commands for update to authenticated
using (exists (
  select 1 from public.bot_profiles b
  where b.id = bot_id and b.owner_id = auth.uid()
))
with check (exists (
  select 1 from public.bot_profiles b
  where b.id = bot_id and b.owner_id = auth.uid()
));

drop policy if exists "Bot owners delete commands" on public.bot_commands;
create policy "Bot owners delete commands"
on public.bot_commands for delete to authenticated
using (exists (
  select 1 from public.bot_profiles b
  where b.id = bot_id and b.owner_id = auth.uid()
));
