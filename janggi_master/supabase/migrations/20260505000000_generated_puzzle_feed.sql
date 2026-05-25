create table if not exists public.generated_puzzles (
  id text primary key,
  fen text not null,
  solution jsonb not null default '[]'::jsonb,
  mate_in integer not null check (mate_in in (2, 3)),
  to_move text not null check (to_move in ('blue', 'red')),
  title text not null default '생성 묘수',
  source text not null default 'self_play',
  quality_score numeric not null default 0,
  generator jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft', 'published', 'rejected')),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  constraint generated_puzzles_solution_array check (jsonb_typeof(solution) = 'array'),
  constraint generated_puzzles_published_at check (
    status <> 'published' or published_at is not null
  )
);

create unique index if not exists generated_puzzles_fen_unique_idx
  on public.generated_puzzles (fen);

create index if not exists generated_puzzles_feed_idx
  on public.generated_puzzles (status, published_at desc, quality_score desc);

create index if not exists generated_puzzles_mate_in_idx
  on public.generated_puzzles (mate_in);

create table if not exists public.generated_puzzle_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  puzzle_id text not null references public.generated_puzzles(id) on delete cascade,
  solved boolean not null default false,
  attempts integer not null default 1 check (attempts > 0),
  hint_used boolean not null default false,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists generated_puzzle_attempts_user_completed_idx
  on public.generated_puzzle_attempts (user_id, completed_at desc);

create index if not exists generated_puzzle_attempts_puzzle_idx
  on public.generated_puzzle_attempts (puzzle_id);

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

alter table public.generated_puzzles enable row level security;
alter table public.generated_puzzle_attempts enable row level security;
alter table public.generated_puzzle_feedback enable row level security;

drop policy if exists "Published generated puzzles are readable" on public.generated_puzzles;
create policy "Published generated puzzles are readable"
  on public.generated_puzzles
  for select
  to anon, authenticated
  using (status = 'published');

drop policy if exists "Users can read their generated puzzle attempts" on public.generated_puzzle_attempts;
create policy "Users can read their generated puzzle attempts"
  on public.generated_puzzle_attempts
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their generated puzzle attempts" on public.generated_puzzle_attempts;
create policy "Users can insert their generated puzzle attempts"
  on public.generated_puzzle_attempts
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read their generated puzzle feedback" on public.generated_puzzle_feedback;
create policy "Users can read their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can upsert their generated puzzle feedback" on public.generated_puzzle_feedback;
create policy "Users can upsert their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their generated puzzle feedback" on public.generated_puzzle_feedback;
create policy "Users can update their generated puzzle feedback"
  on public.generated_puzzle_feedback
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

grant select on public.generated_puzzles to anon, authenticated;
grant select, insert on public.generated_puzzle_attempts to authenticated;
grant select, insert, update on public.generated_puzzle_feedback to authenticated;
grant select, insert, update on public.generated_puzzles to service_role;
grant select, insert, update on public.generated_puzzle_attempts to service_role;
grant select, insert, update on public.generated_puzzle_feedback to service_role;
