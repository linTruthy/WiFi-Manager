import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Ad load status tracking
  bool _isBannerLoading = false;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);

  // Analytics tracking
  int _bannerImpressions = 0;
  int _interstitialImpressions = 0;
  int _rewardedImpressions = 0;

  // Cooldown management
  DateTime? _lastInterstitialShow;
  static const Duration interstitialCooldown = Duration(minutes: 2);

  // Configuration
  final AdRequest _adRequest = AdRequest(
    keywords: ['utility', 'internet', 'wifi'],
    //contentUrl: 'https://your-app-content-url.com',
    nonPersonalizedAds: false,
  );

  // Banner Ad Management
  Future<void> initializeBannerAd({
    String? adUnitId,
    AdSize size = AdSize.banner,
    int retryCount = 0,
  }) async {
    if (_isBannerLoading) return;
    _isBannerLoading = true;

    try {
      _bannerAd?.dispose();
      _bannerAd = BannerAd(
        adUnitId: adUnitId ?? "ca-app-pub-8267064683737776/7537627551",
        size: size,
        request: _adRequest,
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            _isBannerLoading = false;
            _bannerImpressions++;
            debugPrint(
              'Banner Ad loaded successfully. Total impressions: $_bannerImpressions',
            );
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) async {
            _isBannerLoading = false;
            ad.dispose();
            debugPrint('Banner Ad failed to load: $error');

            if (retryCount < maxRetries) {
              await Future.delayed(retryDelay);
              initializeBannerAd(
                adUnitId: adUnitId,
                size: size,
                retryCount: retryCount + 1,
              );
            }
          },
          onAdImpression: (Ad ad) {
            _bannerImpressions++;
            debugPrint('Banner Ad impression recorded');
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      _isBannerLoading = false;
      debugPrint('Error initializing banner ad: $e');
    }
  }

  // Enhanced Banner Widget with loading and error states
  Widget getBannerAdWidget({double? maxWidth}) {
    return _bannerAd == null
        ? const SizedBox.shrink()
        : Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: _bannerAd!.size.height.toDouble(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
  }

  // Interstitial Ad Management
  Future<void> initializeInterstitialAd({
    String? adUnitId,
    int retryCount = 0,
  }) async {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: adUnitId ?? 'ca-app-pub-8267064683737776/1092736180',
        request: _adRequest,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _isInterstitialLoading = false;
            _interstitialAd = ad;
            debugPrint('Interstitial Ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            _isInterstitialLoading = false;
            debugPrint('Interstitial Ad failed to load: $error');

            if (retryCount < maxRetries) {
              await Future.delayed(retryDelay);
              initializeInterstitialAd(
                adUnitId: adUnitId,
                retryCount: retryCount + 1,
              );
            }
          },
        ),
      );
    } catch (e) {
      _isInterstitialLoading = false;
      debugPrint('Error initializing interstitial ad: $e');
    }
  }

  Future<bool> showInterstitialAd() async {
    if (_interstitialAd == null) {
      debugPrint('Interstitial Ad not loaded');
      return false;
    }

    // Check cooldown
    if (_lastInterstitialShow != null &&
        DateTime.now().difference(_lastInterstitialShow!) <
            interstitialCooldown) {
      debugPrint('Interstitial Ad in cooldown');
      return false;
    }

    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        _interstitialImpressions++;
        _lastInterstitialShow = DateTime.now();
        debugPrint(
          'Interstitial Ad showed. Total impressions: $_interstitialImpressions',
        );
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        initializeInterstitialAd();
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        initializeInterstitialAd();
        completer.complete(false);
        debugPrint('Interstitial Ad failed to show: $error');
      },
    );

    await _interstitialAd!.show();
    _interstitialAd = null;
    return completer.future;
  }

  // Rewarded Ad Management with enhanced reward handling
  Future<void> initializeRewardedAd({
    String? adUnitId,
    int retryCount = 0,
  }) async {
    if (_isRewardedLoading) return;
    _isRewardedLoading = true;

    try {
      await RewardedAd.load(
        adUnitId: adUnitId ?? "ca-app-pub-8267064683737776/9972219205",
        request: _adRequest,
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _isRewardedLoading = false;
            _rewardedAd = ad;
            debugPrint('Rewarded Ad loaded successfully');
          },
          onAdFailedToLoad: (LoadAdError error) async {
            _isRewardedLoading = false;
            debugPrint('Rewarded Ad failed to load: $error');

            if (retryCount < maxRetries) {
              await Future.delayed(retryDelay);
              initializeRewardedAd(
                adUnitId: adUnitId,
                retryCount: retryCount + 1,
              );
            }
          },
        ),
      );
    } catch (e) {
      _isRewardedLoading = false;
      debugPrint('Error initializing rewarded ad: $e');
    }
  }

  Future<RewardResult?> showRewardedAd() async {
    if (_rewardedAd == null) {
      debugPrint('Rewarded Ad not loaded');
      return null;
    }

    final completer = Completer<RewardResult?>();
    RewardResult? result;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        _rewardedImpressions++;
        debugPrint(
          'Rewarded Ad showed. Total impressions: $_rewardedImpressions',
        );
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        initializeRewardedAd();
        completer.complete(result);
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        initializeRewardedAd();
        completer.complete(null);
        debugPrint('Rewarded Ad failed to show: $error');
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        result = RewardResult(
          type: reward.type,
          amount: reward.amount,
          timestamp: DateTime.now(),
        );
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    _rewardedAd = null;
    return completer.future;
  }

  // Analytics getters
  int get bannerImpressions => _bannerImpressions;
  int get interstitialImpressions => _interstitialImpressions;
  int get rewardedImpressions => _rewardedImpressions;

  // Cleanup
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

// Helper class for reward tracking
class RewardResult {
  final String type;
  final num amount;
  final DateTime timestamp;

  RewardResult({
    required this.type,
    required this.amount,
    required this.timestamp,
  });
}
