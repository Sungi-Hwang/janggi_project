import 'dart:io';

const defaultOutputPath = r'D:\Project wiki\janggi_master\module_wiki.md';
const outputEnvKey = 'JANGGI_MASTER_WIKI_OUTPUT';
const testHintLabel = 'Direct/name-matched test hints';

const directoryRoles = <String, String>{
  'lib': 'App entry point, root-level orchestration, and engine FFI bridge.',
  'lib/community': 'Community feature flags and Supabase environment gates.',
  'lib/game':
      'Runtime game state, move flow, AI turn orchestration, and rule checks.',
  'lib/models':
      'Core domain objects for board, pieces, moves, puzzles, progress, and rule modes.',
  'lib/monetization': 'Ad and purchase configuration.',
  'lib/providers': 'ChangeNotifier state adapters used by Flutter screens.',
  'lib/screens': 'User-facing flows and page-level UI composition.',
  'lib/services':
      'Persistence, parsing, Supabase, audio, settings, and import services.',
  'lib/theme': 'Board and piece skin values.',
  'lib/utils':
      'Pure helpers for Stockfish conversion, puzzle loading/sharing, and GIB processing.',
  'lib/widgets':
      'Reusable UI pieces for board rendering, ads, captured pieces, previews, and overlays.',
  'tool':
      'One-off and repeatable maintenance tools for puzzle corpus, quality, and seed generation.',
  'test':
      'Regression and unit tests covering engine behavior, puzzles, parsing, services, and widgets.',
};

const improvementQuestions = <String, List<String>>{
  'lib': [
    'Does app startup keep provider wiring, routing, and platform initialization easy to scan?',
    'Is the engine FFI boundary narrow enough that callers do not depend on protocol details?',
  ],
  'lib/game': [
    'Can rule decisions be moved closer to models or engine adapters so GameState stays smaller?',
    'Are async engine calls protected from stale UI state after undo, reset, or navigation?',
  ],
  'lib/models': [
    'Which objects should stay immutable so puzzle import/export and tests can reuse them safely?',
    'Are JSON keys centralized enough to avoid schema drift between local, shared, and community puzzles?',
  ],
  'lib/screens': [
    'Which screen-local helpers are reusable widgets or services in disguise?',
    'Can long screens be split by workflow step without changing navigation behavior?',
  ],
  'lib/services': [
    'Do service methods expose domain-level errors instead of raw plugin/database failures?',
    'Are remote schema fallbacks temporary, documented, and covered by tests?',
  ],
  'lib/utils': [
    'Are conversion/parsing functions pure enough to test without Flutter bindings?',
    'Can shared coordinate, notation, and FEN logic be consolidated?',
  ],
  'lib/widgets': [
    'Can board rendering stay presentation-only while move legality remains in game/model layers?',
    'Are widget dimensions stable across desktop and mobile sizes?',
  ],
  'tool': [
    'Which scripts are part of the release pipeline and deserve docs or tests?',
    'Can duplicated puzzle-validation logic be promoted into lib utilities?',
  ],
  'test': [
    'Which high-risk modules have no direct regression test yet?',
    'Are test names grouped by feature so wiki links reveal coverage gaps quickly?',
  ],
};

void main(List<String> args) {
  final root = Directory.current;
  final outputPath = _resolveOutputPath(args);
  final sourceFiles = _collectSourceFiles(root);
  final modules = sourceFiles
      .map((file) => ModuleInfo.fromFile(root, file))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final tests =
      modules.where((module) => module.path.startsWith('test/')).toList();

  final buffer = StringBuffer()
    ..writeln('# Janggi Master Module Wiki')
    ..writeln()
    ..writeln(
        'Generated from source by `dart run tool/generate_module_wiki.dart`.')
    ..writeln(
        'Use this as a lightweight LLM wiki: each module keeps role, symbols, dependency hints, test hints, and review questions close together.')
    ..writeln()
    ..writeln('## How to use this wiki')
    ..writeln()
    ..writeln(
        '- When changing a feature, start from the directory section, then follow the imported local files.')
    ..writeln(
        '- When looking for reuse, search the public symbols table before adding a new helper.')
    ..writeln(
        '- When looking for improvements, start with hotspots and files without direct/name-matched test hints.')
    ..writeln(
        '- Regenerate this file after structural changes so the map stays honest.')
    ..writeln()
    ..writeln(
        'Note: test hints are not coverage proof. They only show tests that directly import a module or whose file name matches the module stem.')
    ..writeln()
    ..writeln('## System Map')
    ..writeln()
    ..writeln('| Area | Role | Files | Public symbols | $testHintLabel |')
    ..writeln('| --- | --- | ---: | ---: | ---: |');

  for (final entry in directoryRoles.entries) {
    final areaModules = _areaModules(modules, entry.key);
    if (areaModules.isEmpty) {
      continue;
    }
    final linkedTests = areaModules
        .expand((module) => _linkedTests(module, tests))
        .toSet()
        .length;
    final symbolCount =
        areaModules.fold<int>(0, (sum, module) => sum + module.symbols.length);
    buffer.writeln(
        '| `${entry.key}` | ${entry.value} | ${areaModules.length} | $symbolCount | $linkedTests |');
  }

  buffer
    ..writeln()
    ..writeln('## Improvement Hotspots')
    ..writeln()
    ..writeln(
        '| File | Why it matters | Lines | Public symbols | Local imports | $testHintLabel |')
    ..writeln('| --- | --- | ---: | ---: | ---: | --- |');

  final hotspots = modules
      .where((module) => !module.path.startsWith('test/'))
      .toList()
    ..sort((a, b) => b.hotspotScore.compareTo(a.hotspotScore));
  for (final module in hotspots.take(12)) {
    final linked = _linkedTests(module, tests)
        .map((test) => '`${test.path}`')
        .join('<br>');
    buffer.writeln(
      '| `${module.path}` | ${_hotspotReason(module)} | ${module.lineCount} | ${module.symbols.length} | ${module.localImports.length} | ${linked.isEmpty ? 'No direct hint' : linked} |',
    );
  }

  for (final entry in directoryRoles.entries) {
    final areaModules = _areaModules(modules, entry.key);
    if (areaModules.isEmpty) {
      continue;
    }
    buffer
      ..writeln()
      ..writeln('## ${entry.key}')
      ..writeln()
      ..writeln(entry.value)
      ..writeln()
      ..writeln('Review questions:')
      ..writeln();
    for (final question in improvementQuestions[entry.key] ??
        const <String>['Is ownership clear enough for the next change?']) {
      buffer.writeln('- $question');
    }
    buffer
      ..writeln()
      ..writeln('| File | Public symbols | Local imports | $testHintLabel |')
      ..writeln('| --- | --- | --- | --- |');
    for (final module in areaModules) {
      final symbols = module.symbols.isEmpty
          ? 'None'
          : module.symbols.map((symbol) => '`$symbol`').join('<br>');
      final imports = module.localImports.isEmpty
          ? 'None'
          : module.localImports.map((import) => '`$import`').join('<br>');
      final linked = _linkedTests(module, tests)
          .map((test) => '`${test.path}`')
          .join('<br>');
      buffer.writeln(
          '| `${module.path}` | $symbols | $imports | ${linked.isEmpty ? 'No direct hint' : linked} |');
    }
  }

  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote $outputPath with ${modules.length} modules.');
}

String _resolveOutputPath(List<String> args) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == '--output' || arg == '-o') {
      if (index + 1 >= args.length) {
        _failUsage('Missing path after $arg.');
      }
      return args[index + 1];
    }
    if (arg.startsWith('--output=')) {
      final value = arg.substring('--output='.length).trim();
      if (value.isEmpty) {
        _failUsage('Missing path after --output=.');
      }
      return value;
    }
    if (arg == '--help' || arg == '-h') {
      stdout.writeln(
          'Usage: dart run tool/generate_module_wiki.dart [--output <path>]');
      stdout.writeln('Environment fallback: $outputEnvKey');
      stdout.writeln('Default output: $defaultOutputPath');
      exit(0);
    }
  }

  final envOutput = Platform.environment[outputEnvKey]?.trim();
  if (envOutput != null && envOutput.isNotEmpty) {
    return envOutput;
  }
  return defaultOutputPath;
}

Never _failUsage(String message) {
  stderr.writeln(message);
  stderr.writeln(
      'Usage: dart run tool/generate_module_wiki.dart [--output <path>]');
  exit(64);
}

List<File> _collectSourceFiles(Directory root) {
  final files = <File>[];
  for (final topLevel in ['lib', 'tool', 'test']) {
    final directory =
        Directory('${root.path}${Platform.pathSeparator}$topLevel');
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }
  return files;
}

bool _belongsTo(String path, String area) =>
    path == area || path.startsWith('$area/');

List<ModuleInfo> _areaModules(List<ModuleInfo> modules, String area) {
  if (area == 'lib') {
    return modules
        .where((module) =>
            module.path.startsWith('lib/') &&
            module.path.split('/').length == 2)
        .toList();
  }
  return modules.where((module) => _belongsTo(module.path, area)).toList();
}

List<ModuleInfo> _linkedTests(ModuleInfo module, List<ModuleInfo> tests) {
  if (module.path.startsWith('test/')) {
    return const [];
  }
  final stem = module.fileStem;
  return tests
      .where((test) =>
          test.importTargets.contains(module.path) ||
          (stem.length >= 8 && test.fileStem.contains(stem)))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _hotspotReason(ModuleInfo module) {
  final reasons = <String>[];
  if (module.lineCount >= 500) {
    reasons.add('large file');
  }
  if (module.symbols.length >= 4) {
    reasons.add('many public symbols');
  }
  if (module.localImports.length >= 8) {
    reasons.add('many local imports');
  }
  if (reasons.isEmpty) {
    reasons.add('central dependency');
  }
  return reasons.join(', ');
}

class ModuleInfo {
  ModuleInfo({
    required this.path,
    required this.lineCount,
    required this.symbols,
    required this.localImports,
    required this.importTargets,
  });

  factory ModuleInfo.fromFile(Directory root, File file) {
    final text = file.readAsStringSync();
    final relativePath = file.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    final symbols = <String>[];
    final symbolPattern = RegExp(
        r'^(?:class|enum|mixin|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)|^extension\s+([A-Za-z_][A-Za-z0-9_]*)\s+on\s+',
        multiLine: true);
    for (final match in symbolPattern.allMatches(text)) {
      final name = match.group(1) ?? match.group(2)!;
      if (!name.startsWith('_')) {
        symbols.add(name);
      }
    }
    final imports = <String>[];
    final importTargets = <String>{};
    final importPattern = RegExp(r"^import\s+'([^']+)';", multiLine: true);
    for (final match in importPattern.allMatches(text)) {
      final import = match.group(1)!;
      if (import.startsWith('../') ||
          import.startsWith('./') ||
          !import.contains(':')) {
        imports.add(import);
      }
      final target = _resolveImportTarget(relativePath, import);
      if (target != null) {
        importTargets.add(target);
      }
    }
    return ModuleInfo(
      path: relativePath,
      lineCount: '\n'.allMatches(text).length + 1,
      symbols: symbols,
      localImports: imports,
      importTargets: importTargets,
    );
  }

  final String path;
  final int lineCount;
  final List<String> symbols;
  final List<String> localImports;
  final Set<String> importTargets;

  int get hotspotScore =>
      lineCount + symbols.length * 35 + localImports.length * 20;

  String get fileStem => path.split('/').last.replaceFirst('.dart', '');
}

String? _resolveImportTarget(String fromPath, String import) {
  if (import.startsWith('package:janggi_master/')) {
    return 'lib/${import.substring('package:janggi_master/'.length)}';
  }
  if (import.startsWith('package:') || import.startsWith('dart:')) {
    return null;
  }
  final parts = fromPath.split('/')..removeLast();
  for (final part in import.split('/')) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (parts.isNotEmpty) {
        parts.removeLast();
      }
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}
