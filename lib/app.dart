import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/session_controller.dart';
import 'features/rider/application/location_reporter.dart';

class OyaEatApp extends ConsumerWidget {
  const OyaEatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stop sharing location the moment the rider signs out.
    ref.listen(sessionControllerProvider, (_, next) {
      if (next.value == null) ref.read(locationReporterProvider).stop();
    });

    return MaterialApp.router(
      title: 'OyaEat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
