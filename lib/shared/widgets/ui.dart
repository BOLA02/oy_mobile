import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';

/// Rounded white surface with a soft shadow. The default container of the app.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.margin,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Shimmering placeholder box for loading states.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEAE6F2),
      highlightColor: const Color(0xFFF7F4FC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

/// Network image with a soft placeholder and an initials fallback, so a
/// missing photo never leaves a hole.
class AppImage extends StatelessWidget {
  const AppImage({super.key, required this.url, required this.label, this.fit = BoxFit.cover});

  final String? url;
  final String label;
  final BoxFit fit;

  String get _initials => label
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      alignment: Alignment.center,
      child: Text(
        _initials.isEmpty ? '·' : _initials,
        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => Container(color: AppColors.violetSoft),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Small coloured pill, used for order statuses and tags.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// − 2 + control used in the menu, cart and add-to-cart sheet.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.quantity, required this.onAdd, required this.onRemove, this.compact = false});

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 40.0;
    Widget btn(IconData icon, VoidCallback onTap, {bool filled = false}) => SizedBox(
          width: size,
          height: size,
          child: Material(
            color: filled ? AppColors.violet : AppColors.violetSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Icon(icon, size: compact ? 18 : 20, color: filled ? Colors.white : AppColors.violet),
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove_rounded, onRemove),
        SizedBox(
          width: compact ? 30 : 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              '$quantity',
              key: ValueKey(quantity),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 15 : 17),
            ),
          ),
        ),
        btn(Icons.add_rounded, onAdd, filled: true),
      ],
    );
  }
}

/// Rating star + number, e.g. "★ 4.6".
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.onDark = false});

  final double rating;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : AppColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 15, color: AppColors.mangoDeep),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}


/// Back arrow that always works: it pops when it can, and otherwise (e.g. the
/// screen was opened as the first page) goes to [fallback] instead of doing
/// nothing.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}
