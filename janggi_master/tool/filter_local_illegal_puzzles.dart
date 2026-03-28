import 'dart:convert';
import 'dart:io';

class _Options {
  const _Options({
    required this.inputPath,
    required this.reportPath,
    required this.backupPath,
  });

  final String inputPath;
  final String reportPath;
  final String? backupPath;

  static _Options parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';
    var reportPath = 'test_tmp/puzzle_local_legality_report.json';
    String? backupPath;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--report':
          reportPath = args[++i];
          break;
        case '--backup':
          backupPath = args[++i];
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
      reportPath: reportPath,
      backupPath: backupPath,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/filter_local_illegal_puzzles.dart [options]

Options:
  --input <path>   Puzzle catalog JSON (default: assets/puzzles/puzzles.json)
  --report <path>  Local legality report JSON (default: test_tmp/puzzle_local_legality_report.json)
  --backup <path>  Optional backup copy path before filtering
''');
  }
}

void main(List<String> args) {
  final options = _Options.parse(args);

  final inputFile = File(options.inputPath);
  final reportFile = File(options.reportPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${options.inputPath}');
    exit(66);
  }
  if (!reportFile.existsSync()) {
    stderr.writeln('Report file not found: ${options.reportPath}');
    exit(66);
  }

  if (options.backupPath != null) {
    final backupFile = File(options.backupPath!);
    backupFile.parent.createSync(recursive: true);
    inputFile.copySync(backupFile.path);
  }

  final doc = jsonDecode(inputFile.readAsStringSync()) as Map<String, dynamic>;
  final report = jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;

  final invalidIds = (report['invalid'] as List<dynamic>)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .map((item) => item['id'] as String)
      .toSet();

  final puzzles = List<Map<String, dynamic>>.from(
    (doc['puzzles'] as List<dynamic>).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );

  final filtered = puzzles.where((puzzle) => !invalidIds.contains(puzzle['id'])).toList();

  final counts = <int, int>{1: 0, 2: 0, 3: 0};
  for (final puzzle in filtered) {
    final mateIn = puzzle['mateIn'] as int;
    counts[mateIn] = (counts[mateIn] ?? 0) + 1;
  }

  doc['generated'] = DateTime.now().toIso8601String();
  doc['version'] = '1.2-strict-local-legal';
  doc['total'] = filtered.length;
  doc['puzzles'] = filtered;

  final categories = Map<String, dynamic>.from(doc['categories'] as Map<String, dynamic>);
  if (categories['mate1'] is Map<String, dynamic>) {
    categories['mate1'] = {
      ...Map<String, dynamic>.from(categories['mate1'] as Map),
      'count': counts[1] ?? 0,
    };
  }
  if (categories['mate2'] is Map<String, dynamic>) {
    categories['mate2'] = {
      ...Map<String, dynamic>.from(categories['mate2'] as Map),
      'count': counts[2] ?? 0,
    };
  }
  if (categories['mate3'] is Map<String, dynamic>) {
    categories['mate3'] = {
      ...Map<String, dynamic>.from(categories['mate3'] as Map),
      'count': counts[3] ?? 0,
    };
  }
  doc['categories'] = categories;

  inputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(doc),
  );

  stdout.writeln(jsonEncode({
    'removed': invalidIds.length,
    'remaining': filtered.length,
    'mate1': counts[1] ?? 0,
    'mate2': counts[2] ?? 0,
    'mate3': counts[3] ?? 0,
  }));
}
