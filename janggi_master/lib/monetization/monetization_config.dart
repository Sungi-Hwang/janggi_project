import 'package:flutter/foundation.dart';

class MonetizationConfig {
  const MonetizationConfig._();

  // Temporary guard: some Android devices/renderers show a white main canvas
  // when a BannerAd widget is attached to the menu.
  static const bool enableMainMenuBanner = false;
  static const bool enableInGameTopBanner = true;

  static const String removeAdsProductId = 'remove_ads';
  // Legacy product kept for restore/migration only.
  static const String premiumAiProductId = 'premium_ai';
  static const Set<String> productIds = {
    removeAdsProductId,
  };

  static const int maxDifficulty = 15;
  static const int maxThinkingTimeSec = 30;

  static const int firstGamesWithoutInterstitial = 3;
  static const int interstitialMinIntervalSec = 120;
  static const int interstitialGamesBetweenShows = 2;
  static const int interstitialDailyCap = 6;

  static bool get isAdsSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const String.fromEnvironment(
          'ADMOB_ANDROID_BANNER_ID',
          defaultValue: 'ca-app-pub-3940256099942544/6300978111',
        );
      case TargetPlatform.iOS:
        return const String.fromEnvironment(
          'ADMOB_IOS_BANNER_ID',
          defaultValue: 'ca-app-pub-3940256099942544/2934735716',
        );
      default:
        return '';
    }
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const String.fromEnvironment(
          'ADMOB_ANDROID_INTERSTITIAL_ID',
          defaultValue: 'ca-app-pub-3940256099942544/1033173712',
        );
      case TargetPlatform.iOS:
        return const String.fromEnvironment(
          'ADMOB_IOS_INTERSTITIAL_ID',
          defaultValue: 'ca-app-pub-3940256099942544/4411468910',
        );
      default:
        return '';
    }
  }
}
