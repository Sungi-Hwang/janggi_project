import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service;

  SettingsProvider(this._service);

  bool get soundEnabled => _service.soundEnabled;
  double get soundVolume => _service.soundVolume;
  String get language => _service.language;
  String get boardSkin => _service.boardSkin;
  String get pieceSkin => _service.pieceSkin;
  bool get showCoordinates => _service.showCoordinates;
  int get aiThinkingTime => _service.aiThinkingTime;
  int get aiDifficulty => _service.aiDifficulty;

  Future<void> setSoundEnabled(bool value) async {
    await _service.setSoundEnabled(value);
    notifyListeners();
  }

  Future<void> setSoundVolume(double value) async {
    await _service.setSoundVolume(value);
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    await _service.setLanguage(value);
    notifyListeners();
  }

  Future<void> setBoardSkin(String value) async {
    await _service.setBoardSkinValue(value);
    notifyListeners();
  }

  Future<void> setPieceSkin(String value) async {
    await _service.setPieceSkin(value);
    notifyListeners();
  }

  Future<void> setShowCoordinates(bool value) async {
    await _service.setShowCoordinates(value);
    notifyListeners();
  }

  Future<void> setAiThinkingTime(int value) async {
    await _service.setAiThinkingTime(value);
    notifyListeners();
  }

  Future<void> setAiDifficulty(int value) async {
    await _service.setAiDifficulty(value);
    notifyListeners();
  }
}
