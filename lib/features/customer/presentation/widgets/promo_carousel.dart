import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/promo.dart';

/// Swipeable banner row at the top of Home. Falls back to a brand banner when
/// no promos are running so the screen never has an empty gap.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.promos});

  final List<Promo> promos;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  int get _count => widget.promos.isEmpty ? 1 : widget.promos.length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _count < 2 || !_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % _count,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 184,
          child: PageView.builder(
            controller: _controller,
            itemCount: _count,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final promo = widget.promos.isEmpty ? null : widget.promos[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Banner(promo: promo),
              );
            },
          ),
        ),
        if (_count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.violet : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.promo});

  final Promo? promo;

  @override
  Widget build(BuildContext context) {
    final p = promo;
    final title = p?.title ?? 'Better chow,\nno wahala.';
    final subtitle = p?.description ?? 'Order sharp sharp. Chop happy.';

    return GestureDetector(
      onTap: p?.businessId == null ? null : () => context.push('/c/restaurant/${p!.businessId}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (p?.imageUrl != null)
              AppImage(url: p!.imageUrl, label: p.title)
            else
              const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
            // Decorative rings, like the web hero.
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -50,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mango.withValues(alpha: 0.18)),
              ),
            ),
            if (p?.imageUrl != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('OYAEAT',
                      style: TextStyle(
                          color: AppColors.mango, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  if (p?.businessId != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.mango, borderRadius: BorderRadius.circular(20)),
                      child: const Text('Order now',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.ink)),
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
