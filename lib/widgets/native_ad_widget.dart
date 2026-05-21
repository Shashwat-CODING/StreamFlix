import 'dart:io';
import 'package:flutter/cupertino.dart';
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
    if (Platform.isAndroid || Platform.isIOS) {
      _loadAd();
    }
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
              _adFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            if (_retryAttempts < _maxRetries) {
              _retryAttempts++;
              int delay = _retryAttempts * 10;
              Future.delayed(Duration(seconds: delay), () => _loadAd());
            } else {
              setState(() {
                _adFailed = true;
              });
            }
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.size == NativeAdSize.medium
            ? TemplateType.medium
            : TemplateType.small,
        mainBackgroundColor: CupertinoColors.transparent,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: CupertinoColors.white,
          backgroundColor: const Color(0xFFE50914),
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: CupertinoColors.white,
          backgroundColor: CupertinoColors.transparent,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: CupertinoColors.systemGrey,
          backgroundColor: CupertinoColors.transparent,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: CupertinoColors.systemGrey,
          backgroundColor: CupertinoColors.transparent,
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const SizedBox.shrink();
    }
    if (_adFailed) {
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

