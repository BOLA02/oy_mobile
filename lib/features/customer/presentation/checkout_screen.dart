import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/format.dart';
import '../../../core/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/customer_providers.dart';
import '../data/customer_repository.dart';
import '../domain/address.dart';
import 'payment_screen.dart';
import 'widgets/address_sheet.dart';

enum PaymentMethod { online, cash }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  SavedAddress? _picked;
  PaymentMethod _method = PaymentMethod.online;
  bool _prefilled = false;
  bool _submitting = false;
  bool _pinning = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  SavedAddress? _effectiveAddress(List<SavedAddress> saved) {
    if (_picked != null) return _picked;
    if (saved.isEmpty) return null;
    return saved.firstWhere((a) => a.isDefault, orElse: () => saved.first);
  }

  Future<void> _chooseAddress(SavedAddress? current) async {
    final chosen = await showAddressPicker(context, selectedId: current?.id);
    if (chosen != null) setState(() => _picked = chosen);
  }

  /// Saves the current GPS position as an address so the fee can be quoted exactly.
  Future<void> _pinCurrentLocation() async {
    setState(() => _pinning = true);
    try {
      final loc = await currentDeviceLocation();
      final created = await ref.read(customerRepositoryProvider).addAddress(
            label: 'Current location',
            address: loc.address ?? 'Pinned location (${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})',
            latitude: loc.latitude,
            longitude: loc.longitude,
            isDefault: (ref.read(addressesProvider).value ?? const []).isEmpty,
          );
      ref.invalidate(addressesProvider);
      setState(() => _picked = created);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  Future<void> _place(SavedAddress? address, DeliveryQuote? quote) async {
    if (address == null) {
      showError(context, 'Choose where we should deliver.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (quote == null) {
      showError(context, 'Waiting for the delivery fee. Try again in a moment.');
      return;
    }

    final cart = ref.read(cartProvider);
    final repo = ref.read(customerRepositoryProvider);
    final details = CheckoutDetails(
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      address: address.address,
      notes: _notes.text,
      latitude: address.latitude,
      longitude: address.longitude,
    );

    setState(() => _submitting = true);
    try {
      if (_method == PaymentMethod.cash) {
        final order = await repo.placeCashOrder(cart, details);
        _finish(order.id);
        return;
      }

      final profile = await ref.read(profileProvider.future);
      final start = await repo.startOnlinePayment(cart, details, email: profile.email, callbackUrl: Env.paymentCallbackUrl);
      await _payOnline(start);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Opens Paystack. If the customer leaves without paying they can retry or cancel.
  Future<void> _payOnline(PaymentStart start) async {
    while (true) {
      if (!mounted) return;
      final paid = await context.push<bool>(
        '/c/pay',
        extra: PaymentArgs(
          authorizationUrl: start.authorizationUrl,
          reference: start.reference,
          callbackUrl: Env.paymentCallbackUrl,
        ),
      );
      if (!mounted) return;
      if (paid == true) {
        _finish(start.order.id);
        return;
      }

      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment not completed'),
          content: const Text('We have not received your payment. You can try again or cancel this order.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel order')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
      if (retry == true) continue;

      try {
        await ref.read(customerRepositoryProvider).cancelOrder(start.order.id);
      } catch (_) {
        // Already cancelled or not cancellable; the order list shows the truth.
      }
      return;
    }
  }

  void _finish(int orderId) {
    ref.read(cartProvider.notifier).clear();
    ref.invalidate(ordersProvider);
    if (!mounted) return;
    // Home underneath, confirmation on top: Back from anywhere after this lands on Home.
    context.go('/c/home');
    context.push('/c/order-placed/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final saved = ref.watch(addressesProvider);
    final profile = ref.watch(profileProvider);

    if (!_prefilled && profile.hasValue) {
      _prefilled = true;
      _name.text = profile.value!.fullName;
      _phone.text = profile.value!.phone;
    }

    // Leaving after the cart was cleared (e.g. order placed) should not show an empty form.
    if (cart.isEmpty || cart.restaurantId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const EmptyView(icon: Icons.shopping_bag_outlined, title: 'Your cart is empty'),
      );
    }

    final address = _effectiveAddress(saved.value ?? const []);
    final quote = ref.watch(deliveryQuoteProvider((
      businessId: cart.restaurantId!,
      latitude: address?.latitude,
      longitude: address?.longitude,
    )));
    final fee = quote.value?.fee;
    final total = fee == null ? null : cart.subtotal + fee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _Section(
              title: 'Delivery address',
              child: saved.when(
                loading: () => const Skeleton(height: 64, radius: AppRadius.md),
                error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(addressesProvider)),
                data: (_) => address == null
                    ? OutlinedButton.icon(
                        onPressed: () => _chooseAddress(null),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add delivery address'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => _chooseAddress(address),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Icon(Icons.location_on_rounded, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(address.address,
                                          maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          if (!address.hasLocation) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Pin your location for an exact delivery fee.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  ),
                                  TextButton(
                                    onPressed: _pinning ? null : _pinCurrentLocation,
                                    child: _pinning
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('Pin now'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            _Section(
              title: 'Contact',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Your name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number', helperText: 'Your rider will call this number'),
                    validator: (v) => (v == null || v.trim().length < 7) ? 'Enter a valid phone number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Note for the restaurant (optional)'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Payment',
              child: Column(
                children: [
                  _MethodTile(
                    icon: Icons.credit_card_rounded,
                    title: 'Pay online',
                    subtitle: 'Card, bank transfer or USSD',
                    selected: _method == PaymentMethod.online,
                    onTap: () => setState(() => _method = PaymentMethod.online),
                  ),
                  const SizedBox(height: 10),
                  _MethodTile(
                    icon: Icons.payments_outlined,
                    title: 'Cash on delivery',
                    subtitle: 'Pay your rider when the food arrives',
                    selected: _method == PaymentMethod.cash,
                    onTap: () => setState(() => _method = PaymentMethod.cash),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Order summary',
              child: Column(
                children: [
                  for (final l in cart.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l.quantity}×', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l.item.name)),
                          Text(formatNaira(l.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _Line('Subtotal', formatNaira(cart.subtotal)),
                  const SizedBox(height: 8),
                  quote.when(
                    loading: () => const _Line('Delivery fee', null),
                    error: (e, _) => Row(
                      children: [
                        const Expanded(child: Text("Couldn't work out the delivery fee", style: TextStyle(color: AppColors.danger))),
                        TextButton(onPressed: () => ref.invalidate(deliveryQuoteProvider), child: const Text('Retry')),
                      ],
                    ),
                    data: (q) => _Line(
                      q.distanceKm == null ? 'Delivery fee' : 'Delivery fee · ${q.distanceKm!.toStringAsFixed(1)} km',
                      formatNaira(q.fee),
                    ),
                  ),
                  const Divider(height: 24),
                  _Line('Total', total == null ? null : formatNaira(total), bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: CtaButton(
            label: total == null
                ? 'Place order'
                : _method == PaymentMethod.online
                    ? 'Pay ${formatNaira(total)}'
                    : 'Place order · ${formatNaira(total)}',
            loading: _submitting,
            onPressed: total == null ? null : () => _place(address, quote.value),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          SurfaceCard(child: child),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.8 : 1),
          color: selected ? AppColors.primarySoft : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String? value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: bold ? style : const TextStyle(color: AppColors.inkMuted)),
        value == null ? const Skeleton(width: 70, height: 14) : Text(value!, style: style),
      ],
    );
  }
}
