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
    ('차의 직선 침투', '초 차가 1선에서 8선까지 올라가 궁을 봉쇄하는 1수 외통', '5ar2/7R1/5k3/1p3b1p1/6p2/5P1c1/7r1/4CC3/4AA3/R1B1K1B2 w - - 0 1', '["a1a8"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('포의 하단 관통', '한 포가 세로 포선을 열어 초 궁을 직접 묶는 1수 외통', 'r4a3/3ka4/2cb5/1pp2B3/1r7/4R3P/1n2NPPN1/3KC4/3A1A1n1/9 b - - 0 1', '["c8c2"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('중앙 포선 봉쇄', '한이 중앙 포선을 정리해 초 궁의 탈출로를 막는 1수 외통', 'C4a3/1R1ak4/3ccb3/6pp1/3p1p3/9/B4NPP1/5B3/2nA5/4KA2r b - - 0 1', '["d6e6"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('마의 졸목 제거', '초 마가 졸을 잡으며 궁성 주변의 탈출로를 끊는 1수 외통', 'N2a5/5R3/3k1c3/4R4/2p6/7P1/1PPN5/5n1c1/4KA1r1/9 w - - 0 1', '["d4c6"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('포의 끝줄 압박', '초 포가 끝줄까지 관통해 한 궁의 숨을 끊는 1수 외통', '4k1b2/4a4/6n1r/1p2p1B1p/5N3/1R7/3b1PPP1/3cC4/4K2C1/2r6 w - - 0 1', '["h2h10"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('차로 사를 끊는 수', '한 차가 사를 제거하며 궁성 방어를 무너뜨리는 1수 외통', '2b1ka3/4a4/2ncc4/1p5p1/3P3P1/1PR2b3/7R1/4N3C/4AB3/r2AKCr2 b - - 0 1', '["a1d1"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('마의 궁성 침투', '초 마가 궁성 안쪽 급소로 들어가는 1수 외통', '3k2c2/3aa4/1c1b5/4N1Brb/1pp1p3n/3P5/P1P5B/9/3NAA3/R3KC3 w - - 0 1', '["e7c8"]'::jsonb, 1, 'blue', 'mate', '{}'::jsonb),
    ('차의 세로 봉쇄', '한 차가 세로줄을 장악해 초 궁의 탈출을 막는 1수 외통', '2b2a3/2Rak4/5c1r1/2p3p1p/5P3/2C6/4c3P/3N1A3/5K3/5AB2 b - - 0 1', '["h8h2"]'::jsonb, 1, 'red', 'mate', '{}'::jsonb),
    ('받아내기를 유도한 포 결착', '한이 응수를 강제한 뒤 포선으로 다시 묶는 2수 외통', '3aka1nR/6R2/2n1c4/3pb4/2r2p3/P8/2b1Bc2P/2N1CCr2/4AK3/3A3N1 b - - 0 1', '["g3f3","f2f3","f4f7"]'::jsonb, 2, 'red', 'mate', '{}'::jsonb),
    ('끝줄 압박 후 차 회수', '한 차가 끝줄을 압박하고 응수 뒤 다시 잡아내는 2수 외통', '3ck4/4a2R1/3bca3/3pp1CN1/8r/2P6/2b3PP1/3B1K3/3AA3C/rn6R b - - 0 1', '["i6i3","g7g3","i3g3"]'::jsonb, 2, 'red', 'mate', '{}'::jsonb),
    ('병 미끼와 차 마무리', '초 병 전진으로 한 궁을 끌어낸 뒤 차로 마무리하는 2수 외통', '2ba5/4ak3/1C4P2/2ppnN2R/5r3/4c4/2PN5/4C4/3AK4/5A3 w - - 0 1', '["g8g9","f9f8","i7i8"]'::jsonb, 2, 'blue', 'mate', '{}'::jsonb),
    ('차-마-포 삼단 봉쇄', '한 차로 몰고 마로 조이며 포가 마무리하는 3수 외통', 'c2k5/n3a4/3a5/1N2cN2C/9/1B3P1P1/1r7/9/4AA3/n2K5 b - - 0 1', '["b4b1","d1d2","a1b3","d2d3","a10a3"]'::jsonb, 3, 'red', 'mate', '{}'::jsonb),
    ('끝줄 차 전환으로 포 획득', '초가 차를 끝줄로 돌려 포를 얻고 우세를 굳히는 2수 목표', 'R2ack3/9/5a3/4bpp2/2pp1r3/1P4N2/3P2PP1/1C2CN3/4KAr2/5A3 w - - 0 1', '["a10d10","f10f9","d10e10"]'::jsonb, 2, 'blue', 'material_gain', '{"targetPieceTypes":["cannon"],"maxPlayerMoves":2,"minNetMaterialGainCp":300,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":700,"verifiedFinalEvalCp":738,"verifiedEvalGainCp":507,"engineDepth":8}'::jsonb),
    ('측면 침투로 차 회수', '한이 측면 압박으로 상대 차를 끌어내 잡는 2수 목표', '2r1ka3/4a2c1/4c4/p1ppn4/9/6Rbn/PP7/3CCN3/3A1A3/1B3K3 b - - 0 1', '["i5h7","f2e2","h7g5"]'::jsonb, 2, 'red', 'material_gain', '{"targetPieceTypes":["chariot"],"maxPlayerMoves":2,"minNetMaterialGainCp":450,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":900,"verifiedFinalEvalCp":1153,"verifiedEvalGainCp":339,"engineDepth":8}'::jsonb),
    ('마 진입 후 포 사냥', '한 마가 깊숙이 들어가 포를 잡고 강한 공격을 남기는 2수 목표', '5a1C1/1R1ak4/3ccn3/6pp1/3p1p3/3n5/B4BPP1/4CN3/4A4/4KA2r b - - 0 1', '["d5e3","h10a10","e3c2"]'::jsonb, 2, 'red', 'material_gain', '{"targetPieceTypes":["cannon"],"maxPlayerMoves":2,"minNetMaterialGainCp":300,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":500,"verifiedFinalEvalCp":100000,"verifiedEvalGainCp":98589,"engineDepth":8}'::jsonb),
    ('포와 차를 동시에 노리는 수', '한이 포선을 정리하며 차와 포를 모두 노리는 2수 목표', '3a1a3/4k4/2n2n3/rpp1bb1R1/4p4/9/c2P2r1P/4C4/2RA5/3CKAN2 b - - 0 1', '["f8h7","e3e7","c8e7"]'::jsonb, 2, 'red', 'material_gain', '{"targetPieceTypes":["cannon","chariot"],"maxPlayerMoves":2,"minNetMaterialGainCp":450,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":950,"verifiedFinalEvalCp":1530,"verifiedEvalGainCp":164,"engineDepth":8}'::jsonb),
    ('궁성 압박으로 차 획득', '한이 궁성의 차를 묶어 잡고 유리한 형세를 남기는 2수 목표', '2r1kcb2/1R1aR4/3r4n/b4pp1p/c1B6/6N2/3PN1PP1/4C4/4K4/2BA1A3 b - - 0 1', '["d9e9","e3e9","c10c6"]'::jsonb, 2, 'red', 'material_gain', '{"targetPieceTypes":["chariot"],"maxPlayerMoves":2,"minNetMaterialGainCp":450,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":1150,"verifiedFinalEvalCp":439,"verifiedEvalGainCp":635,"engineDepth":8}'::jsonb),
    ('하단 차 전환과 포 획득', '한 차가 하단에서 방향을 바꿔 포를 회수하는 2수 목표', '5k3/4aa3/4c4/R8/1p4pp1/4C4/2P1P2P1/9/3N5/2rC1K3 b - - 0 1', '["c1d1","f1f2","d1d2"]'::jsonb, 2, 'red', 'material_gain', '{"targetPieceTypes":["cannon"],"maxPlayerMoves":2,"minNetMaterialGainCp":300,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":950,"verifiedFinalEvalCp":538,"verifiedEvalGainCp":439,"engineDepth":8}'::jsonb),
    ('마 희생 유도 후 차 잡기', '초가 마로 응수를 강제하고 차를 회수하는 2수 목표', 'r5n2/5k3/4Ncn2/pB6b/3r5/9/1PP6/3A5/3KAN3/R3C4 w - - 0 1', '["e8d6","a10c10","a1a7"]'::jsonb, 2, 'blue', 'material_gain', '{"targetPieceTypes":["chariot"],"maxPlayerMoves":2,"minNetMaterialGainCp":450,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":1000,"verifiedFinalEvalCp":1065,"verifiedEvalGainCp":489,"engineDepth":8}'::jsonb),
    ('포 압박 뒤 차 결착', '초가 포 압박으로 응수를 묶고 차를 잡아 끝내는 2수 목표', '9/3ka1R2/4r4/2B6/3r5/6R2/P3p2P1/4C4/4A4/c3KA3 w - - 0 1', '["e3e8","d6c6","g5d5"]'::jsonb, 2, 'blue', 'material_gain', '{"targetPieceTypes":["chariot"],"maxPlayerMoves":2,"minNetMaterialGainCp":450,"minFinalEvalCp":250,"minEvalGainCp":150,"verifiedNetMaterialGainCp":900,"verifiedFinalEvalCp":100000,"verifiedEvalGainCp":98700,"engineDepth":8}'::jsonb)
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
