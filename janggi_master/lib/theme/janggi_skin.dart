class JanggiSkin {
  const JanggiSkin._();

  static const String displayFontFamily = 'NotoSerifCJKkr';

  static const String boardKoreanWood = 'korean_wood';
  static const String boardReadable = 'readable';
  static const String boardLegacyGold = 'wood';
  static const String boardClassic = 'classic';
  static const String boardDark = 'dark';

  static const String pieceTraditional = 'traditional';
  static const String pieceReadableDisc = 'readable_disc';
  static const String pieceLegacyGold = 'gold_traditional';
  static const String pieceModern = 'modern';

  static String boardLabel(String value) {
    switch (value) {
      case boardKoreanWood:
        return '한국 장기판';
      case boardReadable:
        return '선명한 보드';
      case boardLegacyGold:
        return '금빛 보드';
      case boardClassic:
        return '클래식';
      case boardDark:
        return '다크';
      default:
        return value;
    }
  }

  static String pieceLabel(String value) {
    switch (value) {
      case pieceTraditional:
        return '한국 전통';
      case pieceReadableDisc:
        return '선명한 원형';
      case pieceLegacyGold:
        return '금빛 전통';
      case pieceModern:
        return '모던';
      default:
        return value;
    }
  }
}
