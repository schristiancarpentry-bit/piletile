import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager _instance = AdManager._();
  factory AdManager() => _instance;
  AdManager._();

  static const String _interstitialId = 'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;
  int _roundsSinceAd = 0;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
        },
        onAdFailedToLoad: (_) {
          _isLoaded = false;
        },
      ),
    );
  }

  void onRoundComplete() {
    _roundsSinceAd++;
    if (_roundsSinceAd >= 3) {
      _roundsSinceAd = 0;
    }
  }

  bool get shouldShowAd => _roundsSinceAd == 0 && _isLoaded;

  Future<void> showInterstitial({VoidCallback? onDismissed}) async {
    if (!_isLoaded || _interstitialAd == null) {
      onDismissed?.call();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isLoaded = false;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _isLoaded = false;
        _loadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitialAd!.show();
    _interstitialAd = null;
  }
}
