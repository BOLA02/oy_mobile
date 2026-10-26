import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/rider_repository.dart';
import '../domain/rider_dashboard.dart';

final riderRepositoryProvider =
    Provider<RiderRepository>((ref) => RiderRepository(ref.watch(apiClientProvider)));

final riderDashboardProvider = FutureProvider.autoDispose<RiderDashboard>(
  (ref) => ref.watch(riderRepositoryProvider).dashboard(),
);
