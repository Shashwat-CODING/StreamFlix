import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;
  static int _numAttempts = 0;
  static const int maxAttempts = 5;
  
  static const String _adUnitId = 'ca-app-pub-3775138178121742/7433297377';

  static void loadRewardedAd() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isAdLoading || _rewardedAd != null) return;

    _isAdLoading = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(
        keywords: ['streaming', 'movies', 'tv shows', 'entertainment'],
        nonPersonalizedAds: false,
      ),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _numAttempts = 0;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isAdLoading = false;
          _numAttempts++;
          
          if (_numAttempts < maxAttempts) {
            final retryDelay = Duration(seconds: (1 << _numAttempts).clamp(2, 30));
            Future.delayed(retryDelay, () => loadRewardedAd());
          }
        },
      ),
    );
  }

  static void showRewardedAd({
    required BuildContext context,
    required VoidCallback onComplete,
    String? message,
  }) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      onComplete();
      return;
    }

    if (_rewardedAd == null) {
      onComplete();
      loadRewardedAd();
      return;
    }

    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('📱 [AdService] Ad showed full screen.'),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();

        if (earnedReward) {
          onComplete();
        } else {
          // Toast-like notification could go here if needed
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onComplete();
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
      earnedReward = true;
    });
  }
}

