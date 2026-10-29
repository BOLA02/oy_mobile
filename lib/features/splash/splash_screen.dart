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

/// How long the splash holds the screen. Long enough for the whole animation to
/// play and be enjoyed; tests override it so they do not wait.
final splashDurationProvider = Provider<Duration>((ref) => const Duration(milliseconds: 3800));

/// The timeline, in one place. Each beat starts as the previous one is landing.
class _Beat {
  static const spin = Duration(milliseconds: 2000); // icon: one full turn + grow
  static const wordmarkAt = Duration(milliseconds: 1700);
  static const wordmarkFor = Duration(milliseconds: 650);
  static const taglineAt = Duration(milliseconds: 2450);
  static const taglineFor = Duration(milliseconds: 600);
  static const ringsAt = Duration(milliseconds: 1500);
  static const dotsAt = Duration(milliseconds: 2300);
}

/// The OyaEat logo, built up in three beats on white:
///   1. the icon comes out of the distance, spinning one full turn as it grows
///      to size and settles,
///   2. the "OyaEat" wordmark rises in underneath,
///   3. the tagline fades in last.
/// The logo is cut into three images so each part can move on its own.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.duration});

  /// Overrides [splashDurationProvider] (used by previews and tests).
  final Duration? duration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration ?? ref.read(splashDurationProvider), () {
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
                                  .animate(onPlay: (c) => c.repeat(reverse: true), delay: _Beat.ringsAt + (i * 140).ms)
                                  .fadeIn(duration: 500.ms)
                                  .scale(begin: const Offset(0.94, 0.94), end: const Offset(1.05, 1.05), duration: (1700 + i * 260).ms, curve: Curves.easeInOut),
                            Image.asset('assets/brand/logo_mark.png', key: const ValueKey('splash_mark'), width: markW, semanticLabel: 'OyaEat')
                                .animate()
                                // Emerges gradually, as if from far behind the screen.
                                .fadeIn(duration: 900.ms, curve: Curves.easeIn)
                                // One full 360° turn, evenly paced so every degree is seen,
                                // easing out at the end so it lands softly.
                                .rotate(begin: -1, end: 0, duration: _Beat.spin, curve: Curves.easeInOutCubic)
                                // ...while growing from a speck to full size, with a small overshoot.
                                .scale(begin: const Offset(0.04, 0.04), end: const Offset(1, 1), duration: _Beat.spin, curve: Curves.easeOutBack),
                          ],
                        ),
                      ),
                      SizedBox(height: w * 0.01),
                      // 2. The wordmark rises in once the icon has landed.
                      Image.asset('assets/brand/logo_wordmark.png', width: wordW)
                          .animate()
                          .fadeIn(delay: _Beat.wordmarkAt, duration: _Beat.wordmarkFor)
                          .slideY(begin: 0.45, end: 0, delay: _Beat.wordmarkAt, duration: _Beat.wordmarkFor, curve: Curves.easeOutCubic)
                          .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1), delay: _Beat.wordmarkAt, duration: _Beat.wordmarkFor, curve: Curves.easeOutCubic),
                      SizedBox(height: w * 0.045),
                      // 3. Then the tagline.
                      Image.asset('assets/brand/logo_tagline.png', width: tagW)
                          .animate()
                          .fadeIn(delay: _Beat.taglineAt, duration: _Beat.taglineFor)
                          .slideY(begin: 0.8, end: 0, delay: _Beat.taglineAt, duration: _Beat.taglineFor, curve: Curves.easeOutCubic),
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
                            .fadeIn(delay: _Beat.dotsAt)
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
