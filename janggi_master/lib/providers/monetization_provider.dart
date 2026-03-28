import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../monetization/monetization_config.dart';
import '../services/monetization_service.dart';

class MonetizationProvider extends ChangeNotifier {
  MonetizationProvider(this._service);

  final MonetizationService _service;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _initialized = false;
  bool _isInitializing = false;
  bool _storeAvailable = false;
  bool _productsLoading = false;
  bool _purchasePending = false;
  bool _removeAdsPurchased = false;
  bool _premiumPurchased = false;
  String? _errorMessage;

  List<ProductDetails> _products = const [];

  bool _adSdkInitialized = false;
  bool _interstitialLoading = false;
  bool _interstitialShowing = false;
  InterstitialAd? _interstitialAd;

  bool get isInitialized => _initialized;
  bool get storeAvailable => _storeAvailable;
  bool get productsLoading => _productsLoading;
  bool get purchasePending => _purchasePending;
  bool get removeAdsPurchased => _removeAdsPurchased;
  bool get premiumPurchased => _premiumPurchased;
  bool get adSdkInitialized => _adSdkInitialized;
  bool get isPremiumUnlocked => _premiumPurchased;
  bool get isAdFree => _removeAdsPurchased || _premiumPurchased;
  bool get canShowAds => MonetizationConfig.isAdsSupportedPlatform && !isAdFree;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get products => _products;
  ProductDetails? get removeAdsProduct =>
      _productById(MonetizationConfig.removeAdsProductId);
  int get maxDifficulty => MonetizationConfig.maxDifficulty;
  int get maxThinkingTimeSec => MonetizationConfig.maxThinkingTimeSec;

  Future<void> init() async {
    if (_initialized || _isInitializing) return;
    _isInitializing = true;

    await _service.init();
    _removeAdsPurchased = _service.removeAdsPurchased;
    _premiumPurchased = _service.premiumPurchased;
    if (_premiumPurchased) {
      _removeAdsPurchased = true;
    }

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        _errorMessage = 'Purchase stream error: $error';
        _purchasePending = false;
        notifyListeners();
      },
    );

    await _refreshStoreState();
    await _initializeAds();

    _isInitializing = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> _refreshStoreState() async {
    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (_storeAvailable) {
        await refreshProducts();
      } else {
        _products = const [];
      }
    } catch (error) {
      _errorMessage = 'Store init failed: $error';
      _storeAvailable = false;
      _products = const [];
    }
  }

  Future<void> refreshProducts() async {
    if (!_storeAvailable) return;
    _productsLoading = true;
    notifyListeners();

    try {
      final response = await _inAppPurchase.queryProductDetails(
        MonetizationConfig.productIds,
      );
      _products = response.productDetails;
      if (response.error != null) {
        _errorMessage = response.error!.message;
      }
    } catch (error) {
      _errorMessage = 'Failed to query products: $error';
    } finally {
      _productsLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyRemoveAds() async {
    await _buyById(MonetizationConfig.removeAdsProductId);
  }

  Future<void> _buyById(String productId) async {
    if (!_storeAvailable) {
      _errorMessage = 'Store is unavailable on this device.';
      notifyListeners();
      return;
    }

    final product = _productById(productId);
    if (product == null) {
      _errorMessage = 'Product is not loaded yet. Please try again.';
      notifyListeners();
      return;
    }

    _purchasePending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final param = PurchaseParam(productDetails: product);
      await _inAppPurchase.buyNonConsumable(purchaseParam: param);
    } catch (error) {
      _purchasePending = false;
      _errorMessage = 'Purchase failed: $error';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    _errorMessage = null;
    _purchasePending = true;
    notifyListeners();

    try {
      await _inAppPurchase.restorePurchases();
    } catch (error) {
      _purchasePending = false;
      _errorMessage = 'Restore failed: $error';
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  int enforceDifficultyLimit(int value) {
    return value.clamp(1, maxDifficulty);
  }

  int enforceThinkingTimeLimit(int value) {
    return value.clamp(1, maxThinkingTimeSec);
  }

  bool isDifficultyLocked(int value) {
    return false;
  }

  bool isThinkingTimeLocked(int value) {
    return false;
  }

  Future<void> registerGameCompleted() async {
    await _service.registerGameCompleted();
    if (canShowAds && _interstitialAd == null) {
      _loadInterstitial();
    }
  }

  Future<bool> maybeShowEndGameInterstitial() async {
    if (!_adSdkInitialized || !canShowAds) {
      return false;
    }
    if (_interstitialShowing) {
      return false;
    }

    final now = DateTime.now();
    await _service.normalizeInterstitialDailyCounter(now);

    if (_service.completedGamesTotal <=
        MonetizationConfig.firstGamesWithoutInterstitial) {
      return false;
    }
    if (_service.gamesSinceInterstitial <
        MonetizationConfig.interstitialGamesBetweenShows) {
      return false;
    }
    if (_service.interstitialShownToday >=
        MonetizationConfig.interstitialDailyCap) {
      return false;
    }

    final lastShownAt = _service.lastInterstitialShownAt;
    if (lastShownAt != null &&
        now.difference(lastShownAt).inSeconds <
            MonetizationConfig.interstitialMinIntervalSec) {
      return false;
    }

    if (_interstitialAd == null) {
      _loadInterstitial();
      return false;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _interstitialShowing = true;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_onInterstitialDismissed());
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialShowing = false;
        _loadInterstitial();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    ad.show();
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _interstitialShowing = false;
        _loadInterstitial();
        return false;
      },
    );
  }

  Future<void> _onInterstitialDismissed() async {
    _interstitialShowing = false;
    await _service.recordInterstitialShown(DateTime.now());
    _loadInterstitial();
  }

  Future<void> _initializeAds() async {
    if (!MonetizationConfig.isAdsSupportedPlatform) {
      return;
    }

    await MobileAds.instance.initialize();
    _adSdkInitialized = true;

    if (canShowAds) {
      _loadInterstitial();
    }
  }

  void _loadInterstitial() {
    if (!_adSdkInitialized || !canShowAds) return;
    if (_interstitialLoading || _interstitialAd != null) return;
    final adUnitId = MonetizationConfig.interstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void _disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialLoading = false;
    _interstitialShowing = false;
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    unawaited(_processPurchases(purchases));
  }

  Future<void> _processPurchases(List<PurchaseDetails> purchases) async {
    bool needsNotify = false;

    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          needsNotify = true;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverPurchase(purchase.productID);
          _purchasePending = false;
          needsNotify = true;
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _errorMessage = purchase.error?.message ?? 'Purchase failed.';
          needsNotify = true;
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          needsNotify = true;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }

    if (needsNotify) {
      notifyListeners();
    }
  }

  Future<void> _deliverPurchase(String productId) async {
    if (productId == MonetizationConfig.removeAdsProductId) {
      _removeAdsPurchased = true;
    } else if (productId == MonetizationConfig.premiumAiProductId) {
      _premiumPurchased = true;
      _removeAdsPurchased = true;
    } else {
      return;
    }

    await _service.setEntitlements(
      removeAdsPurchased: _removeAdsPurchased,
      premiumPurchased: _premiumPurchased,
    );

    if (isAdFree) {
      _disposeInterstitial();
    } else if (_interstitialAd == null) {
      _loadInterstitial();
    }
  }

  ProductDetails? _productById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _disposeInterstitial();
    super.dispose();
  }
}
