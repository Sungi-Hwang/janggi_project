import 'dart:convert';
import 'dart:io';

class GibCorpusPaths {
  GibCorpusPaths({
    required this.root,
    required this.rawRoot,
    required this.kjaRawRoot,
    required this.manualDropDir,
    required this.normalizedDir,
    required this.manifestDir,
  });

  final Directory root;
  final Directory rawRoot;
  final Directory kjaRawRoot;
  final Directory manualDropDir;
  final Directory normalizedDir;
  final Directory manifestDir;

  void ensureExists() {
    root.createSync(recursive: true);
    rawRoot.createSync(recursive: true);
    kjaRawRoot.createSync(recursive: true);
    manualDropDir.createSync(recursive: true);
    normalizedDir.createSync(recursive: true);
    manifestDir.createSync(recursive: true);
  }
}

class KjaPdsPostSummary {
  const KjaPdsPostSummary({
    required this.id,
    required this.title,
    required this.postedDate,
    required this.viewUrl,
  });

  final int id;
  final String title;
  final String postedDate;
  final String viewUrl;
}

class KjaPdsAttachment {
  const KjaPdsAttachment({
    required this.fileName,
    required this.downloadUrl,
    required this.postTitle,
    required this.postedDate,
    required this.viewUrl,
  });

  final String fileName;
  final String downloadUrl;
  final String postTitle;
  final String postedDate;
  final String viewUrl;
}

class KjaPdsPostPage {
  const KjaPdsPostPage({
    required this.title,
    required this.postedDate,
    required this.viewUrl,
    required this.attachments,
  });

  final String title;
  final String postedDate;
  final String viewUrl;
  final List<KjaPdsAttachment> attachments;
}

String resolveCorpusRoot([String? explicitRoot]) {
  final envRoot = Platform.environment['JANGGI_GIB_ROOT'];
  final root = (explicitRoot != null && explicitRoot.trim().isNotEmpty)
      ? explicitRoot.trim()
      : ((envRoot != null && envRoot.trim().isNotEmpty)
          ? envRoot.trim()
          : _defaultCorpusRoot());
  return root;
}

GibCorpusPaths resolveCorpusPaths({
  String? rootPath,
  String? manualDirOverride,
}) {
  final root = Directory(resolveCorpusRoot(rootPath));
  return GibCorpusPaths(
    root: root,
    rawRoot: Directory('${root.path}${Platform.pathSeparator}raw'),
    kjaRawRoot:
        Directory('${root.path}${Platform.pathSeparator}raw${Platform.pathSeparator}kja_pds'),
    manualDropDir: Directory(
      manualDirOverride?.trim().isNotEmpty == true
          ? manualDirOverride!.trim()
          : '${root.path}${Platform.pathSeparator}manual_drop',
    ),
    normalizedDir:
        Directory('${root.path}${Platform.pathSeparator}normalized'),
    manifestDir:
        Directory('${root.path}${Platform.pathSeparator}manifests'),
  );
}

String sanitizeFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'untitled' : cleaned;
}

String htmlUnescape(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#10;', '\n')
      .trim();
}

List<KjaPdsPostSummary> parseKjaPdsListHtml(String html) {
  final posts = <KjaPdsPostSummary>[];
  final rowPattern = RegExp(
    r'<tr>\s*<td[^>]*>\s*<span[^>]*>\s*\d+\s*</span>\s*</td>\s*'
    r'<td[^>]*>\s*<a href="/data_room/data\.php\?show=view&amp;id=(\d+)[^"]*board=pds"\s*>\s*(.*?)\s*</a>.*?'
    r'<td[^>]*class="bd_line_num">(\d{4}-\d{2}-\d{2})</td>',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in rowPattern.allMatches(html)) {
    final id = int.tryParse(match.group(1) ?? '');
    if (id == null) continue;
    final title = _normalizeWhitespace(htmlUnescape(match.group(2) ?? ''));
    final postedDate = match.group(3)?.trim() ?? '';
    posts.add(
      KjaPdsPostSummary(
        id: id,
        title: title,
        postedDate: postedDate,
        viewUrl:
            'https://koreajanggi.cafe24.com/data_room/data.php?show=view&id=$id&offset=0&board=pds',
      ),
    );
  }

  return posts;
}

KjaPdsPostPage parseKjaPdsPostHtml(
  String html, {
  required String viewUrl,
}) {
  final subjectMatch = RegExp(
    r'<input[^>]+name="subject"[^>]+value="([^"]+)"',
    caseSensitive: false,
  ).firstMatch(html);
  final titleFromInput = subjectMatch == null
      ? null
      : _normalizeWhitespace(htmlUnescape(subjectMatch.group(1) ?? ''));
  final titleFromView = RegExp(
    r'<td[^>]*class="viewtit"[^>]*>(.*?)</td>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  final title = titleFromInput ??
      (titleFromView == null
          ? 'Untitled Post'
          : _normalizeWhitespace(htmlUnescape(titleFromView.group(1) ?? '')));

  final dateMatch = RegExp(
    r'tit_date\.gif.*?<td[^>]*>(\d{4}\.\d{2}\.\d{2})</td>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  final postedDate = dateMatch?.group(1)?.replaceAll('.', '-') ?? '';

  final attachments = <KjaPdsAttachment>[];
  final attachmentPattern = RegExp(
    'href="\\.\\./board/down\\.php\\?board=pds&id=\\d+&cnt=\\d+".*?title=\'([^\']+)\'',
    caseSensitive: false,
    dotAll: true,
  );
  final fullAttachmentPattern = RegExp(
    'href="\\.\\./board/down\\.php\\?board=pds&id=(\\d+)&cnt=(\\d+)".*?title=\'([^\']+)\'',
    caseSensitive: false,
    dotAll: true,
  );

  for (final match in fullAttachmentPattern.allMatches(html)) {
    final postId = match.group(1);
    final cnt = match.group(2);
    final fileName = _normalizeWhitespace(htmlUnescape(match.group(3) ?? ''));
    if (fileName.isEmpty) continue;

    attachments.add(
      KjaPdsAttachment(
        fileName: fileName,
        downloadUrl:
            'https://koreajanggi.cafe24.com/board/down.php?board=pds&id=$postId&cnt=$cnt',
        postTitle: title,
        postedDate: postedDate,
        viewUrl: viewUrl,
      ),
    );
  }

  if (attachments.isEmpty) {
    for (final match in attachmentPattern.allMatches(html)) {
      final fileName = _normalizeWhitespace(htmlUnescape(match.group(1) ?? ''));
      if (fileName.isEmpty) continue;
      attachments.add(
        KjaPdsAttachment(
          fileName: fileName,
          downloadUrl: viewUrl,
          postTitle: title,
          postedDate: postedDate,
          viewUrl: viewUrl,
        ),
      );
    }
  }

  return KjaPdsPostPage(
    title: title,
    postedDate: postedDate,
    viewUrl: viewUrl,
    attachments: attachments,
  );
}

List<File> scanManualDropFiles(Directory root) {
  if (!root.existsSync()) {
    return const <File>[];
  }

  final files = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) {
        final lower = file.path.toLowerCase();
        return lower.endsWith('.gib') ||
            lower.endsWith('.txt') ||
            lower.endsWith('.gib.txt');
      })
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(data)}\n', encoding: utf8);
}

void writeJsonLines(String path, Iterable<Map<String, dynamic>> records) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  final sink = file.openWrite(encoding: utf8);
  for (final record in records) {
    sink.writeln(jsonEncode(record));
  }
  sink.close();
}

String _defaultCorpusRoot() {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}janggi_gib_corpus';
}

String _normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
