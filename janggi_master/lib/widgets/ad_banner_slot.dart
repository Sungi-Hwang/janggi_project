import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_config.dart';
import '../providers/monetization_provider.dart';

class AdBannerSlot extends StatefulWidget {
  const AdBannerSlot({super.key});

  @override
  State<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends State<AdBannerSlot> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monetization = context.read<MonetizationProvider>();
    if (!monetization.canShowAds) {
      _disposeBanner();
      return;
    }
    if (!monetization.adSdkInitialized) {
      return;
    }

    if (_bannerAd == null) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (_bannerAd != null) return;
    final monetization = context.read<MonetizationProvider>();
    if (!monetization.adSdkInitialized) return;
    final adUnitId = MonetizationConfig.bannerAdUnitId;
    if (adUnitId.isEmpty) return;
    if (kDebugMode) {
      debugPrint('[AdBannerSlot] loading banner: $adUnitId');
    }

    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            debugPrint('[AdBannerSlot] banner loaded');
          }
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            debugPrint('[AdBannerSlot] banner failed: $error');
          }
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd = ad;
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
      return const SizedBox(height: 52);
    }

    if (_bannerAd == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner());
      return const SizedBox(height: 52);
    }

    if (!_isLoaded) {
      return const SizedBox(height: 52);
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
