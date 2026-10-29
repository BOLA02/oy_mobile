import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The OyaEat logo, built up in three beats on white:
///   1. the icon spins in from nothing and settles,
///   2. the "OyaEat" wordmark rises in underneath,
///   3. the tagline fades in last.
/// The logo is cut into three images so each part can move on its own.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 2800)});

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const ValueKey('splash'),
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, box) {
            // Sized from the width so it looks the same on a small phone and a tablet.
            final w = math.min(box.maxWidth, 440.0);
            final markW = w * 0.50;
            final wordW = w * 0.80;
            final tagW = w * 0.64;

            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. The icon, with soft rings pulsing behind it.
                      SizedBox(
                        width: markW * 1.9,
                        height: markW * 1.9,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                width: markW * (1.15 + i * 0.28),
                                height: markW * (1.15 + i * 0.28),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (i.isEven ? AppColors.brandOrange : AppColors.brandGreen).withValues(alpha: 0.16 - i * 0.04),
                                    width: 1.5,
                                  ),
                                ),
                              )
                                  .animate(onPlay: (c) => c.repeat(reverse: true), delay: (700 + i * 140).ms)
                                  .fadeIn(duration: 500.ms)
                                  .scale(begin: const Offset(0.94, 0.94), end: const Offset(1.05, 1.05), duration: (1700 + i * 260).ms, curve: Curves.easeInOut),
                            Image.asset('assets/brand/logo_mark.png', width: markW, semanticLabel: 'OyaEat')
                                .animate()
                                .fadeIn(duration: 240.ms)
                                // "Spins out": three-quarters of a turn while growing from a dot.
                                .rotate(begin: -0.75, end: 0, duration: 1150.ms, curve: Curves.easeOutCubic)
                                .scale(begin: const Offset(0.1, 0.1), end: const Offset(1, 1), duration: 1150.ms, curve: Curves.easeOutBack),
                          ],
                        ),
                      ),
                      SizedBox(height: w * 0.01),
                      // 2. The wordmark rises in once the icon has landed.
                      Image.asset('assets/brand/logo_wordmark.png', width: wordW)
                          .animate()
                          .fadeIn(delay: 950.ms, duration: 450.ms)
                          .slideY(begin: 0.45, end: 0, delay: 950.ms, duration: 550.ms, curve: Curves.easeOutCubic)
                          .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), delay: 950.ms, duration: 550.ms, curve: Curves.easeOutCubic),
                      SizedBox(height: w * 0.045),
                      // 3. Then the tagline.
                      Image.asset('assets/brand/logo_tagline.png', width: tagW)
                          .animate()
                          .fadeIn(delay: 1550.ms, duration: 500.ms)
                          .slideY(begin: 0.8, end: 0, delay: 1550.ms, duration: 500.ms, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: i == 1 ? AppColors.brandGreen : AppColors.brandOrange, shape: BoxShape.circle),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true), delay: (i * 160).ms)
                            .fadeIn(delay: 1300.ms)
                            .moveY(begin: 0, end: -8, duration: 480.ms, curve: Curves.easeInOut),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
