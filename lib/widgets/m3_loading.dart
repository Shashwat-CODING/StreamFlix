import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

class M3Loading extends StatelessWidget {
  final double size;
  final String? message;

  const M3Loading({super.key, this.size = 64, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: LoadingIndicatorM3E(color: cs.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class M3LoadingOverlay extends StatelessWidget {
  final String? message;

  const M3LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: M3Loading(message: message, size: 48),
      ),
    );
  }
}
