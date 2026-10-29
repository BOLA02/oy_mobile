import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/features/splash/splash_screen.dart';

/// Moves time forward in small steps, like real frames, so delayed effects get
/// their turn to start.
Future<void> _advance(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The splash's delayed effects use timers; let them run out before the test ends.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

Future<ProviderContainer> _pumpSplash(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: SplashScreen()),
  ));
  return container;
}

/// Where the icon is pointing right now, in radians (from its on-screen transform).
double _angle(WidgetTester tester) {
  final m = tester.renderObject(find.byKey(const ValueKey('splash_mark'))).getTransformTo(null).storage;
  return math.atan2(m[1], m[0]);
}

double _scale(WidgetTester tester) {
  final m = tester.renderObject(find.byKey(const ValueKey('splash_mark'))).getTransformTo(null).storage;
  return math.sqrt(m[0] * m[0] + m[1] * m[1]);
}

void main() {
  testWidgets('the icon makes one full, smooth 360° turn while it grows in', (tester) async {
    await _pumpSplash(tester);

    // Follow the angle every 40 ms. Wrapping makes angles jump by 2π, so add up the
    // small steps instead; that gives the real distance the icon has turned.
    var turned = 0.0;
    var biggestStep = 0.0;
    var last = _angle(tester);
    final firstScale = _scale(tester);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final now = _angle(tester);
      var step = now - last;
      while (step > math.pi) {
        step -= 2 * math.pi;
      }
      while (step < -math.pi) {
        step += 2 * math.pi;
      }
      turned += step;
      biggestStep = math.max(biggestStep, step.abs());
      last = now;
    }

    // A complete revolution (the sign only says which way it turns).
    expect(turned.abs(), closeTo(2 * math.pi, 0.25));
    // Never a jump: each 40 ms step is a modest slice of the turn, so the eye can follow it.
    expect(biggestStep, lessThan(math.pi / 3));
    // It starts as a speck and ends at full size.
    expect(firstScale, lessThan(0.1));
    expect(_scale(tester), closeTo(1, 0.08));
    // And it lands upright.
    expect(_angle(tester).abs(), lessThan(0.05));
    await _finish(tester);
  });

  testWidgets('the spin is spread evenly, not a flick in the first instant', (tester) async {
    await _pumpSplash(tester);

    var turned = 0.0;
    var last = _angle(tester);
    // Track the turn up to the halfway mark of the 2 s spin.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final now = _angle(tester);
      var step = now - last;
      while (step > math.pi) {
        step -= 2 * math.pi;
      }
      while (step < -math.pi) {
        step += 2 * math.pi;
      }
      turned += step;
      last = now;
    }

    // At 1 s of 2 s it should be roughly half way round. A front-loaded ease would
    // already be past 80% by now, which is what made it look like a quick flick.
    final share = turned.abs() / (2 * math.pi);
    expect(share, inInclusiveRange(0.3, 0.7));
    await _finish(tester);
  });

  testWidgets('the splash holds long enough to enjoy and then lets go', (tester) async {
    final container = await _pumpSplash(tester);
    await _advance(tester, 3500);
    expect(container.read(splashFinishedProvider), isFalse, reason: 'still playing at 3.5 s');

    await _advance(tester, 500);
    expect(container.read(splashFinishedProvider), isTrue);
    await _finish(tester);
  });

  testWidgets('wordmark and tagline come after the icon, in that order', (tester) async {
    await _pumpSplash(tester);

    double opacityOf(String asset) {
      final image = find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.endsWith(asset));
      // flutter_animate fades with a FadeTransition.
      final fades = find.ancestor(of: image, matching: find.byType(FadeTransition)).evaluate();
      if (fades.isEmpty) return 1;
      return (fades.first.widget as FadeTransition).opacity.value;
    }

    await _advance(tester, 800);
    expect(opacityOf('logo_wordmark.png'), 0, reason: 'not yet while the icon is still turning');
    expect(opacityOf('logo_tagline.png'), 0);

    await _advance(tester, 1600); // 2.4 s
    expect(opacityOf('logo_wordmark.png'), greaterThan(0.5));
    expect(opacityOf('logo_tagline.png'), 0, reason: 'the tagline waits for the wordmark');

    await _advance(tester, 1100); // 3.5 s
    expect(opacityOf('logo_tagline.png'), greaterThan(0.9));
    expect(opacityOf('logo_wordmark.png'), closeTo(1, 0.01));
    await _finish(tester);
  });
}
