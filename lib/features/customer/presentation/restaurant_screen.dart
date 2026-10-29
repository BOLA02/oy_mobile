import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/customer_providers.dart';
import '../domain/restaurant.dart';
import 'widgets/restaurant_cards.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, required this.restaurantId, this.initial});

  final int restaurantId;

  /// Passed from the list so the header can show instantly while the menu loads.
  final Restaurant? initial;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  static const _expandedHeight = 250.0;

  final _scroll = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  String? _activeCategory;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // The name moves into the app bar only once the photo has scrolled away.
    _scroll.addListener(() {
      final collapsed = _scroll.hasClients && _scroll.offset > _expandedHeight - kToolbarHeight - 24;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _jumpTo(String category) async {
    setState(() => _activeCategory = category);
    final ctx = _sectionKeys[category]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic, alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final cart = ref.watch(cartProvider);
    final restaurant = menuAsync.value?.restaurant ?? widget.initial;

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _Header(restaurant: restaurant, restaurantId: widget.restaurantId, collapsed: _collapsed, expandedHeight: _expandedHeight),
          if (restaurant != null) SliverToBoxAdapter(child: _Info(restaurant: restaurant)),
          ...menuAsync.when(
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, _) => const _MenuTileSkeleton(),
                ),
              ),
            ],
            error: (e, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(message: '$e', onRetry: () => ref.invalidate(restaurantMenuProvider(widget.restaurantId))),
              ),
            ],
            data: (m) => _menuSlivers(m),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _CartBar(restaurantId: widget.restaurantId, visible: !cart.isEmpty && cart.restaurantId == widget.restaurantId),
    );
  }

  List<Widget> _menuSlivers(RestaurantMenu m) {
    if (m.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.restaurant_menu_rounded,
            title: 'No dishes yet',
            subtitle: 'This restaurant has not published its menu.',
          ),
        ),
      ];
    }
    final groups = m.byCategory;
    for (final k in groups.keys) {
      _sectionKeys.putIfAbsent(k, GlobalKey.new);
    }
    final active = _activeCategory ?? groups.keys.first;

    return [
      if (groups.length > 1)
        SliverPersistentHeader(
          pinned: true,
          delegate: _CategoryBarDelegate(
            categories: groups.keys.toList(),
            active: active,
            onTap: _jumpTo,
          ),
        ),
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            key: _sectionKeys[entry.key],
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text(entry.key, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MenuTile(restaurant: m.restaurant, item: entry.value[i]),
          ),
        ),
      ],
    ];
  }
}

// ── Collapsing photo header ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.restaurant, required this.restaurantId, required this.collapsed, required this.expandedHeight});

  final Restaurant? restaurant;
  final int restaurantId;
  final bool collapsed;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    Widget circle(IconData icon, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 2,
            shadowColor: Colors.black26,
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Icon(icon, size: 20, color: AppColors.ink)),
          ),
        );

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: 56,
      leading: circle(Icons.arrow_back_rounded, () => context.pop()),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
          child: FavoriteButton(restaurantId: restaurantId, size: 38),
        ),
      ],
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: collapsed ? 1 : 0,
        child: Text(restaurant?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'restaurant-$restaurantId',
              child: AppImage(url: restaurant?.imageUrl, label: restaurant?.name ?? ''),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Colors.transparent, Color(0x33000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Name, rating and key facts ──────────────────────────────────────────

class _Info extends StatelessWidget {
  const _Info({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final hours = (r.openingHour != null && r.closingHour != null) ? '${r.openingHour} – ${r.closingHour}' : null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.name, style: Theme.of(context).textTheme.headlineMedium)),
              if (r.rating != null) RatingBadge(rating: r.rating!),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [r.typeLabel, r.location].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          if (r.reviewCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${r.reviewCount} review${r.reviewCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5)),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (r.deliveryFee != null) _Fact(icon: Icons.two_wheeler_rounded, text: 'From ${formatNaira(r.deliveryFee!)}'),
              if (r.minimumOrder != null && r.minimumOrder! > 0)
                _Fact(icon: Icons.shopping_bag_outlined, text: 'Min ${formatNaira(r.minimumOrder!)}'),
              if (hours != null) _Fact(icon: Icons.schedule_rounded, text: hours),
            ],
          ),
          if (r.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(r.description!.trim(), style: const TextStyle(color: AppColors.inkMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Sticky category chips ───────────────────────────────────────────────

class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  _CategoryBarDelegate({required this.categories, required this.active, required this.onTap});

  final List<String> categories;
  final String active;
  final ValueChanged<String> onTap;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: overlapsContent ? AppColors.border : Colors.transparent)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          final selected = c == active;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(c,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : AppColors.primary)),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryBarDelegate old) => old.active != active || old.categories != categories;
}

// ── Menu items ──────────────────────────────────────────────────────────

class _MenuTile extends ConsumerWidget {
  const _MenuTile({required this.restaurant, required this.item});

  final Restaurant restaurant;
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.lines.where((l) => l.item.id == item.id).fold(0, (n, l) => n + l.quantity)));

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: () => showAddToCartSheet(context, ref, restaurant, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                if (item.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(item.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5, height: 1.3)),
                ],
                const SizedBox(height: 10),
                Text(formatNaira(item.price),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: AppImage(url: item.imageUrl, label: item.name),
                  ),
                ),
                Positioned(
                  right: -6,
                  bottom: -8,
                  child: qty == 0
                      ? Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          shadowColor: Colors.black26,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await addWithConfirm(context, ref, restaurant, item);
                            },
                            child: const SizedBox(width: 36, height: 36, child: Icon(Icons.add_rounded, color: AppColors.primary)),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppShadows.pop,
                          ),
                          child: Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTileSkeleton extends StatelessWidget {
  const _MenuTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(width: 140, height: 15),
                SizedBox(height: 8),
                Skeleton(height: 11),
                SizedBox(height: 6),
                Skeleton(width: 100, height: 11),
                SizedBox(height: 12),
                Skeleton(width: 70, height: 14),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Skeleton(width: 96, height: 96, radius: AppRadius.md),
        ],
      ),
    );
  }
}

// ── Adding to the cart ──────────────────────────────────────────────────

/// Adds one item, first asking if the cart would be replaced. Returns whether it was added.
Future<bool> addWithConfirm(BuildContext context, WidgetRef ref, Restaurant restaurant, MenuItem item, {int quantity = 1}) async {
  final cart = ref.read(cartProvider.notifier);
  if (cart.wouldReplace(restaurant.id)) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new cart?'),
        content: const Text('Your cart has items from another restaurant. Adding this will clear it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep cart')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start new')),
        ],
      ),
    );
    if (ok != true) return false;
  }
  cart.add(restaurant, item, quantity: quantity);
  return true;
}

Future<void> showAddToCartSheet(BuildContext context, WidgetRef ref, Restaurant restaurant, MenuItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddToCartSheet(restaurant: restaurant, item: item),
  );
}

class _AddToCartSheet extends ConsumerStatefulWidget {
  const _AddToCartSheet({required this.restaurant, required this.item});

  final Restaurant restaurant;
  final MenuItem item;

  @override
  ConsumerState<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<_AddToCartSheet> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl?.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: AspectRatio(aspectRatio: 16 / 9, child: AppImage(url: item.imageUrl, label: item.name)),
              ),
            const SizedBox(height: 16),
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            if (item.description?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(item.description!.trim(), style: const TextStyle(color: AppColors.inkMuted, height: 1.4)),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(formatNaira(item.price), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                const Spacer(),
                QuantityStepper(
                  quantity: _qty,
                  onAdd: () => setState(() => _qty++),
                  onRemove: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CtaButton(
              label: 'Add to cart · ${formatNaira(item.price * _qty)}',
              onPressed: () async {
                final nav = Navigator.of(context);
                final added = await addWithConfirm(context, ref, widget.restaurant, item, quantity: _qty);
                if (added) nav.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating cart bar ───────────────────────────────────────────────────

class _CartBar extends ConsumerWidget {
  const _CartBar({required this.restaurantId, required this.visible});

  final int restaurantId;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim),
        child: child,
      ),
      child: !visible
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : SafeArea(
              key: const ValueKey('bar'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: CtaButton(
                  label: 'View cart · ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} · ${formatNaira(cart.subtotal)}',
                  onPressed: () => context.push('/c/cart'),
                ),
              ),
            ),
    );
  }
}
