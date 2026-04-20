import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static RewardedAd? _rewardedAd;
  static bool _isAdLoading = false;
  static int _numAttempts = 0;
  static const int maxAttempts = 5;
  
  static const String _adUnitId = 'ca-app-pub-3775138178121742/7433297377';

  /// Preloads the rewarded ad with retry logic and timeout.
  static void loadRewardedAd() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isAdLoading || _rewardedAd != null) return;

    _isAdLoading = true;
    debugPrint('🎬 [AdService] Attempting to load rewarded ad (Attempt: ${_numAttempts + 1})');

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(
        keywords: ['streaming', 'movies', 'tv shows', 'entertainment'],
        nonPersonalizedAds: false,
      ),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdService] Rewarded ad loaded successfully.');
          _rewardedAd = ad;
          _numAttempts = 0;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isAdLoading = false;
          _numAttempts++;
          debugPrint('❌ [AdService] Rewarded ad failed to load: ${error.message} (Code: ${error.code})');
          
          if (_numAttempts < maxAttempts) {
            final retryDelay = Duration(seconds: (1 << _numAttempts).clamp(2, 30));
            debugPrint('🔄 [AdService] Retrying in ${retryDelay.inSeconds} seconds...');
            Future.delayed(retryDelay, () => loadRewardedAd());
          } else {
            debugPrint('⚠️ [AdService] Max retry attempts reached. Giving up for now.');
          }
        },
      ),
    );
  }

  /// Shows the rewarded ad to the user.
  /// If the ad is not ready, it will try to load one and proceed implicitly.
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
      debugPrint('⚠️ [AdService] Ad requested but not ready. Loading and proceeding...');
      onComplete();
      loadRewardedAd();
      return;
    }

    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('📱 [AdService] Ad showed full screen.'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('🚪 [AdService] Ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next ad

        if (earnedReward) {
          onComplete();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message ?? 'Watch the full ad to unlock content.'),
                backgroundColor: Colors.red.shade900,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('💥 [AdService] Ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onComplete(); // Fallback to content if ad fails to show
      },
      onAdWillDismissFullScreenContent: (ad) => debugPrint('👋 [AdService] Ad about to dismiss.'),
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
      debugPrint('💰 [AdService] User earned reward: ${rewardItem.amount} ${rewardItem.type}');
      earnedReward = true;
    });
  }
}
