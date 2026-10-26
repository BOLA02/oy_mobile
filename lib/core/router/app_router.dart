import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/customer_signup_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/rider_register_screen.dart';
import '../../features/customer/presentation/cart_screen.dart';
import '../../features/customer/presentation/home_screen.dart';
import '../../features/customer/presentation/restaurant_screen.dart';
import '../../features/rider/presentation/rider_dashboard_screen.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/profile_screen.dart';
import '../../shared/widgets/shells.dart';

const _authPaths = {'/login', '/signup', '/rider-register'};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final path = state.matchedLocation;

      if (session.isLoading) return path == '/splash' ? null : '/splash';

      final user = session.value;
      if (user == null) return _authPaths.contains(path) ? null : '/login';

      // Signed in: keep each role inside its own half of the app.
      final home = user.role == AppRole.customer ? '/c/home' : '/r/deliveries';
      final prefix = user.role == AppRole.customer ? '/c' : '/r';
      if (!path.startsWith(prefix)) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const CustomerSignupScreen()),
      GoRoute(path: '/rider-register', builder: (_, _) => const RiderRegisterScreen()),

      // ── Customer ───────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CustomerShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/c/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/c/orders',
              builder: (_, _) => const Scaffold(
                body: EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  subtitle: 'Your order history will show up here.',
                ),
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/c/cart', builder: (_, _) => const CartScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/c/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/c/restaurant/:id',
        builder: (_, state) => RestaurantScreen(restaurantId: int.parse(state.pathParameters['id']!)),
      ),

      // ── Rider ──────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RiderShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/r/deliveries', builder: (_, _) => const RiderDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/r/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});
