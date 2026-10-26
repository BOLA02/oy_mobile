import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/customer_providers.dart';
import '../domain/restaurant.dart';

class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(restaurantMenuProvider(restaurantId));
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: Text(menu.value?.restaurant.name ?? 'Menu')),
      body: menu.whenView(
        onRetry: () => ref.invalidate(restaurantMenuProvider(restaurantId)),
        data: (m) {
          if (m.items.isEmpty) {
            return const EmptyView(
              icon: Icons.restaurant_menu,
              title: 'No dishes yet',
              subtitle: 'This restaurant has not published its menu.',
            );
          }
          final groups = m.byCategory.entries.toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              if (m.restaurant.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(m.restaurant.description!, style: const TextStyle(color: AppColors.inkMuted)),
                ),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(g.key, style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final item in g.value)
                  _MenuTile(
                    item: item,
                    onAdd: () => _add(context, ref, m.restaurant, item),
                  ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty || cart.restaurantId != restaurantId
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: CtaButton(
                  label: 'View cart · ${cart.itemCount} · ${formatNaira(cart.subtotal)}',
                  onPressed: () => context.push('/c/cart'),
                ),
              ),
            ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Restaurant restaurant, MenuItem item) async {
    final cart = ref.read(cartProvider.notifier);
    if (cart.wouldReplace(restaurant.id)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: const Text('Your cart has items from another restaurant. Adding this will clear it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep cart')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start new')),
          ],
        ),
      );
      if (ok != true) return;
    }
    cart.add(restaurant, item);
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.onAdd});

  final MenuItem item;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.imageUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(width: 70, height: 70),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (item.description?.isNotEmpty == true)
                    Text(item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(formatNaira(item.price),
                      style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Add ${item.name}',
            ),
          ],
        ),
      ),
    );
  }
}
