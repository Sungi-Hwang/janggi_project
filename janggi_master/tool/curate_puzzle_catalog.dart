import 'dart:convert';
import 'dart:io';

const _removedIds = {
  'm1_45',
  'm1_50',
  'm1_54',
  'm1_67',
  'm1_71',
  'm1_115',
  'm1_117',
  'm1_158',
  'm1_162',
  'm1_176',
  'm1_196',
  'm1_198',
  'm1_213',
  'm1_217',
  'm1_228',
  'm1_246',
  'm2_15',
  'm2_33',
  'm2_42',
  'm2_50',
  'm2_53',
  'm2_60',
};
const _promotedIds = <String>{};

final _mate1TitlePattern = RegExp(r'^1수 외통 #(\d+)$');

class _Options {
  const _Options({
    required this.inputPath,
  });

  final String inputPath;

  static _Options parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--help':
        case '-h':
          stdout.writeln('''
Usage: dart run tool/curate_puzzle_catalog.dart [options]

Options:
  --input <path>   Puzzle catalog JSON (default: assets/puzzles/puzzles.json)
''');
          exit(0);
        default:
          stderr.writeln('Unknown argument: ${args[i]}');
          exit(64);
      }
    }

    return _Options(inputPath: inputPath);
  }
}

class _IndexedPuzzle {
  const _IndexedPuzzle({
    required this.originalIndex,
    required this.puzzle,
  });

  final int originalIndex;
  final Map<String, dynamic> puzzle;
}

void main(List<String> args) {
  final options = _Options.parse(args);
  final file = File(options.inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Input file not found: ${options.inputPath}');
    exit(66);
  }

  final raw = file.readAsStringSync(encoding: utf8);
  final normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  final data = Map<String, dynamic>.from(jsonDecode(normalized) as Map);
  final originalPuzzles = List<Map<String, dynamic>>.from(
    (data['puzzles'] as List<dynamic>).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );

  var nextMate1TitleNumber = _findNextMate1TitleNumber(originalPuzzles);
  final curated = <_IndexedPuzzle>[];
  var removedCount = 0;
  var promotedCount = 0;

  for (var i = 0; i < originalPuzzles.length; i++) {
    final puzzle = Map<String, dynamic>.from(originalPuzzles[i]);
    final id = puzzle['id'] as String? ?? '';

    if (_removedIds.contains(id)) {
      removedCount++;
      continue;
    }

    if (_promotedIds.contains(id)) {
      promotedCount++;
      final solution = List<String>.from(puzzle['solution'] as List<dynamic>);
      puzzle['mateIn'] = 1;
      puzzle['difficulty'] = 1;
      puzzle['title'] = '1수 외통 #$nextMate1TitleNumber';
      puzzle['solution'] = <String>[solution.first];
      nextMate1TitleNumber++;
    }

    curated.add(_IndexedPuzzle(originalIndex: i, puzzle: puzzle));
  }

  curated.sort((a, b) {
    final mateCompare =
        (a.puzzle['mateIn'] as int).compareTo(b.puzzle['mateIn'] as int);
    if (mateCompare != 0) return mateCompare;
    return a.originalIndex.compareTo(b.originalIndex);
  });

  final curatedPuzzles = curated.map((entry) => entry.puzzle).toList();
  final counts = _countByMate(curatedPuzzles);

  data['generated'] = DateTime.now().toIso8601String();
  data['total'] = curatedPuzzles.length;
  data['puzzles'] = curatedPuzzles;
  data['categories'] = _updateCategories(
    Map<String, dynamic>.from(data['categories'] as Map? ?? const {}),
    counts,
  );

  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);

  stdout.writeln(jsonEncode({
    'removed': removedCount,
    'promoted': promotedCount,
    'remaining': curatedPuzzles.length,
    'mate1': counts[1] ?? 0,
    'mate2': counts[2] ?? 0,
    'mate3': counts[3] ?? 0,
    'nextMate1TitleNumber': nextMate1TitleNumber,
  }));
}

int _findNextMate1TitleNumber(List<Map<String, dynamic>> puzzles) {
  var maxTitleNumber = 0;
  for (final puzzle in puzzles) {
    if (puzzle['mateIn'] != 1) continue;
    final title = puzzle['title'] as String? ?? '';
    final match = _mate1TitlePattern.firstMatch(title);
    if (match == null) continue;
    final value = int.tryParse(match.group(1) ?? '');
    if (value != null && value > maxTitleNumber) {
      maxTitleNumber = value;
    }
  }
  return maxTitleNumber + 1;
}

Map<int, int> _countByMate(List<Map<String, dynamic>> puzzles) {
  final counts = <int, int>{1: 0, 2: 0, 3: 0};
  for (final puzzle in puzzles) {
    final mateIn = puzzle['mateIn'] as int;
    counts[mateIn] = (counts[mateIn] ?? 0) + 1;
  }
  return counts;
}

Map<String, dynamic> _updateCategories(
  Map<String, dynamic> categories,
  Map<int, int> counts,
) {
  final next = <String, dynamic>{...categories};
  for (final entry
      in <String, int>{'mate1': 1, 'mate2': 2, 'mate3': 3}.entries) {
    next[entry.key] = {
      ...Map<String, dynamic>.from(next[entry.key] as Map? ?? const {}),
      'count': counts[entry.value] ?? 0,
    };
  }
  return next;
}
