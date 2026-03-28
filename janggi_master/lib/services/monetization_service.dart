import 'package:shared_preferences/shared_preferences.dart';

class MonetizationService {
  static const String _keyRemoveAdsPurchased = 'monetization_remove_ads';
  static const String _keyPremiumPurchased = 'monetization_premium_ai';
  static const String _keyCompletedGamesTotal = 'monetization_completed_games';
  static const String _keyGamesSinceInterstitial =
      'monetization_games_since_interstitial';
  static const String _keyLastInterstitialAt = 'monetization_last_ad_at';
  static const String _keyInterstitialShownToday =
      'monetization_interstitial_count_today';
  static const String _keyInterstitialDay = 'monetization_interstitial_day';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  bool get removeAdsPurchased =>
      _prefs.getBool(_keyRemoveAdsPurchased) ?? false;
  bool get premiumPurchased => _prefs.getBool(_keyPremiumPurchased) ?? false;
  int get completedGamesTotal => _prefs.getInt(_keyCompletedGamesTotal) ?? 0;
  int get gamesSinceInterstitial =>
      _prefs.getInt(_keyGamesSinceInterstitial) ?? 0;
  int get interstitialShownToday =>
      _prefs.getInt(_keyInterstitialShownToday) ?? 0;
  DateTime? get lastInterstitialShownAt {
    final millis = _prefs.getInt(_keyLastInterstitialAt);
    if (millis == null || millis <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setEntitlements({
    required bool removeAdsPurchased,
    required bool premiumPurchased,
  }) async {
    await _prefs.setBool(_keyRemoveAdsPurchased, removeAdsPurchased);
    await _prefs.setBool(_keyPremiumPurchased, premiumPurchased);
  }

  Future<void> registerGameCompleted() async {
    await _prefs.setInt(_keyCompletedGamesTotal, completedGamesTotal + 1);
    await _prefs.setInt(_keyGamesSinceInterstitial, gamesSinceInterstitial + 1);
  }

  Future<void> recordInterstitialShown(DateTime now) async {
    await normalizeInterstitialDailyCounter(now);
    await _prefs.setInt(_keyInterstitialShownToday, interstitialShownToday + 1);
    await _prefs.setInt(
      _keyLastInterstitialAt,
      now.millisecondsSinceEpoch,
    );
    await _prefs.setInt(_keyGamesSinceInterstitial, 0);
  }

  Future<void> normalizeInterstitialDailyCounter(DateTime now) async {
    final nowDay = _toDayKey(now);
    final currentDay = _prefs.getString(_keyInterstitialDay);
    if (currentDay == nowDay) {
      return;
    }

    await _prefs.setString(_keyInterstitialDay, nowDay);
    await _prefs.setInt(_keyInterstitialShownToday, 0);
  }

  String _toDayKey(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
