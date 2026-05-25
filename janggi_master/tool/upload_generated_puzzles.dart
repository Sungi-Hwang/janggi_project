import 'dart:convert';
import 'dart:io';

import 'package:janggi_master/utils/generated_puzzle_quality_guard.dart';

Future<void> main(List<String> args) async {
  final options = _UploadOptions.parse(args);
  final document = await _readJson(options.inputPath);
  final puzzles = _extractRows(
    document,
    publish: options.publish,
    status: options.status,
    qualityScore: options.qualityScore,
    requiredMateIn: options.requiredMateIn,
  );

  if (puzzles.isEmpty) {
    stderr.writeln(
        'No valid ${options.requiredMateIn}-move generated puzzles found.');
    exit(65);
  }

  if (options.dryRun) {
    stdout.writeln(jsonEncode(_summary(puzzles)));
    return;
  }

  final url = Platform.environment['SUPABASE_URL'];
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || url.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL.');
    exit(64);
  }
  if (serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln('Missing SUPABASE_SERVICE_ROLE_KEY.');
    exit(64);
  }

  await _uploadRows(
    supabaseUrl: url,
    serviceKey: serviceKey,
    rows: puzzles,
  );
  stdout.writeln(jsonEncode(_summary(puzzles)));
}

class _UploadOptions {
  const _UploadOptions({
    required this.inputPath,
    required this.status,
    required this.publish,
    required this.dryRun,
    required this.qualityScore,
    required this.requiredMateIn,
  });

  final String inputPath;
  final String status;
  final bool publish;
  final bool dryRun;
  final double qualityScore;
  final int requiredMateIn;

  static _UploadOptions parse(List<String> args) {
    var inputPath = 'dev/test_tmp/selfplay_puzzles.json';
    var status = 'draft';
    var publish = false;
    var dryRun = false;
    var qualityScore = 0.7;
    var requiredMateIn = 3;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--input':
          inputPath = args[++i];
          break;
        case '--status':
          status = args[++i];
          break;
        case '--publish':
          publish = true;
          status = 'published';
          break;
        case '--dry-run':
          dryRun = true;
          break;
        case '--quality-score':
          qualityScore = double.parse(args[++i]);
          break;
        case '--require-mate-in':
          requiredMateIn = int.parse(args[++i]);
          if (requiredMateIn < 1 || requiredMateIn > 3) {
            stderr.writeln('--require-mate-in must be 1, 2, or 3.');
            exit(64);
          }
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

    if (!const {'draft', 'published', 'rejected'}.contains(status)) {
      stderr.writeln('--status must be draft, published, or rejected.');
      exit(64);
    }

    return _UploadOptions(
      inputPath: inputPath,
      status: status,
      publish: publish,
      dryRun: dryRun,
      qualityScore: qualityScore,
      requiredMateIn: requiredMateIn,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/upload_generated_puzzles.dart [options]

Options:
  --input <path>          Self-play generator JSON
  --status <status>      draft, published, or rejected (default: draft)
  --publish              Shortcut for --status published and sets published_at
  --quality-score <n>    Default quality score for uploaded rows (default: 0.7)
  --require-mate-in <n>  Only upload this mate length (default: 3)
  --dry-run              Validate and print summary without uploading

Environment:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
''');
  }
}

Future<Map<String, dynamic>> _readJson(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('Input file not found', path);
  }
  final decoded = json.decode(await file.readAsString());
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> _extractRows(
  Map<String, dynamic> document, {
  required bool publish,
  required String status,
  required double qualityScore,
  required int requiredMateIn,
}) {
  final rawPuzzles = document['puzzles'];
  if (rawPuzzles is! List) {
    throw const FormatException('Expected a puzzles array.');
  }

  final now = DateTime.now().toUtc().toIso8601String();
  final seenFen = <String>{};
  final rows = <Map<String, dynamic>>[];
  for (final raw in rawPuzzles.whereType<Map>()) {
    final puzzle = Map<String, dynamic>.from(raw);
    final mateIn = (puzzle['mateIn'] as num?)?.toInt();
    final fen = puzzle['fen'] as String?;
    final solution = puzzle['solution'];
    if (mateIn == null || mateIn != requiredMateIn) continue;
    final requiredLength = mateIn * 2 - 1;
    if (fen == null || fen.trim().isEmpty) continue;
    if (solution is! List || solution.length != requiredLength) continue;
    if (!seenFen.add(_fenKey(fen))) continue;
    final toMove = puzzle['toMove'] ?? _sideFromFen(fen);
    if (GeneratedPuzzleQualityGuard.hasImmediateGeneralCapture(
      fen: fen,
      toMove: toMove as String?,
    )) {
      continue;
    }

    rows.add(<String, dynamic>{
      'id': _stableGeneratedId(fen),
      'fen': fen,
      'solution': List<String>.from(solution),
      'mate_in': mateIn,
      'to_move': toMove,
      'title': puzzle['title'] ?? '생성 묘수',
      'source': puzzle['source'] ?? 'self_play',
      'quality_score':
          (puzzle['qualityScore'] as num?)?.toDouble() ?? qualityScore,
      'generator': puzzle['generator'] ?? <String, dynamic>{},
      'status': status,
      'published_at': publish || status == 'published' ? now : null,
    });
  }
  return rows;
}

Future<void> _uploadRows({
  required String supabaseUrl,
  required String serviceKey,
  required List<Map<String, dynamic>> rows,
}) async {
  final client = HttpClient();
  try {
    for (var start = 0; start < rows.length; start += 100) {
      final batch = rows.skip(start).take(100).toList(growable: false);
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/generated_puzzles?on_conflict=id',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set('apikey', serviceKey);
      request.headers.set('Authorization', 'Bearer $serviceKey');
      request.headers.set(
        'Prefer',
        'resolution=merge-duplicates,return=minimal',
      );
      request.write(json.encode(batch));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Upload failed (${response.statusCode}): $body',
          uri: uri,
        );
      }
    }
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _summary(List<Map<String, dynamic>> rows) {
  final mate2 = rows.where((row) => row['mate_in'] == 2).length;
  final mate3 = rows.where((row) => row['mate_in'] == 3).length;
  final total = rows.length;
  return <String, dynamic>{
    'valid': total,
    'mate2': mate2,
    'mate3': mate3,
    'mate3Ratio': total == 0 ? 0 : mate3 / total,
    'containsMate1': false,
    'containsMate2': mate2 > 0,
    'allMate3': total > 0 && mate3 == total,
  };
}

String _stableGeneratedId(String fen) {
  var hash = 0xcbf29ce484222325;
  for (final codeUnit in _fenKey(fen).codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
  }
  return 'gp_${hash.toRadixString(16).padLeft(16, '0')}';
}

String _fenKey(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  if (parts.length < 2) return fen;
  return '${parts[0]} ${parts[1]}';
}

String _sideFromFen(String fen) {
  final parts = fen.split(RegExp(r'\s+'));
  return parts.length > 1 && parts[1] == 'b' ? 'red' : 'blue';
}
