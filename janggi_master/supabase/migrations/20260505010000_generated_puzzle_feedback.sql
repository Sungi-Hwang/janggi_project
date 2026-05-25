create table if not exists public.generated_puzzle_feedback (
  user_id uuid not null references public.profiles(id) on delete cascade,
  puzzle_id text not null references public.generated_puzzles(id) on delete cascade,
  vote integer not null check (vote in (-1, 1)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, puzzle_id)
);

create index if not exists generated_puzzle_feedback_puzzle_vote_idx
  on public.generated_puzzle_feedback (puzzle_id, vote);

alter table public.generated_puzzle_feedback enable row level security;

drop policy if exists "Users can read their generated puzzle feedback"
  on public.generated_puzzle_feedback;
create policy "Users can read their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their generated puzzle feedback"
  on public.generated_puzzle_feedback;
create policy "Users can insert their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their generated puzzle feedback"
  on public.generated_puzzle_feedback;
create policy "Users can update their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select, insert, update on public.generated_puzzle_feedback
  to authenticated;
grant select, insert, update on public.generated_puzzle_feedback
  to service_role;
