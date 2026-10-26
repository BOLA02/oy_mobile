import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/domain/session.dart';
import '../../features/auth/presentation/customer_signup_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/rider_register_screen.dart';
import '../../features/customer/domain/restaurant.dart';
import '../../features/customer/presentation/account_screens.dart';
import '../../features/customer/presentation/cart_screen.dart';
import '../../features/customer/presentation/checkout_screen.dart';
import '../../features/customer/presentation/order_detail_screen.dart';
import '../../features/customer/presentation/order_placed_screen.dart';
import '../../features/customer/presentation/orders_screen.dart';
import '../../features/customer/presentation/payment_screen.dart';
import '../../features/customer/presentation/home_screen.dart';
import '../../features/customer/presentation/restaurant_screen.dart';
import '../../features/rider/presentation/rider_dashboard_screen.dart';
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
            GoRoute(path: '/c/orders', builder: (_, _) => const OrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/c/profile', builder: (_, _) => const CustomerProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/c/restaurant/:id',
        builder: (_, state) => RestaurantScreen(
          restaurantId: int.parse(state.pathParameters['id']!),
          initial: state.extra is Restaurant ? state.extra as Restaurant : null,
        ),
      ),
      GoRoute(path: '/c/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/c/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/c/pay',
        builder: (_, state) => PaymentScreen(args: state.extra! as PaymentArgs),
      ),
      GoRoute(
        path: '/c/order-placed/:id',
        builder: (_, state) => OrderPlacedScreen(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/c/order/:id',
        builder: (_, state) => OrderDetailScreen(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/c/addresses', builder: (_, _) => const AddressesScreen()),
      GoRoute(path: '/c/favorites', builder: (_, _) => const FavoritesScreen()),

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
