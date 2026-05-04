import 'package:flutter/foundation.dart';

class MonetizationConfig {
  const MonetizationConfig._();

  static const _googleSamplePublisherId = 'ca-app-pub-3940256099942544';
  static const _useProductionAdsInDebug = bool.fromEnvironment(
    'ADMOB_USE_PRODUCTION_ADS_IN_DEBUG',
  );
  static const _androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-5593224479644015/3813684745',
  );
  static const _androidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-5593224479644015/6990601711',
  );
  static const _iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );
  static const _iosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
  );

  static const _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  // Main menu banners now use a separate overlay slot so they do not alter the
  // menu scaffold's main layout while loading.
  static const bool enableMainMenuBanner = true;
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
        return _configuredOrDebugTestAdUnitId(
          configuredId: _androidBannerAdUnitId,
          debugTestId: _androidTestBannerAdUnitId,
        );
      case TargetPlatform.iOS:
        return _configuredOrDebugTestAdUnitId(
          configuredId: _iosBannerAdUnitId,
          debugTestId: _iosTestBannerAdUnitId,
        );
      default:
        return '';
    }
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _configuredOrDebugTestAdUnitId(
          configuredId: _androidInterstitialAdUnitId,
          debugTestId: _androidTestInterstitialAdUnitId,
        );
      case TargetPlatform.iOS:
        return _configuredOrDebugTestAdUnitId(
          configuredId: _iosInterstitialAdUnitId,
          debugTestId: _iosTestInterstitialAdUnitId,
        );
      default:
        return '';
    }
  }

  static String _configuredOrDebugTestAdUnitId({
    required String configuredId,
    required String debugTestId,
  }) {
    if (!kReleaseMode && !_useProductionAdsInDebug) {
      return debugTestId;
    }

    final normalizedId = configuredId.trim();
    if (normalizedId.isNotEmpty && !_isGoogleSampleAdId(normalizedId)) {
      return normalizedId;
    }

    // Never serve Google's sample test units from production builds.
    return kReleaseMode ? '' : debugTestId;
  }

  static bool _isGoogleSampleAdId(String value) {
    return value.contains(_googleSamplePublisherId);
  }
}
