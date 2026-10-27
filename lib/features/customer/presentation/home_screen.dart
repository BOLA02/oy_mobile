import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/customer_providers.dart';
import '../domain/restaurant.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/restaurant_cards.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(promosProvider);
    ref.invalidate(restaurantsProvider);
    await ref.read(restaurantsProvider.future);
  }

  void _openRestaurant(Restaurant r) => context.push('/c/restaurant/${r.id}', extra: r);

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsProvider);
    final cuisine = ref.watch(selectedCuisineProvider);
    final name = ref.watch(sessionControllerProvider).value?.name?.split(' ').first;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.violet,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(), style: const TextStyle(color: AppColors.inkMuted, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('${name == null ? 'Hungry?' : 'Hi, $name'} 👋',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => context.push('/c/favorites'),
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                        icon: const Icon(Icons.favorite_border_rounded, color: AppColors.violet),
                        tooltip: 'Favourites',
                      ),
                      const SizedBox(width: 4),
                      Consumer(builder: (context, ref, _) {
                        final count = ref.watch(cartProvider.select((c) => c.itemCount));
                        return IconButton.filledTonal(
                          onPressed: () => context.push('/c/cart'),
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            backgroundColor: AppColors.mango,
                            textColor: AppColors.ink,
                            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.violet),
                          ),
                          tooltip: 'Cart',
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ── Search ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: AppShadows.card,
                    ),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search restaurants or cuisines',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
                        suffixIcon: ListenableBuilder(
                          listenable: _search,
                          builder: (_, _) => _search.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    ref.read(restaurantQueryProvider.notifier).set('');
                                  },
                                ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (v) => ref.read(restaurantQueryProvider.notifier).set(v),
                    ),
                  ),
                ),
              ),

              // ── Promos ──────────────────────────────────
              SliverToBoxAdapter(
                child: ref.watch(promosProvider).when(
                      data: (promos) => PromoCarousel(promos: promos),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Skeleton(height: 184, radius: AppRadius.lg),
                      ),
                      // Promos are decoration: if they fail, show the brand banner.
                      error: (_, _) => const PromoCarousel(promos: []),
                    ),
              ),

              ...restaurants.when(
                loading: () => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        children: const [
                          RestaurantCardSkeleton(),
                          SizedBox(height: 16),
                          RestaurantCardSkeleton(),
                        ],
                      ),
                    ),
                  ),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(message: '$e', onRetry: () => ref.invalidate(restaurantsProvider)),
                  ),
                ],
                data: (all) => _content(all, cuisine),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<Restaurant> all, String? cuisine) {
    if (all.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.storefront_outlined,
            title: 'No restaurants found',
            subtitle: 'Try a different search, or check back soon.',
          ),
        ),
      ];
    }

    final cuisines = {
      for (final r in all)
        if (r.type?.trim().isNotEmpty == true) r.type!.trim(),
    }.toList()
      ..sort();

    final filtered = cuisine == null ? all : all.where((r) => r.type?.trim() == cuisine).toList();
    final popular = ([...all]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0))).take(6).toList();
    final showPopular = cuisine == null && ref.read(restaurantQueryProvider).trim().isEmpty && popular.length > 1;

    return [
      if (cuisines.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CuisineChip(
                    label: 'All',
                    selected: cuisine == null,
                    onTap: () => ref.read(selectedCuisineProvider.notifier).set(null),
                  ),
                  for (final c in cuisines)
                    _CuisineChip(
                      label: businessTypeLabel(c),
                      selected: cuisine == c,
                      onTap: () => ref.read(selectedCuisineProvider.notifier).set(c),
                    ),
                ],
              ),
            ),
          ),
        ),
      if (showPopular) ...[
        const SliverToBoxAdapter(child: SectionHeader(title: 'Popular near you')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 226,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: popular.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => RestaurantMiniCard(restaurant: popular[i], onTap: () => _openRestaurant(popular[i])),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: SectionHeader(title: cuisine == null ? 'All restaurants' : businessTypeLabel(cuisine)),
      ),
      if (filtered.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyView(icon: Icons.search_off_rounded, title: 'Nothing here yet', subtitle: 'Try another cuisine.'),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => RestaurantCard(restaurant: filtered[i], onTap: () => _openRestaurant(filtered[i])),
          ),
        ),
    ];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _CuisineChip extends StatelessWidget {
  const _CuisineChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: selected ? null : AppShadows.card,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? Colors.white : AppColors.ink,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
