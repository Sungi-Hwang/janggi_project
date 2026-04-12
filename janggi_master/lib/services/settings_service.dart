import 'package:shared_preferences/shared_preferences.dart';
import '../models/rule_mode.dart';
import '../theme/janggi_skin.dart';

/// 앱의 설정을 관리하는 서비스
class SettingsService {
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keySoundVolume = 'sound_volume';
  static const String _keyLanguage = 'language';
  static const String _keyBoardSkin = 'board_skin';
  static const String _keyPieceSkin = 'piece_skin';
  static const String _keyShowCoordinates = 'show_coordinates';
  static const String _keyAiThinkingTime = 'ai_thinking_time';
  static const String _keyAiDifficulty = 'ai_difficulty';
  static const String _keyRuleMode = 'rule_mode';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 사운드 설정
  bool get soundEnabled => _prefs.getBool(_keySoundEnabled) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(_keySoundEnabled, value);

  double get soundVolume => _prefs.getDouble(_keySoundVolume) ?? 1.0;
  Future<void> setSoundVolume(double value) =>
      _prefs.setDouble(_keySoundVolume, value);

  // 언어 설정 (ko, en)
  String get language => _prefs.getString(_keyLanguage) ?? 'ko';
  Future<void> setLanguage(String value) =>
      _prefs.setString(_keyLanguage, value);

  // 디자인 설정
  String get boardSkin =>
      _prefs.getString(_keyBoardSkin) ?? JanggiSkin.boardKoreanWood;

  Future<void> setBoardSkinValue(String value) =>
      _prefs.setString(_keyBoardSkin, value);

  String get pieceSkin =>
      _prefs.getString(_keyPieceSkin) ?? JanggiSkin.pieceTraditional;
  Future<void> setPieceSkin(String value) =>
      _prefs.setString(_keyPieceSkin, value);

  // 게임 편의 설정
  bool get showCoordinates => _prefs.getBool(_keyShowCoordinates) ?? true;
  Future<void> setShowCoordinates(bool value) =>
      _prefs.setBool(_keyShowCoordinates, value);

  int get aiThinkingTime => _prefs.getInt(_keyAiThinkingTime) ?? 5; // 초 단위
  Future<void> setAiThinkingTime(int value) =>
      _prefs.setInt(_keyAiThinkingTime, value.clamp(1, 30));

  int get aiDifficulty => _prefs.getInt(_keyAiDifficulty) ?? 5;
  Future<void> setAiDifficulty(int value) =>
      _prefs.setInt(_keyAiDifficulty, value.clamp(1, 15));

  RuleMode get ruleMode =>
      RuleModeX.fromStorageValue(_prefs.getString(_keyRuleMode));

  Future<void> setRuleMode(RuleMode value) =>
      _prefs.setString(_keyRuleMode, value.storageValue);
}
