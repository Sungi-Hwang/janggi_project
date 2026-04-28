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

  final selected = _selectSeedPuzzles(puzzles, options);
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
    'mate1': selected.where((puzzle) => puzzle['mateIn'] == 1).length,
    'mate2': selected.where((puzzle) => puzzle['mateIn'] == 2).length,
    'mate3': selected.where((puzzle) => puzzle['mateIn'] == 3).length,
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
  });

  final String inputPath;
  final String outputPath;
  final String manifestPath;
  final String previewPath;
  final int totalCount;
  final int mate1Count;
  final int mate2Count;
  final int mate3Count;

  static _Options parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';
    var outputPath = 'supabase/seeds/20260428_community_seed_self_verified.sql';
    var manifestPath =
        'supabase/seeds/20260428_community_seed_self_verified_manifest.json';
    var previewPath =
        'supabase/seeds/20260428_community_seed_self_verified_puzzles.json';
    var totalCount = 20;
    var mate1Count = 12;
    var mate2Count = 6;
    var mate3Count = 2;

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
  --mate1 <n>        1-move mate rows (default: 12)
  --mate2 <n>        2-move mate rows (default: 6)
  --mate3 <n>        3-move mate rows (default: 2)
''');
  }
}

List<Map<String, dynamic>> _selectSeedPuzzles(
  List<Map<String, dynamic>> puzzles,
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
  final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
  final toMove = puzzle['toMove'] == 'red' ? 'red' : 'blue';
  final sideLabel = toMove == 'red' ? '한' : '초';
  final padded = sequence.toString().padLeft(2, '0');

  return <String, dynamic>{
    'sequence': sequence,
    'originalId': puzzle['id'],
    'title': '자가검증 $mateIn수 외통 #$padded',
    'description': '엔진 검증 카탈로그 기반 $mateIn수 외통 · $sideLabel 차례',
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

Map<String, dynamic> _countCategories(List<Map<String, dynamic>> puzzles) {
  final counts = <String, int>{'mate1': 0, 'mate2': 0, 'mate3': 0};
  for (final puzzle in puzzles) {
    final mateIn = (puzzle['mateIn'] as num?)?.toInt() ?? 1;
    counts['mate$mateIn'] = (counts['mate$mateIn'] ?? 0) + 1;
  }
  return {
    for (final entry in counts.entries) entry.key: {'count': entry.value},
  };
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
