import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final options = _Options.parse(args);
  final catalog = _readJson(options.inputPath);
  final puzzles = List<Map<String, dynamic>>.from(
    (catalog['puzzles'] as List<dynamic>? ?? const <dynamic>[]).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );
  final materialPuzzles = _readOptionalPuzzles(options.materialInputPath);

  final selected = _selectSeedPuzzles(puzzles, materialPuzzles, options);
  if (selected.length < options.totalCount) {
    stderr.writeln(
      'Only selected ${selected.length}/${options.totalCount} seed puzzles.',
    );
    exitCode = 2;
  }

  final communityRows = <Map<String, dynamic>>[];
  for (var i = 0; i < selected.length; i++) {
    communityRows.add(_toCommunitySeedRow(selected[i], i + 1));
  }

  _writeJson(options.previewPath, <String, dynamic>{
    'version': '1.0-community-seed-preview',
    'generated': DateTime.now().toIso8601String(),
    'total': selected.length,
    'categories': _countCategories(selected),
    'puzzles': selected,
  });
  _writeJson(options.manifestPath, <String, dynamic>{
    'version': '1.0-community-seed-manifest',
    'generated': DateTime.now().toIso8601String(),
    'input': options.inputPath,
    'total': communityRows.length,
    'rows': communityRows,
  });
  _writeText(options.outputPath, _buildSql(communityRows));

  stdout.writeln(jsonEncode({
    'selected': selected.length,
    'mate':
        selected.where((puzzle) => _objectiveTypeOf(puzzle) == 'mate').length,
    'materialGain': selected
        .where((puzzle) => _objectiveTypeOf(puzzle) == 'material_gain')
        .length,
    'mate1': selected
        .where((puzzle) => _objectiveTypeOf(puzzle) == 'mate')
        .where((puzzle) => puzzle['mateIn'] == 1)
        .length,
    'mate2': selected
        .where((puzzle) => _objectiveTypeOf(puzzle) == 'mate')
        .where((puzzle) => puzzle['mateIn'] == 2)
        .length,
    'mate3': selected
        .where((puzzle) => _objectiveTypeOf(puzzle) == 'mate')
        .where((puzzle) => puzzle['mateIn'] == 3)
        .length,
    'sql': options.outputPath,
    'manifest': options.manifestPath,
    'preview': options.previewPath,
  }));
}

class _Options {
  const _Options({
    required this.inputPath,
    required this.outputPath,
    required this.manifestPath,
    required this.previewPath,
    required this.totalCount,
    required this.mate1Count,
    required this.mate2Count,
    required this.mate3Count,
    required this.materialInputPath,
    required this.materialCount,
  });

  final String inputPath;
  final String outputPath;
  final String manifestPath;
  final String previewPath;
  final int totalCount;
  final int mate1Count;
  final int mate2Count;
  final int mate3Count;
  final String materialInputPath;
  final int materialCount;

  static _Options parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';
    var outputPath = 'supabase/seeds/20260428_community_seed_self_verified.sql';
    var manifestPath =
        'supabase/seeds/20260428_community_seed_self_verified_manifest.json';
    var previewPath =
        'supabase/seeds/20260428_community_seed_self_verified_puzzles.json';
    var totalCount = 20;
    var mate1Count = 8;
    var mate2Count = 3;
    var mate3Count = 1;
    var materialInputPath =
        'dev/test_tmp/material_gain_strict_local_28_depth8.json';
    var materialCount = 8;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--output':
          outputPath = args[++i];
          break;
        case '--manifest':
          manifestPath = args[++i];
          break;
        case '--preview':
          previewPath = args[++i];
          break;
        case '--count':
          totalCount = int.parse(args[++i]);
          break;
        case '--mate1':
          mate1Count = int.parse(args[++i]);
          break;
        case '--mate2':
          mate2Count = int.parse(args[++i]);
          break;
        case '--mate3':
          mate3Count = int.parse(args[++i]);
          break;
        case '--material-input':
          materialInputPath = args[++i];
          break;
        case '--material-count':
          materialCount = int.parse(args[++i]);
          break;
        case '--help':
        case '-h':
          _printUsage();
          exit(0);
        default:
          stderr.writeln('Unknown argument: ${args[i]}');
          _printUsage();
          exit(64);
      }
    }

    return _Options(
      inputPath: inputPath,
      outputPath: outputPath,
      manifestPath: manifestPath,
      previewPath: previewPath,
      totalCount: totalCount,
      mate1Count: mate1Count,
      mate2Count: mate2Count,
      mate3Count: mate3Count,
      materialInputPath: materialInputPath,
      materialCount: materialCount,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/build_community_seed_sql.dart [options]

Options:
  --input <path>     Validated puzzle catalog JSON
  --output <path>    SQL seed output
  --manifest <path>  Seed manifest JSON output
  --preview <path>   Selected puzzle preview JSON output
  --count <n>        Total rows (default: 20)
  --mate1 <n>        1-move mate rows (default: 8)
  --mate2 <n>        2-move mate rows (default: 3)
  --mate3 <n>        3-move mate rows (default: 1)
  --material-input <path> Validated material-gain JSON
  --material-count <n>    Material-gain rows (default: 8)
''');
  }
}

List<Map<String, dynamic>> _selectSeedPuzzles(
  List<Map<String, dynamic>> puzzles,
  List<Map<String, dynamic>> materialPuzzles,
  _Options options,
) {
  final selected = <Map<String, dynamic>>[];
  final seen = <String>{};

  void addMate(int mateIn, int count) {
    final candidates = puzzles
        .where((puzzle) => puzzle['mateIn'] == mateIn)
        .where(_isStrictlyValidated)
        .where((puzzle) => seen.add(_dedupeKey(puzzle)))
        .take(count)
        .map((puzzle) => Map<String, dynamic>.from(puzzle))
        .toList(growable: false);
    selected.addAll(candidates);
  }

  addMate(1, options.mate1Count);
  addMate(2, options.mate2Count);
  addMate(3, options.mate3Count);
  selected.addAll(
    _selectMaterialGainPuzzles(
      materialPuzzles,
      options.materialCount,
      seen,
    ),
  );

  if (selected.length < options.totalCount) {
    final remaining = options.totalCount - selected.length;
    final fill = puzzles
        .where(_isStrictlyValidated)
        .where((puzzle) => seen.add(_dedupeKey(puzzle)))
        .take(remaining)
        .map((puzzle) => Map<String, dynamic>.from(puzzle));
    selected.addAll(fill);
  }

  return selected.take(options.totalCount).toList(growable: false);
}

List<Map<String, dynamic>> _selectMaterialGainPuzzles(
  List<Map<String, dynamic>> puzzles,
  int count,
  Set<String> seen,
) {
  if (count <= 0 || puzzles.isEmpty) return const <Map<String, dynamic>>[];

  Iterable<Map<String, dynamic>> source = puzzles
      .where((puzzle) => _objectiveTypeOf(puzzle) == 'material_gain')
      .where((puzzle) =>
          !(puzzle['id'] as String? ?? '').toLowerCase().contains('tmp_one'));

  var selected = _takeUniqueMaterialPuzzles(source, count, seen);
  if (selected.length >= count) {
    return selected;
  }

  source =
      puzzles.where((puzzle) => _objectiveTypeOf(puzzle) == 'material_gain');
  selected = <Map<String, dynamic>>[
    ...selected,
    ..._takeUniqueMaterialPuzzles(source, count - selected.length, seen),
  ];
  return selected.take(count).toList(growable: false);
}

List<Map<String, dynamic>> _takeUniqueMaterialPuzzles(
  Iterable<Map<String, dynamic>> puzzles,
  int count,
  Set<String> seen,
) {
  final selected = <Map<String, dynamic>>[];
  for (final puzzle in puzzles) {
    if (selected.length >= count) break;
    final key = _dedupeKey(puzzle);
    if (!seen.add(key)) continue;
    selected.add(Map<String, dynamic>.from(puzzle));
  }
  return selected;
}

bool _isStrictlyValidated(Map<String, dynamic> puzzle) {
  final validation =
      Map<String, dynamic>.from(puzzle['validation'] as Map? ?? const {});
  return validation['strictPass'] == true &&
      validation['firstMoveMatches'] == true &&
      validation['uniqueFirstMove'] == true &&
      validation['linePerfect'] == true &&
      validation['finalMateResolved'] == true;
}

String _dedupeKey(Map<String, dynamic> puzzle) {
  return jsonEncode({
    'fen': puzzle['fen'],
    'solution': puzzle['solution'],
    'objectiveType': puzzle['objectiveType'] ?? 'mate',
  });
}

Map<String, dynamic> _toCommunitySeedRow(
  Map<String, dynamic> puzzle,
  int sequence,
) {
  if (_objectiveTypeOf(puzzle) == 'material_gain') {
    return _toMaterialGainSeedRow(puzzle, sequence);
  }

  final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
  final toMove = puzzle['toMove'] == 'red' ? 'red' : 'blue';
  final sideLabel = toMove == 'red' ? '한' : '초';
  final padded = sequence.toString().padLeft(2, '0');
  final originalId = puzzle['id'] as String? ?? '';
  final copy = _curatedCopyByOriginalId[originalId];

  return <String, dynamic>{
    'sequence': sequence,
    'originalId': originalId,
    'title': copy?.title ?? '자가검증 $mateIn수 외통 #$padded',
    'description':
        copy?.description ?? '엔진 검증 카탈로그 기반 $mateIn수 외통 · $sideLabel 차례',
    'fen': puzzle['fen'],
    'solution': List<String>.from(puzzle['solution'] as List),
    'mateIn': mateIn,
    'toMove': toMove,
    'objectiveType': 'mate',
    'objective': <String, dynamic>{},
    'source': puzzle['source'],
    'validation': puzzle['validation'],
  };
}

Map<String, dynamic> _toMaterialGainSeedRow(
  Map<String, dynamic> puzzle,
  int sequence,
) {
  final objective =
      Map<String, dynamic>.from(puzzle['objective'] as Map? ?? const {});
  final targetLabel = _materialTargetLabel(objective);
  final mateIn = (objective['maxPlayerMoves'] as num?)?.toInt() ??
      (puzzle['mateIn'] as num?)?.toInt() ??
      1;
  final toMove = puzzle['toMove'] == 'red' ? 'red' : 'blue';
  final sideLabel = toMove == 'red' ? '한' : '초';
  final originalId = puzzle['id'] as String? ?? '';
  final copy = _curatedMaterialCopyByOriginalId[originalId];
  final finalEval = (objective['verifiedFinalEvalCp'] as num?)?.toInt();
  final netGain = (objective['verifiedNetMaterialGainCp'] as num?)?.toInt();
  final evalText = finalEval == null ? '' : ' · 형세 +$finalEval';
  final netText = netGain == null ? '' : ' · 순이득 +$netGain';

  return <String, dynamic>{
    'sequence': sequence,
    'originalId': originalId,
    'title': copy?.title ?? '$targetLabel 획득 전술 #$sequence',
    'description': copy?.description ??
        '$sideLabel가 $mateIn수 안에 $targetLabel을 얻고 우세를 굳히는 목표형 문제$netText$evalText',
    'fen': puzzle['fen'],
    'solution': List<String>.from(puzzle['solution'] as List),
    'mateIn': mateIn,
    'toMove': toMove,
    'objectiveType': 'material_gain',
    'objective': objective,
    'source': puzzle['source'],
    'validation': <String, dynamic>{
      'strictPass': true,
      'engineDepth': objective['engineDepth'],
      if (netGain != null) 'verifiedNetMaterialGainCp': netGain,
      if (finalEval != null) 'verifiedFinalEvalCp': finalEval,
      if (objective['verifiedEvalGainCp'] != null)
        'verifiedEvalGainCp': objective['verifiedEvalGainCp'],
    },
  };
}

const _curatedCopyByOriginalId = <String, _SeedCopy>{
  'm1_01': _SeedCopy(
    title: '차의 직선 침투',
    description: '초 차가 1선에서 8선까지 올라가 궁을 봉쇄하는 1수 외통',
  ),
  'm1_03': _SeedCopy(
    title: '포의 하단 관통',
    description: '한 포가 세로 포선을 열어 초 궁을 직접 묶는 1수 외통',
  ),
  'm1_05': _SeedCopy(
    title: '중앙 포선 봉쇄',
    description: '한이 중앙 포선을 정리해 초 궁의 탈출로를 막는 1수 외통',
  ),
  'm1_06': _SeedCopy(
    title: '마의 졸목 제거',
    description: '초 마가 졸을 잡으며 궁성 주변의 탈출로를 끊는 1수 외통',
  ),
  'm1_07': _SeedCopy(
    title: '포의 끝줄 압박',
    description: '초 포가 끝줄까지 관통해 한 궁의 숨을 끊는 1수 외통',
  ),
  'm1_08': _SeedCopy(
    title: '차로 사를 끊는 수',
    description: '한 차가 사를 제거하며 궁성 방어를 무너뜨리는 1수 외통',
  ),
  'm1_12': _SeedCopy(
    title: '마의 궁성 침투',
    description: '초 마가 궁성 안쪽 급소로 들어가는 1수 외통',
  ),
  'm1_15': _SeedCopy(
    title: '차의 세로 봉쇄',
    description: '한 차가 세로줄을 장악해 초 궁의 탈출을 막는 1수 외통',
  ),
  'm1_16': _SeedCopy(
    title: '차의 궁문 돌파',
    description: '초 차가 두 번째 줄에서 궁문까지 밀고 들어가는 1수 외통',
  ),
  'm1_17': _SeedCopy(
    title: '사 걷어내기',
    description: '초 차가 사를 잡아 궁성 방어의 마지막 칸을 지우는 1수 외통',
  ),
  'm1_18': _SeedCopy(
    title: '마의 측면 급습',
    description: '한 마가 병을 잡으며 초 궁의 이동칸을 지우는 1수 외통',
  ),
  'm1_19': _SeedCopy(
    title: '마의 궁성 봉쇄',
    description: '한 마가 궁성 아래 급소를 차단하는 1수 외통',
  ),
  'm1_20': _SeedCopy(
    title: '차의 끝줄 장악',
    description: '초 차가 오른쪽 끝줄을 타고 한 궁을 묶는 1수 외통',
  ),
  'm2_01': _SeedCopy(
    title: '받아내기를 유도한 포 결착',
    description: '한이 응수를 강제한 뒤 포선으로 다시 묶는 2수 외통',
  ),
  'm2_02': _SeedCopy(
    title: '끝줄 압박 후 차 회수',
    description: '한 차가 끝줄을 압박하고 응수 뒤 다시 잡아내는 2수 외통',
  ),
  'm2_03': _SeedCopy(
    title: '병 미끼와 차 마무리',
    description: '초 병 전진으로 한 궁을 끌어낸 뒤 차로 마무리하는 2수 외통',
  ),
  'm2_05': _SeedCopy(
    title: '사 제거 후 차 회귀',
    description: '한 차가 사를 잡아 궁을 흔들고 다시 1선으로 꽂는 2수 외통',
  ),
  'm2_07': _SeedCopy(
    title: '차 맞교환 유도',
    description: '초 차가 중앙으로 유도한 뒤 상대 차를 잡아 끝내는 2수 외통',
  ),
  'm2_08': _SeedCopy(
    title: '끝줄 차 압박',
    description: '한 차가 끝줄을 잡고 병 응수를 강제한 뒤 다시 내려치는 2수 외통',
  ),
  'm2_09': _SeedCopy(
    title: '포 장군과 차 결착',
    description: '초 포가 궁성 압박을 시작하고 차가 사를 잡아 끝내는 2수 외통',
  ),
  'm2_13': _SeedCopy(
    title: '포를 끊고 마로 봉쇄',
    description: '초 차가 포를 제거한 뒤 마가 궁성 탈출로를 막는 2수 외통',
  ),
  'm3_12': _SeedCopy(
    title: '차-마-포 삼단 봉쇄',
    description: '한 차로 몰고 마로 조이며 포가 마무리하는 3수 외통',
  ),
  'm3_22': _SeedCopy(
    title: '포 압박 후 차 결착',
    description: '한 포가 궁을 밀어내고 차가 상을 걷어내며 끝내는 3수 외통',
  ),
};

const _curatedMaterialCopyByOriginalId = <String, _SeedCopy>{
  'manual_gib__manual_gib_12__mg063_2': _SeedCopy(
    title: '끝줄 차 전환으로 포 획득',
    description: '초가 차를 끝줄로 돌려 포를 얻고 우세를 굳히는 2수 목표',
  ),
  'manual_gib__manual_gib_22__mg062_2': _SeedCopy(
    title: '측면 침투로 차 회수',
    description: '한이 측면 압박으로 상대 차를 끌어내 잡는 2수 목표',
  ),
  'manual_gib__manual_gib_36__mg054_2': _SeedCopy(
    title: '마 진입 후 포 사냥',
    description: '한 마가 깊숙이 들어가 포를 잡고 강한 공격을 남기는 2수 목표',
  ),
  'manual_gib__manual_gib_50__mg060_2': _SeedCopy(
    title: '포와 차를 동시에 노리는 수',
    description: '한이 포선을 정리하며 차와 포를 모두 노리는 2수 목표',
  ),
  'manual_gib__manual_gib_88__mg056_2': _SeedCopy(
    title: '궁성 압박으로 차 획득',
    description: '한이 궁성의 차를 묶어 잡고 유리한 형세를 남기는 2수 목표',
  ),
  'manual_10_gib__manual_10_gib_4__mg078_2': _SeedCopy(
    title: '하단 차 전환과 포 획득',
    description: '한 차가 하단에서 방향을 바꿔 포를 회수하는 2수 목표',
  ),
  'manual_10_gib__manual_10_gib_49__mg085_2': _SeedCopy(
    title: '마 희생 유도 후 차 잡기',
    description: '초가 마로 응수를 강제하고 차를 회수하는 2수 목표',
  ),
  'manual_10_gib__manual_10_gib_58__mg109_2': _SeedCopy(
    title: '포 압박 뒤 차 결착',
    description: '초가 포 압박으로 응수를 묶고 차를 잡아 끝내는 2수 목표',
  ),
};

class _SeedCopy {
  const _SeedCopy({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

Map<String, dynamic> _countCategories(List<Map<String, dynamic>> puzzles) {
  final counts = <String, int>{
    'mate1': 0,
    'mate2': 0,
    'mate3': 0,
    'material_gain': 0,
  };
  for (final puzzle in puzzles) {
    if (_objectiveTypeOf(puzzle) == 'material_gain') {
      counts['material_gain'] = (counts['material_gain'] ?? 0) + 1;
      continue;
    }
    final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
    counts['mate$mateIn'] = (counts['mate$mateIn'] ?? 0) + 1;
  }
  return {
    for (final entry in counts.entries) entry.key: {'count': entry.value},
  };
}

String _objectiveTypeOf(Map<String, dynamic> puzzle) {
  return puzzle['objectiveType'] == 'material_gain' ||
          puzzle['objective_type'] == 'material_gain'
      ? 'material_gain'
      : 'mate';
}

String _materialTargetLabel(Map<String, dynamic> objective) {
  final values = List<String>.from(
    objective['targetPieceTypes'] as List? ?? const <String>[],
  );
  final labels = <String>[
    if (values.contains('chariot')) '차',
    if (values.contains('cannon')) '포',
  ];
  if (labels.isEmpty) return '기물';
  return labels.join('/');
}

String _buildSql(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer()
    ..writeln('-- Community seed generated from locally validated puzzles.')
    ..writeln('-- Safe to re-run: rows are deduped by fen + solution.')
    ..writeln()
    ..writeln('alter table public.community_puzzles')
    ..writeln(
        "  add column if not exists objective_type text not null default 'mate'")
    ..writeln("    check (objective_type in ('mate', 'material_gain')),")
    ..writeln(
        "  add column if not exists objective jsonb not null default '{}'::jsonb;")
    ..writeln()
    ..writeln(
        'create index if not exists community_puzzles_status_objective_created_idx')
    ..writeln(
        '  on public.community_puzzles(status, objective_type, created_at desc);')
    ..writeln()
    ..writeln('do \$\$')
    ..writeln('begin')
    ..writeln('  if not exists (select 1 from auth.users) then')
    ..writeln(
        "    raise exception 'No Supabase auth user exists. Sign in once with Google first.';")
    ..writeln('  end if;')
    ..writeln('end')
    ..writeln('\$\$;')
    ..writeln()
    ..writeln('with selected_author as (')
    ..writeln('  select')
    ..writeln('    id,')
    ..writeln(
        "    coalesce(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', email, 'Google 사용자') as display_name,")
    ..writeln("    raw_user_meta_data->>'avatar_url' as avatar_url")
    ..writeln('  from auth.users')
    ..writeln('  order by last_sign_in_at desc nulls last, created_at desc')
    ..writeln('  limit 1')
    ..writeln('), upsert_profile as (')
    ..writeln('  insert into public.profiles (id, display_name, avatar_url)')
    ..writeln('  select id, display_name, avatar_url from selected_author')
    ..writeln('  on conflict (id) do update set')
    ..writeln('    display_name = excluded.display_name,')
    ..writeln('    avatar_url = excluded.avatar_url,')
    ..writeln('    updated_at = now()')
    ..writeln('  returning id')
    ..writeln(
        '), seed_rows (title, description, fen, solution, mate_in, to_move, objective_type, objective) as (')
    ..writeln('  values');

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final suffix = i == rows.length - 1 ? '' : ',';
    buffer.writeln(
      '    (${_sqlString(row['title'])}, ${_sqlString(row['description'])}, '
      '${_sqlString(row['fen'])}, ${_sqlJson(row['solution'])}::jsonb, '
      '${row['mateIn']}, ${_sqlString(row['toMove'])}, '
      "${_sqlString(row['objectiveType'])}, ${_sqlJson(row['objective'])}::jsonb)$suffix",
    );
  }

  buffer
    ..writeln(')')
    ..writeln('insert into public.community_puzzles (')
    ..writeln(
        '  author_id, title, description, fen, solution, mate_in, to_move,')
    ..writeln('  objective_type, objective, status')
    ..writeln(')')
    ..writeln('select')
    ..writeln('  (select id from upsert_profile),')
    ..writeln('  sr.title, sr.description, sr.fen, sr.solution, sr.mate_in,')
    ..writeln("  sr.to_move, sr.objective_type, sr.objective, 'published'")
    ..writeln('from seed_rows sr')
    ..writeln('where not exists (')
    ..writeln('  select 1')
    ..writeln('  from public.community_puzzles existing')
    ..writeln('  where existing.fen = sr.fen')
    ..writeln('    and existing.solution = sr.solution')
    ..writeln("    and existing.status <> 'deleted'")
    ..writeln(')')
    ..writeln('returning title, mate_in, to_move;');

  return buffer.toString();
}

String _sqlString(dynamic value) {
  final text = (value ?? '').toString().replaceAll("'", "''");
  return "'$text'";
}

String _sqlJson(dynamic value) {
  return _sqlString(jsonEncode(value));
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Input file not found: $path');
    exit(66);
  }
  return Map<String, dynamic>.from(
    jsonDecode(file.readAsStringSync(encoding: utf8)) as Map,
  );
}

List<Map<String, dynamic>> _readOptionalPuzzles(String path) {
  if (path.trim().isEmpty) return const <Map<String, dynamic>>[];
  final file = File(path);
  if (!file.existsSync()) return const <Map<String, dynamic>>[];
  final decoded = jsonDecode(file.readAsStringSync(encoding: utf8));
  if (decoded is! Map) return const <Map<String, dynamic>>[];
  return List<Map<String, dynamic>>.from(
    (decoded['puzzles'] as List<dynamic>? ?? const <dynamic>[]).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );
}

void _writeJson(String path, Map<String, dynamic> value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    encoding: utf8,
  );
}

void _writeText(String path, String value) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(value, encoding: utf8);
}
