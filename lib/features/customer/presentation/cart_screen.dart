import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/customer_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final ctl = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(cart.restaurantName ?? 'Your cart'),
        actions: [
          if (!cart.isEmpty) TextButton(onPressed: ctl.clear, child: const Text('Clear')),
        ],
      ),
      body: cart.isEmpty
          ? const EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              subtitle: 'Add something tasty from a restaurant.',
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final line in cart.lines)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(formatNaira(line.total)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => ctl.decrease(line.item.id),
                          ),
                          Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.violet),
                            onPressed: () => ctl.increase(line.item.id),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: Theme.of(context).textTheme.titleMedium),
                    Text(formatNaira(cart.subtotal), style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Delivery fee is calculated at checkout.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: CtaButton(
                  label: 'Checkout',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checkout is coming in the next step.')),
                  ),
                ),
              ),
            ),
    );
  }
}
