import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/customer_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear cart?'),
                    content: const Text('All items will be removed.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) ctl.clear();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyView(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Your cart is empty',
                    subtitle: 'Add something tasty from a restaurant.',
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                    onPressed: () => context.go('/c/home'),
                    child: const Text('Browse restaurants'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cart.restaurantName ?? '', style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 14),
                for (final line in cart.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey(line.item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.lg)),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ctl.remove(line.item.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text('${line.item.name} removed'),
                            action: SnackBarAction(label: 'Undo', textColor: AppColors.accent, onPressed: () => ctl.restore(line)),
                          ));
                      },
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(width: 60, height: 60, child: AppImage(url: line.item.imageUrl, label: line.item.name)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(line.item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(formatNaira(line.total),
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            QuantityStepper(
                              compact: true,
                              quantity: line.quantity,
                              onAdd: () => ctl.increase(line.item.id),
                              onRemove: () => ctl.decrease(line.item.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add more items'),
                ),
                const SizedBox(height: 8),
                if (cart.shortfall > 0)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add ${formatNaira(cart.shortfall)} more to reach the ${formatNaira(cart.minimumOrder ?? 0)} minimum order.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                SurfaceCard(
                  child: Column(
                    children: [
                      _SummaryRow('Subtotal', formatNaira(cart.subtotal)),
                      const SizedBox(height: 10),
                      const _SummaryRow('Delivery fee', 'Calculated at checkout', muted: true),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: CtaButton(
                  label: 'Checkout · ${formatNaira(cart.subtotal)}',
                  onPressed: cart.shortfall > 0 ? null : () => context.push('/c/checkout'),
                ),
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.inkMuted)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: muted ? AppColors.inkMuted : AppColors.ink)),
      ],
    );
  }
}
