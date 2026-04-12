import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_config.dart';
import '../providers/monetization_provider.dart';

enum AdBannerPlacement {
  menu,
  inGame,
}

class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({
    super.key,
    this.placement = AdBannerPlacement.inGame,
  });

  final AdBannerPlacement placement;

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoadingSize = false;
  int? _requestedWidth;

  bool get _useAdaptiveSize => widget.placement == AdBannerPlacement.menu;

  bool get _reserveSpaceWhileLoading =>
      widget.placement == AdBannerPlacement.inGame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureBannerReady();
  }

  @override
  void didUpdateWidget(covariant AdBannerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _disposeBanner();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureBannerReady();
        }
      });
    }
  }

  Future<void> _ensureBannerReady() async {
    final monetization = context.read<MonetizationProvider>();
    if (!monetization.canShowAds || !monetization.adSdkInitialized) {
      _disposeBanner();
      return;
    }

    final nextSize = await _resolveAdSize();
    if (!mounted || nextSize == null) {
      return;
    }

    if (_adSize == nextSize && _bannerAd != null) {
      return;
    }

    _disposeBanner();
    _loadBanner(nextSize);
  }

  Future<AdSize?> _resolveAdSize() async {
    if (!_useAdaptiveSize) {
      return AdSize.banner;
    }

    if (_isLoadingSize) {
      return _adSize;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) {
      return null;
    }

    if (_requestedWidth == width && _adSize != null) {
      return _adSize;
    }

    _isLoadingSize = true;
    try {
      final adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        width,
      );
      _requestedWidth = width;
      _adSize = adaptiveSize ?? AdSize.banner;
      return _adSize;
    } finally {
      _isLoadingSize = false;
    }
  }

  void _loadBanner(AdSize size) {
    if (_bannerAd != null) {
      return;
    }

    final monetization = context.read<MonetizationProvider>();
    if (!monetization.adSdkInitialized) {
      return;
    }

    final adUnitId = MonetizationConfig.bannerAdUnitId;
    if (adUnitId.isEmpty) {
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[AdBannerSlot] loading ${widget.placement.name} banner: '
        '$adUnitId (${size.width}x${size.height})',
      );
    }

    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          if (kDebugMode) {
            debugPrint('[AdBannerSlot] ${widget.placement.name} banner loaded');
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = size;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint(
              '[AdBannerSlot] ${widget.placement.name} banner failed: $error',
            );
          }
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd = ad;
    _adSize = size;
    ad.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monetization = context.watch<MonetizationProvider>();

    if (!monetization.canShowAds) {
      if (_bannerAd != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _disposeBanner());
      }
      return const SizedBox.shrink();
    }

    if (!monetization.adSdkInitialized) {
      return _buildPlaceholder();
    }

    if (_bannerAd == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ensureBannerReady();
        }
      });
      return _buildPlaceholder();
    }

    if (!_isLoaded) {
      return _buildPlaceholder();
    }

    final width = _adSize?.width.toDouble() ?? _bannerAd!.size.width.toDouble();
    final height =
        _adSize?.height.toDouble() ?? _bannerAd!.size.height.toDouble();

    final adWidget = SizedBox(
      width: width,
      height: height,
      child: AdWidget(ad: _bannerAd!),
    );

    if (widget.placement == AdBannerPlacement.menu) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: adWidget,
        ),
      );
    }

    return adWidget;
  }

  Widget _buildPlaceholder() {
    if (!_reserveSpaceWhileLoading) {
      return const SizedBox.shrink();
    }

    final height =
        (_adSize?.height.toDouble() ?? AdSize.banner.height.toDouble()) + 4;
    return SizedBox(height: height);
  }
}
