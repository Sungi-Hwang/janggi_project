-- Community seed generated from locally validated puzzles.
-- Safe to re-run: rows are deduped by fen + solution.

alter table public.community_puzzles
  add column if not exists objective_type text not null default 'mate'
    check (objective_type in ('mate', 'material_gain')),
  add column if not exists objective jsonb not null default '{}'::jsonb;

create index if not exists community_puzzles_status_objective_created_idx
  on public.community_puzzles(status, objective_type, created_at desc);

do $$
begin
  if not exists (select 1 from auth.users) then
    raise exception 'No Supabase auth user exists. Sign in once with Google first.';
  end if;
end
$$;

with selected_author as (
  select
    id,
    coalesce(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', email, 'Google 사용자') as display_name,
    raw_user_meta_data->>'avatar_url' as avatar_url
  from auth.users
  order by last_sign_in_at desc nulls last, created_at desc
  limit 1
), upsert_profile as (
  insert into public.profiles (id, display_name, avatar_url)
  select id, display_name, avatar_url from selected_author
  on conflict (id) do update set
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now()
  returning id
), seed_rows (title, description, fen, solution, mate_in, to_move, objective_type, objective) as (
  values
    ('자가검증 1수 외통 #01', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', '5ar2/7R1/5k3/1p3b1p1/6p2/5P1c1/7r1/4CC3/4AA3/R1B1K1B2 w - - 0 1', '["a1a8"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #02', '엔진 검증 카탈로그 기반 1수 외통 · 한 차례', 'r4a3/3ka4/2cb5/1pp2B3/1r7/4R3P/1n2NPPN1/3KC4/3A1A1n1/9 b - - 0 1', '["c8c2"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #03', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', 'N2a5/5R3/3k1c3/4R4/2p6/7P1/1PPN5/5n1c1/4KA1r1/9 w - - 0 1', '["d4c6"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #04', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', '4k1b2/4a4/6n1r/1p2p1B1p/5N3/1R7/3b1PPP1/3cC4/4K2C1/2r6 w - - 0 1', '["h2h10"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #05', '엔진 검증 카탈로그 기반 1수 외통 · 한 차례', '2b1ka3/4a4/2ncc4/1p5p1/3P3P1/1PR2b3/7R1/4N3C/4AB3/r2AKCr2 b - - 0 1', '["a1d1"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #06', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', '3k2c2/3aa4/1c1b5/4N1Brb/1pp1p3n/3P5/P1P5B/9/3NAA3/R3KC3 w - - 0 1', '["e7c8"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #07', '엔진 검증 카탈로그 기반 1수 외통 · 한 차례', '2b2a3/2Rak4/5c1r1/2p3p1p/5P3/2C6/4c3P/3N1A3/5K3/5AB2 b - - 0 1', '["h8h2"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #08', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', '9/3ka4/2Na5/p4npp1/2p6/6PP1/c1Pp5/2N1C4/1R2KA3/3A2B2 w - - 0 1', '["b2b9"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #09', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', 'C1bak4/3Rac3/3N5/5p3/1p4p2/4P4/4P1P2/4N4/4K4/2C5r w - - 0 1', '["d9d10"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #10', '엔진 검증 카탈로그 기반 1수 외통 · 한 차례', 'r3c4/9/4kCn2/b4R3/7p1/3n5/1P5P1/3K1B3/3A1Ar2/3N5 b - - 0 1', '["d5b4"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #11', '엔진 검증 카탈로그 기반 1수 외통 · 한 차례', '5a3/4ka2R/4cb3/9/1pp3p2/7NB/P1n1PP3/3C3B1/c8/4CK3 b - - 0 1', '["c4d2"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('자가검증 1수 외통 #12', '엔진 검증 카탈로그 기반 1수 외통 · 초 차례', '5k3/4aa3/5c3/4c4/9/5p3/4p3R/9/4A4/4K4 w - - 0 1', '["i4i10"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #13', '엔진 검증 카탈로그 기반 2수 외통 · 초 차례', '2ba5/4ak3/1C4P2/2ppnN2R/5r3/4c4/2PN5/4C4/3AK4/5A3 w - - 0 1', '["g8g9","f9f8","i7i8"]'::jsonb, 2, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #14', '엔진 검증 카탈로그 기반 2수 외통 · 한 차례', '5a3/4ka1R1/4ccr2/p4r1p1/2pP5/9/4B3P/2R2A3/4A4/5K3 b - - 0 1', '["f7f3","f1e1","g8g1"]'::jsonb, 2, 'red', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #15', '엔진 검증 카탈로그 기반 2수 외통 · 초 차례', '9/3ka1R2/4C4/2B6/2r6/6R2/P3p2P1/9/4A4/c3KA3 w - - 0 1', '["g5d5","c6d6","d5d6"]'::jsonb, 2, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #16', '엔진 검증 카탈로그 기반 2수 외통 · 한 차례', '2rk1a3/4n3r/4B4/6pp1/9/p2b5/1R1n2P1P/9/3C5/4CK3 b - - 0 1', '["i9f9","g4f4","f9f4"]'::jsonb, 2, 'red', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #17', '엔진 검증 카탈로그 기반 2수 외통 · 초 차례', '5k1r1/2C1a3R/4ca3/2B6/5p1p1/9/3PB1P2/3A5/4A4/4KC3 w - - 0 1', '["f1f7","e9f9","i9f9"]'::jsonb, 2, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 2수 외통 #18', '엔진 검증 카탈로그 기반 2수 외통 · 초 차례', '1C1ab4/3a3rC/3k1cR2/N2ppn1p1/4c4/2B2p3/8R/2N6/4AA3/3K5 w - - 0 1', '["g8f8","e6e8","a7b9"]'::jsonb, 2, 'blue', 'mate', '{}'::jsonb),
    ('자가검증 3수 외통 #19', '엔진 검증 카탈로그 기반 3수 외통 · 한 차례', 'c2k5/n3a4/3a5/1N2cN2C/9/1B3P1P1/1r7/9/4AA3/n2K5 b - - 0 1', '["b4b1","d1d2","a1b3","d2d3","a10a3"]'::jsonb, 3, 'red', 'mate', '{}'::jsonb),
    ('자가검증 3수 외통 #20', '엔진 검증 카탈로그 기반 3수 외통 · 한 차례', '4k4/4a1P2/5a3/1pp3RB1/9/3r5/2b6/4A4/1b1cK4/9 b - - 0 1', '["d2a2","e2f3","d5f5","h7f4","f5f4"]'::jsonb, 3, 'red', 'mate', '{}'::jsonb)
)
insert into public.community_puzzles (
  author_id, title, description, fen, solution, mate_in, to_move,
  objective_type, objective, status
)
select
  (select id from upsert_profile),
  sr.title, sr.description, sr.fen, sr.solution, sr.mate_in,
  sr.to_move, sr.objective_type, sr.objective, 'published'
from seed_rows sr
where not exists (
  select 1
  from public.community_puzzles existing
  where existing.fen = sr.fen
    and existing.solution = sr.solution
    and existing.status <> 'deleted'
)
returning title, mate_in, to_move;
