alter table public.community_puzzles
  add column if not exists objective_type text not null default 'mate'
    check (objective_type in ('mate', 'material_gain')),
  add column if not exists objective jsonb not null default '{}'::jsonb;

create index if not exists community_puzzles_status_objective_created_idx
  on public.community_puzzles(status, objective_type, created_at desc);
