import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _ImportOptions.parse(args);
  final registry = _SourceRegistry.defaults();
  final source = registry.sources[options.source];
  if (source == null) {
    stderr.writeln('Unknown source: ${options.source}');
    exit(64);
  }

  final decision = _decide(source, options);
  final report = <String, dynamic>{
    'generated': DateTime.now().toUtc().toIso8601String(),
    'source': source.name,
    'licenseStatus': options.licenseStatus,
    'input': options.input,
    'format': options.format,
    'dryRun': options.dryRun,
    'allowed': decision.allowed,
    'action': decision.action,
    'reason': decision.reason,
    'registry': source.toJson(),
  };

  _writeJson(options.outputPath, report);
  stdout.writeln(jsonEncode(report));

  if (!decision.allowed) return;
  if (options.dryRun) return;

  stderr.writeln(
    'Import execution is intentionally not implemented yet. '
    'Add a source-specific adapter after license and API permission are clear.',
  );
  exit(78);
}

_ImportDecision _decide(_ExternalSource source, _ImportOptions options) {
  if (options.input == null || options.input!.trim().isEmpty) {
    return const _ImportDecision(
      allowed: false,
      action: 'report_only',
      reason: '--input is required for every external import candidate.',
    );
  }

  if (source.name == 'user_provided_gib') {
    final file = File(options.input!);
    if (!file.existsSync()) {
      return const _ImportDecision(
        allowed: false,
        action: 'report_only',
        reason: 'User-provided GIB input must be a local existing file.',
      );
    }
    if (options.licenseStatus != 'user_provided' &&
        options.licenseStatus != 'allowed') {
      return const _ImportDecision(
        allowed: false,
        action: 'report_only',
        reason: 'User-provided files require --license-status user_provided.',
      );
    }
    return const _ImportDecision(
      allowed: true,
      action: 'adapter_required',
      reason: 'Local user-provided file is eligible for a GIB adapter.',
    );
  }

  if (!source.enabledByDefault) {
    return _ImportDecision(
      allowed: false,
      action: 'report_only',
      reason:
          '${source.name} is disabled until an explicit license or written permission is recorded.',
    );
  }

  if (source.requiresPermission && options.licenseStatus != 'allowed') {
    return _ImportDecision(
      allowed: false,
      action: 'report_only',
      reason:
          '${source.name} requires confirmed API terms or operator permission before import.',
    );
  }

  return _ImportDecision(
    allowed: source.allowedUse == 'self_play',
    action: source.allowedUse == 'self_play' ? 'not_external' : 'report_only',
    reason: source.allowedUse == 'self_play'
        ? 'Self-play is generated in-house and does not need external import.'
        : 'A source-specific adapter is required before importing.',
  );
}

class _ImportOptions {
  const _ImportOptions({
    required this.source,
    required this.licenseStatus,
    required this.format,
    required this.outputPath,
    required this.dryRun,
    this.input,
  });

  final String source;
  final String licenseStatus;
  final String format;
  final String outputPath;
  final bool dryRun;
  final String? input;

  static _ImportOptions parse(List<String> args) {
    var source = 'self_play';
    var licenseStatus = 'unknown';
    var format = 'unknown';
    var outputPath = 'dev/external_janggi_sources_report.json';
    var dryRun = true;
    String? input;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--source':
          source = args[++i];
          break;
        case '--license-status':
          licenseStatus = args[++i];
          break;
        case '--input':
          input = args[++i];
          break;
        case '--format':
          format = args[++i];
          break;
        case '--output':
          outputPath = args[++i];
          break;
        case '--dry-run':
          dryRun = true;
          break;
        case '--execute':
          dryRun = false;
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

    if (!const {
      'unknown',
      'permission_required',
      'allowed',
      'user_provided',
    }.contains(licenseStatus)) {
      stderr.writeln(
        '--license-status must be unknown, permission_required, allowed, or user_provided.',
      );
      exit(64);
    }

    return _ImportOptions(
      source: source,
      licenseStatus: licenseStatus,
      input: input,
      format: format,
      outputPath: outputPath,
      dryRun: dryRun,
    );
  }

  static void _printUsage() {
    stdout.writeln('''
Usage: dart run tool/import_external_janggi_games.dart [options]

Options:
  --source <name>          self_play, pychess_public, user_provided_gib,
                           janggi_org, kja, or braintv
  --license-status <name>  unknown, permission_required, allowed, user_provided
  --input <url_or_path>    Required candidate URL or local file path
  --format <name>          pychess-json, gib, pgn, or unknown
  --output <path>          Report JSON path
  --dry-run                Report only (default)
  --execute                Attempt import. Currently only reports blocked status
                           unless a source adapter is added.
''');
  }
}

class _SourceRegistry {
  const _SourceRegistry(this.sources);

  final Map<String, _ExternalSource> sources;

  factory _SourceRegistry.defaults() {
    return const _SourceRegistry(<String, _ExternalSource>{
      'self_play': _ExternalSource(
        name: 'self_play',
        enabledByDefault: true,
        requiresPermission: false,
        allowedUse: 'self_play',
        note: 'In-house weak-vs-strong self-play generation.',
      ),
      'pychess_public': _ExternalSource(
        name: 'pychess_public',
        enabledByDefault: true,
        requiresPermission: true,
        allowedUse: 'permissioned_api_only',
        note:
            'PyChess supports Janggi, but bulk archive use needs clear API terms or operator permission.',
      ),
      'user_provided_gib': _ExternalSource(
        name: 'user_provided_gib',
        enabledByDefault: true,
        requiresPermission: false,
        allowedUse: 'user_provided_file',
        note: 'Only local files explicitly provided by the user.',
      ),
      'janggi_org': _ExternalSource(
        name: 'janggi_org',
        enabledByDefault: false,
        requiresPermission: true,
        allowedUse: 'disabled_until_permission',
        note: 'Visible game records are not enough; license must be explicit.',
      ),
      'kja': _ExternalSource(
        name: 'kja',
        enabledByDefault: false,
        requiresPermission: true,
        allowedUse: 'disabled_until_permission',
        note: 'Korean Janggi Association records require explicit permission.',
      ),
      'braintv': _ExternalSource(
        name: 'braintv',
        enabledByDefault: false,
        requiresPermission: true,
        allowedUse: 'disabled_until_permission',
        note: 'Broadcast records require explicit reuse permission.',
      ),
    });
  }
}

class _ExternalSource {
  const _ExternalSource({
    required this.name,
    required this.enabledByDefault,
    required this.requiresPermission,
    required this.allowedUse,
    required this.note,
  });

  final String name;
  final bool enabledByDefault;
  final bool requiresPermission;
  final String allowedUse;
  final String note;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'enabledByDefault': enabledByDefault,
      'requiresPermission': requiresPermission,
      'allowedUse': allowedUse,
      'note': note,
    };
  }
}

class _ImportDecision {
  const _ImportDecision({
    required this.allowed,
    required this.action,
    required this.reason,
  });

  final bool allowed;
  final String action;
  final String reason;
}

void _writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}
