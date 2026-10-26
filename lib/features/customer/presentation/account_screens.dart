import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/customer_providers.dart';
import '../domain/address.dart';
import 'widgets/address_sheet.dart';
import 'widgets/restaurant_cards.dart';

/// The customer's "Profile" tab.
class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final session = ref.watch(sessionControllerProvider).value;
    final name = profile.value?.fullName ?? session?.name ?? 'Your account';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.mango,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      if (profile.value != null) ...[
                        const SizedBox(height: 2),
                        Text(profile.value!.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        Text(profile.value!.phone, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Tile(icon: Icons.receipt_long_outlined, title: 'My orders', onTap: () => context.go('/c/orders')),
                const Divider(indent: 56),
                _Tile(icon: Icons.location_on_outlined, title: 'Saved addresses', onTap: () => context.push('/c/addresses')),
                const Divider(indent: 56),
                _Tile(icon: Icons.favorite_border_rounded, title: 'Favourite restaurants', onTap: () => context.push('/c/favorites')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: _Tile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              color: AppColors.danger,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                    ],
                  ),
                );
                if (ok == true) {
                  ref.read(cartProvider.notifier).clear();
                  await ref.read(sessionControllerProvider.notifier).signOut();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.violet),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: color == null ? const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint) : null,
      onTap: onTap,
    );
  }
}

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: addresses.whenView(
        onRetry: () => ref.invalidate(addressesProvider),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.location_off_outlined,
                title: 'No saved addresses',
                subtitle: 'Add one to check out faster.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _AddressCard(address: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await showAddAddressSheet(context);
          if (created != null) ref.invalidate(addressesProvider);
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});

  final SavedAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(customerRepositoryProvider);
    return SurfaceCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.violetSoft,
            child: Icon(address.label.toLowerCase() == 'work' ? Icons.work_outline_rounded : Icons.home_outlined, color: AppColors.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      const StatusPill(label: 'Default', color: AppColors.violet, background: AppColors.violetSoft),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.address, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              try {
                if (v == 'default') await repo.makeDefaultAddress(address.id);
                if (v == 'delete') await repo.deleteAddress(address.id);
                ref.invalidate(addressesProvider);
              } catch (e) {
                if (context.mounted) showError(context, e);
              }
            },
            itemBuilder: (_) => [
              if (!address.isDefault) const PopupMenuItem(value: 'default', child: Text('Make default')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRestaurantsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favorites.whenView(
        onRetry: () => ref.invalidate(favoriteRestaurantsProvider),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.favorite_border_rounded,
                title: 'No favourites yet',
                subtitle: 'Tap the heart on a restaurant to save it here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (_, i) => RestaurantCard(
                  restaurant: list[i],
                  onTap: () => context.push('/c/restaurant/${list[i].id}', extra: list[i]),
                ),
              ),
      ),
    );
  }
}
