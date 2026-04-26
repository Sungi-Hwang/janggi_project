import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final options = _Options.parse(args);

  final inputFile = File(options.inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: ${options.inputPath}');
    exitCode = 2;
    return;
  }

  final input = jsonDecode(inputFile.readAsStringSync()) as Map<String, dynamic>;
  final puzzles = ((input['puzzles'] as List?) ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .toList();

  final reportFile = File(options.reportPath);
  final strictPreviewFile = File(options.strictOutputPath);
  reportFile.parent.createSync(recursive: true);
  strictPreviewFile.parent.createSync(recursive: true);

  final existingReport = reportFile.existsSync()
      ? (jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};
  final existingResults = <String, Map<String, dynamic>>{};
  for (final item in (existingReport['results'] as List?) ?? const <dynamic>[]) {
    if (item is Map<String, dynamic>) {
      final id = item['id']?.toString();
      if (id != null) {
        existingResults[id] = item;
      }
    }
  }

  final startedAt = DateTime.now().toUtc().toIso8601String();
  final total = puzzles.length;
  var processed = 0;

  for (final puzzle in puzzles) {
    final id = puzzle['id']?.toString();
    if (id == null || id.isEmpty) {
      continue;
    }
    if (existingResults.containsKey(id)) {
      processed++;
      continue;
    }

    stdout.writeln('[$processed/$total] validating $id...');
    final result = await Process.run(
      'dart',
      <String>[
        'run',
        'tool/puzzle_quality_validator.dart',
        '--worker',
        '--input',
        options.inputPath,
        '--id',
        id,
        '--depth',
        options.depth.toString(),
        '--multipv',
        options.multiPv.toString(),
        '--engine',
        options.enginePath,
      ],
      workingDirectory: options.workingDirectory,
    );

    if (result.exitCode != 0) {
      stderr.writeln('Validation failed for $id');
      stderr.writeln(result.stderr);
      existingResults[id] = <String, dynamic>{
        'id': id,
        'strictPass': false,
        'relaxedPass': false,
        'error': 'worker_exit_${result.exitCode}',
        'stderr': result.stderr.toString(),
      };
    } else {
      final stdoutText = result.stdout.toString().trim();
      final jsonLine = stdoutText
          .split(RegExp(r'[\r\n]+'))
          .map((line) => line.trim())
          .where((line) => line.startsWith('{') && line.endsWith('}'))
          .last;
      existingResults[id] = jsonDecode(jsonLine) as Map<String, dynamic>;
    }

    processed++;
    _writeOutputs(
      input: input,
      puzzles: puzzles,
      results: existingResults,
      reportFile: reportFile,
      strictPreviewFile: strictPreviewFile,
      startedAt: startedAt,
      options: options,
    );
  }

  _writeOutputs(
    input: input,
    puzzles: puzzles,
    results: existingResults,
    reportFile: reportFile,
    strictPreviewFile: strictPreviewFile,
    startedAt: startedAt,
    options: options,
  );

  stdout.writeln('Resumable report written to ${reportFile.path}');
  stdout.writeln('Strict preview written to ${strictPreviewFile.path}');
}

void _writeOutputs({
  required Map<String, dynamic> input,
  required List<Map<String, dynamic>> puzzles,
  required Map<String, Map<String, dynamic>> results,
  required File reportFile,
  required File strictPreviewFile,
  required String startedAt,
  required _Options options,
}) {
  final orderedResults = <Map<String, dynamic>>[];
  for (final puzzle in puzzles) {
    final id = puzzle['id']?.toString();
    if (id != null && results.containsKey(id)) {
      orderedResults.add(results[id]!);
    }
  }

  final strictIds = orderedResults
      .where((r) => r['strictPass'] == true)
      .map((r) => r['id']?.toString())
      .whereType<String>()
      .toSet();
  final strictPuzzles = puzzles
      .where((p) => strictIds.contains(p['id']?.toString()))
      .toList();

  final report = <String, dynamic>{
    'input': options.inputPath,
    'engine': options.enginePath,
    'generated': startedAt,
    'depth': options.depth,
    'multipv': options.multiPv,
    'processed': orderedResults.length,
    'total': puzzles.length,
    'summary': <String, dynamic>{
      'strictPass': orderedResults.where((r) => r['strictPass'] == true).length,
      'relaxedPass':
          orderedResults.where((r) => r['relaxedPass'] == true).length,
      'branchUnique':
          orderedResults.where((r) => r['branchUnique'] == true).length,
    },
    'results': orderedResults,
  };
  _writeJson(reportFile, report);

  final strictDoc = Map<String, dynamic>.from(input);
  strictDoc['generated'] = DateTime.now().toUtc().toIso8601String();
  strictDoc['total'] = strictPuzzles.length;
  strictDoc['puzzles'] = strictPuzzles;
  strictDoc['validationSummary'] = report['summary'];
  _writeJson(strictPreviewFile, strictDoc);
}

void _writeJson(File file, Object data) {
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}

class _Options {
  _Options({
    required this.inputPath,
    required this.reportPath,
    required this.strictOutputPath,
    required this.depth,
    required this.multiPv,
    required this.enginePath,
    required this.workingDirectory,
  });

  final String inputPath;
  final String reportPath;
  final String strictOutputPath;
  final int depth;
  final int multiPv;
  final String enginePath;
  final String workingDirectory;

  static _Options parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';
    var reportPath = 'dev/test_tmp/puzzle_quality_resumable_report.json';
    var strictOutputPath = 'dev/test_tmp/puzzles_resumable_strict_preview.json';
    var depth = 12;
    var multiPv = 8;
    var enginePath = Platform.isWindows
        ? 'engine/src/stockfish.exe'
        : 'engine/src/stockfish';

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--report':
          reportPath = args[++i];
          break;
        case '--strict-output':
          strictOutputPath = args[++i];
          break;
        case '--depth':
          depth = int.parse(args[++i]);
          break;
        case '--multipv':
          multiPv = int.parse(args[++i]);
          break;
        case '--engine':
          enginePath = args[++i];
          break;
      }
    }

    return _Options(
      inputPath: inputPath,
      reportPath: reportPath,
      strictOutputPath: strictOutputPath,
      depth: depth,
      multiPv: multiPv,
      enginePath: enginePath,
      workingDirectory: Directory.current.path,
    );
  }
}
