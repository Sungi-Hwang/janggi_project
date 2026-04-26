import '../utils/puzzle_share_codec.dart';
import 'custom_puzzle_service.dart';

class SharedPuzzleImportException implements Exception {
  const SharedPuzzleImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SharedPuzzleImportService {
  static Map<String, dynamic> decodeShareCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const SharedPuzzleImportException('공유 코드를 붙여넣어 주세요.');
    }

    try {
      return PuzzleShareCodec.decode(trimmed);
    } catch (_) {
      throw const SharedPuzzleImportException('공유 코드 형식이 올바르지 않습니다.');
    }
  }

  static Map<String, dynamic> buildImportedPuzzle(
    Map<String, dynamic> decoded, {
    String importSource = CustomPuzzleService.importSourceShareCode,
    DateTime? importedAt,
  }) {
    final payload = PuzzleShareCodec.toSavablePuzzle(decoded);
    final solution = List<String>.from(payload['solution'] ?? const <String>[]);
    if (solution.isEmpty) {
      throw const SharedPuzzleImportException(
        '정답 수순이 없는 공유 코드는 가져온 문제에 저장할 수 없습니다.',
      );
    }

    final now = importedAt ?? DateTime.now();
    final title = (payload['title'] as String? ?? '').trim();

    return <String, dynamic>{
      'id': CustomPuzzleService.nextImportedId(),
      'title': title.isNotEmpty
          ? title
          : '가져온 문제 ${_timestampLabel(now)}',
      'fen': payload['fen'],
      'solution': solution,
      'mateIn': payload['mateIn'],
      'toMove': payload['toMove'],
      'source': 'imported',
      'createdAt': now.toIso8601String(),
      'libraryType': CustomPuzzleService.libraryTypeImported,
      'importSource': importSource,
    };
  }

  static String _timestampLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
