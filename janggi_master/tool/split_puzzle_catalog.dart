import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final options = _SplitOptions.parse(args);

  final input = _readJson(options.inputPath);
  final report = _readJson(options.reportPath);

  final puzzles = List<Map<String, dynamic>>.from(
    (input['puzzles'] as List<dynamic>).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );
  final details = List<Map<String, dynamic>>.from(
    (report['details'] as List<dynamic>).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );

  final detailById = {
    for (final detail in details) detail['id'] as String: detail,
  };

  final strict = <Map<String, dynamic>>[];
  final relaxed = <Map<String, dynamic>>[];
  final quarantine = <Map<String, dynamic>>[];

  for (final puzzle in puzzles) {
    final id = puzzle['id'] as String;
    final detail = detailById[id];
    final withValidation = <String, dynamic>{
      ...puzzle,
      if (detail != null)
        'validation': Map<String, dynamic>.from(
          detail['validation'] as Map? ?? const <String, dynamic>{},
        ),
    };

    if (detail?['strictPass'] == true) {
      strict.add(withValidation);
    } else if (detail?['relaxedPass'] == true) {
      relaxed.add(withValidation);
    } else {
      quarantine.add(withValidation);
    }
  }

  final summary = Map<String, dynamic>.from(
    report['summary'] as Map? ?? const <String, dynamic>{},
  );

  _writeCatalog(
    base: input,
    puzzles: strict,
    outputPath: options.strictOutputPath,
    versionSuffix: 'beta-strict',
    validationSummary: summary,
    bucket: 'strict',
  );
  _writeCatalog(
    base: input,
    puzzles: relaxed,
    outputPath: options.relaxedOutputPath,
    versionSuffix: 'beta-relaxed',
    validationSummary: summary,
    bucket: 'relaxed',
  );
  _writeCatalog(
    base: input,
    puzzles: quarantine,
    outputPath: options.quarantineOutputPath,
    versionSuffix: 'beta-quarantine',
    validationSummary: summary,
    bucket: 'quarantine',
  );

  if (options.replaceInput) {
    _writeCatalog(
      base: input,
      puzzles: strict,
      outputPath: options.inputPath,
      versionSuffix: 'beta-strict',
      validationSummary: summary,
      bucket: 'strict',
    );
  }

  stdout.writeln(jsonEncode({
    'strict': strict.length,
    'relaxed': relaxed.length,
    'quarantine': quarantine.length,
    'replacedInput': options.replaceInput,
  }));
}

class _SplitOptions {
  _SplitOptions({
    required this.inputPath,
    required this.reportPath,
    required this.strictOutputPath,
    required this.relaxedOutputPath,
    required this.quarantineOutputPath,
    required this.replaceInput,
  });

  final String inputPath;
  final String reportPath;
  final String strictOutputPath;
  final String relaxedOutputPath;
  final String quarantineOutputPath;
  final bool replaceInput;

  static _SplitOptions parse(List<String> args) {
    var inputPath = 'assets/puzzles/puzzles.json';
    var reportPath = 'test_tmp/puzzle_quality_validation_full_d8_m3.json';
    var strictOutputPath = 'assets/puzzles/puzzles_strict.json';
    var relaxedOutputPath = 'assets/puzzles/puzzles_relaxed.json';
    var quarantineOutputPath = 'assets/puzzles/puzzles_quarantine.json';
    var replaceInput = false;

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
        case '--relaxed-output':
          relaxedOutputPath = args[++i];
          break;
        case '--quarantine-output':
          quarantineOutputPath = args[++i];
          break;
        case '--replace-input':
          replaceInput = true;
          break;
        case '--help':
        case '-h':
          stdout.writeln('''
Usage: dart run tool/split_puzzle_catalog.dart [options]

Options:
  --input <path>               Source puzzle catalog
  --report <path>              Validation report JSON
  --strict-output <path>       Strict catalog output
  --relaxed-output <path>      Relaxed catalog output
  --quarantine-output <path>   Quarantine catalog output
  --replace-input              Replace the source catalog with strict output
''');
          exit(0);
        default:
          stderr.writeln('Unknown argument: ${args[i]}');
          exit(64);
      }
    }

    return _SplitOptions(
      inputPath: inputPath,
      reportPath: reportPath,
      strictOutputPath: strictOutputPath,
      relaxedOutputPath: relaxedOutputPath,
      quarantineOutputPath: quarantineOutputPath,
      replaceInput: replaceInput,
    );
  }
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('JSON file not found', path);
  }
  final raw = file.readAsStringSync(encoding: utf8);
  final normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  return Map<String, dynamic>.from(jsonDecode(normalized) as Map);
}

void _writeCatalog({
  required Map<String, dynamic> base,
  required List<Map<String, dynamic>> puzzles,
  required String outputPath,
  required String versionSuffix,
  required Map<String, dynamic> validationSummary,
  required String bucket,
}) {
  final next = <String, dynamic>{...base};
  next['version'] = '${base['version'] ?? '1.1'}-$versionSuffix';
  next['generated'] = DateTime.now().toIso8601String();
  next['total'] = puzzles.length;
  next['categories'] = _buildCategories(
    Map<String, dynamic>.from(base['categories'] as Map? ?? const {}),
    puzzles,
  );
  next['validationSummary'] = {
    ...validationSummary,
    'bucket': bucket,
    'bucketCount': puzzles.length,
  };
  next['puzzles'] = puzzles;

  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(next)}\n', encoding: utf8);
}

Map<String, dynamic> _buildCategories(
  Map<String, dynamic> baseCategories,
  List<Map<String, dynamic>> puzzles,
) {
  final counts = <String, int>{
    'mate1': 0,
    'mate2': 0,
    'mate3': 0,
  };

  for (final puzzle in puzzles) {
    final mateIn = puzzle['mateIn'];
    if (mateIn is int && mateIn >= 1 && mateIn <= 3) {
      counts['mate$mateIn'] = (counts['mate$mateIn'] ?? 0) + 1;
    }
  }

  return {
    for (final entry in counts.entries)
      entry.key: {
        ...Map<String, dynamic>.from(
          baseCategories[entry.key] as Map? ?? const <String, dynamic>{},
        ),
        'count': entry.value,
      },
  };
}
