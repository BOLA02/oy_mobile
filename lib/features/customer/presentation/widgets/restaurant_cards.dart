import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui.dart';
import '../../application/customer_providers.dart';
import '../../domain/restaurant.dart';

/// Heart button that toggles a restaurant as a favourite.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.restaurantId, this.size = 36});

  final int restaurantId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider.select((v) => v.value?.contains(restaurantId) ?? false));
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          HapticFeedback.lightImpact();
          try {
            await ref.read(favoritesProvider.notifier).toggle(restaurantId);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(isFav),
              size: size * 0.55,
              color: isFav ? AppColors.danger : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

String _subtitle(Restaurant r) =>
    [r.type, r.location].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

/// Full-width card used in the main restaurant list.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(tag: 'restaurant-${r.id}', child: AppImage(url: r.imageUrl, label: r.name)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x55000000)],
                      stops: [0.55, 1],
                    ),
                  ),
                ),
                Positioned(top: 10, right: 10, child: FavoriteButton(restaurantId: r.id)),
                if (r.rating != null)
                  Positioned(bottom: 10, left: 10, child: RatingBadge(rating: r.rating!, onDark: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(_subtitle(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (r.deliveryFee != null) ...[
                      const Icon(Icons.two_wheeler_rounded, size: 16, color: AppColors.violet),
                      const SizedBox(width: 4),
                      Text(formatNaira(r.deliveryFee!), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 14),
                    ],
                    if (r.minimumOrder != null && r.minimumOrder! > 0) ...[
                      const Icon(Icons.shopping_bag_outlined, size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Text('Min ${formatNaira(r.minimumOrder!)}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact card for horizontal "popular" rows.
class RestaurantMiniCard extends StatelessWidget {
  const RestaurantMiniCard({super.key, required this.restaurant, required this.onTap});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return SizedBox(
      width: 200,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 118,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(url: r.imageUrl, label: r.name),
                  Positioned(top: 8, right: 8, child: FavoriteButton(restaurantId: r.id, size: 32)),
                  if (r.rating != null) Positioned(bottom: 8, left: 8, child: RatingBadge(rating: r.rating!, onDark: true)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(_subtitle(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                  if (r.deliveryFee != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 15, color: AppColors.violet),
                        const SizedBox(width: 4),
                        Text(formatNaira(r.deliveryFee!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 16 / 8.5, child: Skeleton(height: double.infinity, radius: 0)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(width: 160, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 110, height: 12),
                SizedBox(height: 12),
                Skeleton(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
