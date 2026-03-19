import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 0,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width == double.infinity ? null : width,
      height: height == double.infinity ? null : height,
      child: Shimmer.fromColors(
        baseColor: baseColor ?? const Color(0xFF1E1E1E),
        highlightColor: highlightColor ?? const Color(0xFF2A2A2A),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor ?? const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
