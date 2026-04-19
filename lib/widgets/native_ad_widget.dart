import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'shimmer_placeholder.dart';

enum NativeAdSize { small, medium }

class NativeAdWidget extends StatefulWidget {
  final NativeAdSize size;
  final double? width;
  final double? height;

  const NativeAdWidget({
    super.key,
    this.size = NativeAdSize.medium,
    this.width,
    this.height,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _adFailed = false;
  int _retryAttempts = 0;
  static const int _maxRetries = 3;

  final String _adUnitId = 'ca-app-pub-3775138178121742/1965348272';

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    debugPrint('🚀 [AD] Loading Native Ad: $_adUnitId');
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ [AD] Native Ad loaded successfully.');
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
              _adFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [AD] Native ad failed to load: ${error.message}');
          debugPrint('   [AD] Error Code: ${error.code}');
          debugPrint('   [AD] Error Domain: ${error.domain}');
          ad.dispose();
          if (mounted) {
            if (_retryAttempts < _maxRetries) {
              _retryAttempts++;
              int delay = _retryAttempts * 10;
              debugPrint('🔄 [AD] Retrying in $delay seconds (Attempt $_retryAttempts/$_maxRetries)...');
              Future.delayed(Duration(seconds: delay), () => _loadAd());
            } else {
              debugPrint('🛑 [AD] Max retries reached for native ad.');
              setState(() {
                _adFailed = true;
              });
            }
          }
        },
        onAdClicked: (ad) => debugPrint('🖱️ [AD] Native Ad clicked'),
        onAdOpened: (ad) => debugPrint('📱 [AD] Native Ad opened'),
        onAdImpression: (ad) => debugPrint('👁️ [AD] Native Ad impression tracked'),
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.size == NativeAdSize.medium
            ? TemplateType.medium
            : TemplateType.small,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFFE50914),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white70,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white70,
          backgroundColor: Colors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adFailed) {
      debugPrint('🙈 [AD] Hiding failed ad widget');
      return const SizedBox.shrink();
    }

    final double defaultHeight = widget.size == NativeAdSize.medium ? 320 : 90;
    final double displayHeight = widget.height ?? defaultHeight;

    if (_nativeAdIsLoaded && _nativeAd != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 320,
            minHeight: displayHeight,
            maxWidth: widget.width ?? 480,
            maxHeight: displayHeight,
          ),
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    }

    // Shimmer placeholder while loading
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: ShimmerPlaceholder(
        width: widget.width ?? double.infinity,
        height: displayHeight,
        borderRadius: 16,
      ),
    );
  }
}
