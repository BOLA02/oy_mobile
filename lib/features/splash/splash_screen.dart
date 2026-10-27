import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

/// True once the splash animation has had its moment. The router keeps the
/// splash up until this is set, even if the saved session loads sooner.
class SplashFinished extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashFinishedProvider = NotifierProvider<SplashFinished, bool>(SplashFinished.new);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 2600)});

  final Duration duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) ref.read(splashFinishedProvider.notifier).finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.violetDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          // Soft rings that pulse outwards from the mark, like steam rising.
          for (var i = 0; i < 3; i++)
            Center(
              child: Container(
                width: 220.0 + i * 120,
                height: 220.0 + i * 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10 - i * 0.02), width: 1.5),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.04, 1.04), duration: (1800 + i * 300).ms, curve: Curves.easeInOut)
                  .fadeIn(delay: (150 * i).ms, duration: 500.ms),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/brand/icon_fg.png', width: 256, height: 256)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.55, 0.55), end: const Offset(1, 1), duration: 900.ms, curve: Curves.elasticOut)
                    .then(delay: 200.ms)
                    .shimmer(duration: 1100.ms, color: AppColors.mango.withValues(alpha: 0.45)),
                const SizedBox(height: 4),
                Text('Better chow, no wahala.',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9), letterSpacing: 0.4))
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 500.ms)
                    .slideY(begin: 0.6, end: 0, delay: 800.ms, duration: 500.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.mango, shape: BoxShape.circle),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 160).ms)
                      .fadeIn(delay: 1000.ms)
                      .moveY(begin: 0, end: -8, duration: 480.ms, curve: Curves.easeInOut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
