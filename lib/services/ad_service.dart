import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isLoading = false;
  
  static const String _adUnitId = 'ca-app-pub-3775138178121742/7433297377';

  static void loadRewardedAd() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isLoading || _rewardedAd != null) return;
    _isLoading = true;
    
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          debugPrint('Error Code: ${error.code}');
          debugPrint('Error Message: ${error.message}');
          debugPrint('Error Domain: ${error.domain}');
          _isLoading = false;
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
      debugPrint('Ad show request but not loaded. Proceeding implicitly.');
      onComplete();
      loadRewardedAd();
      return;
    }

    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload for the next time

        if (earnedReward) {
          onComplete();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'Watch the full ad to unlock this content.'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('RewardedAd failed to show: $error');
        debugPrint('Error Code: ${error.code}');
        debugPrint('Error Message: ${error.message}');
        debugPrint('Error Domain: ${error.domain}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onComplete();     // Fallback if error displaying ad
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
      earnedReward = true;
    });
  }
}
