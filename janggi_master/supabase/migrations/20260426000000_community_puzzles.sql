create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Google 사용자',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_puzzles (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  description text not null check (char_length(description) between 1 and 140),
  fen text not null,
  solution jsonb not null default '[]'::jsonb,
  mate_in integer not null default 1 check (mate_in between 1 and 20),
  to_move text not null default 'blue' check (to_move in ('blue', 'red')),
  like_count integer not null default 0,
  import_count integer not null default 0,
  report_count integer not null default 0,
  status text not null default 'published'
    check (status in ('published', 'hidden', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_puzzle_likes (
  puzzle_id uuid not null references public.community_puzzles(id)
    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (puzzle_id, user_id)
);

create table if not exists public.community_puzzle_imports (
  puzzle_id uuid not null references public.community_puzzles(id)
    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (puzzle_id, user_id)
);

create table if not exists public.community_puzzle_reports (
  puzzle_id uuid not null references public.community_puzzles(id)
    on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (puzzle_id, user_id)
);

create index if not exists community_puzzles_status_created_idx
  on public.community_puzzles(status, created_at desc);
create index if not exists community_puzzles_status_likes_idx
  on public.community_puzzles(status, like_count desc, created_at desc);

create or replace function public.refresh_community_puzzle_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_puzzle_id uuid;
begin
  target_puzzle_id := coalesce(new.puzzle_id, old.puzzle_id);

  update public.community_puzzles
  set
    like_count = (
      select count(*) from public.community_puzzle_likes
      where puzzle_id = target_puzzle_id
    ),
    import_count = (
      select count(*) from public.community_puzzle_imports
      where puzzle_id = target_puzzle_id
    ),
    report_count = (
      select count(*) from public.community_puzzle_reports
      where puzzle_id = target_puzzle_id
    ),
    updated_at = now()
  where id = target_puzzle_id;

  return null;
end;
$$;

drop trigger if exists refresh_like_counts
  on public.community_puzzle_likes;
create trigger refresh_like_counts
after insert or delete on public.community_puzzle_likes
for each row execute function public.refresh_community_puzzle_counts();

drop trigger if exists refresh_import_counts
  on public.community_puzzle_imports;
create trigger refresh_import_counts
after insert or delete on public.community_puzzle_imports
for each row execute function public.refresh_community_puzzle_counts();

drop trigger if exists refresh_report_counts
  on public.community_puzzle_reports;
create trigger refresh_report_counts
after insert or delete on public.community_puzzle_reports
for each row execute function public.refresh_community_puzzle_counts();

alter table public.profiles enable row level security;
alter table public.community_puzzles enable row level security;
alter table public.community_puzzle_likes enable row level security;
alter table public.community_puzzle_imports enable row level security;
alter table public.community_puzzle_reports enable row level security;

drop policy if exists "profiles are readable" on public.profiles;
create policy "profiles are readable"
on public.profiles for select
using (true);

drop policy if exists "users can upsert own profile" on public.profiles;
create policy "users can upsert own profile"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "users can update own profile" on public.profiles;
create policy "users can update own profile"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "published puzzles are readable"
  on public.community_puzzles;
create policy "published puzzles are readable"
on public.community_puzzles for select
using (status = 'published');

drop policy if exists "users can create own puzzles"
  on public.community_puzzles;
create policy "users can create own puzzles"
on public.community_puzzles for insert
with check (auth.uid() = author_id);

drop policy if exists "authors can update own puzzles"
  on public.community_puzzles;
create policy "authors can update own puzzles"
on public.community_puzzles for update
using (auth.uid() = author_id)
with check (auth.uid() = author_id);

drop policy if exists "authors can delete own puzzles"
  on public.community_puzzles;
create policy "authors can delete own puzzles"
on public.community_puzzles for delete
using (auth.uid() = author_id);

drop policy if exists "likes are readable"
  on public.community_puzzle_likes;
create policy "likes are readable"
on public.community_puzzle_likes for select
using (true);

drop policy if exists "users can like as themselves"
  on public.community_puzzle_likes;
create policy "users can like as themselves"
on public.community_puzzle_likes for insert
with check (auth.uid() = user_id);

drop policy if exists "users can unlike own likes"
  on public.community_puzzle_likes;
create policy "users can unlike own likes"
on public.community_puzzle_likes for delete
using (auth.uid() = user_id);

drop policy if exists "imports are readable"
  on public.community_puzzle_imports;
create policy "imports are readable"
on public.community_puzzle_imports for select
using (true);

drop policy if exists "users can mark own imports"
  on public.community_puzzle_imports;
create policy "users can mark own imports"
on public.community_puzzle_imports for insert
with check (auth.uid() = user_id);

drop policy if exists "reports are readable by reporter"
  on public.community_puzzle_reports;
create policy "reports are readable by reporter"
on public.community_puzzle_reports for select
using (auth.uid() = user_id);

drop policy if exists "users can report as themselves"
  on public.community_puzzle_reports;
create policy "users can report as themselves"
on public.community_puzzle_reports for insert
with check (auth.uid() = user_id);
