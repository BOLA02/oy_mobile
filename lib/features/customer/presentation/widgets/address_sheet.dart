import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/async_view.dart';
import '../../../../shared/widgets/cta_button.dart';
import '../../../../shared/widgets/ui.dart';
import '../../application/customer_providers.dart';
import '../../domain/address.dart';

/// Lets the customer pick a saved address or add a new one.
/// Resolves to the chosen address, or null if dismissed.
Future<SavedAddress?> showAddressPicker(BuildContext context, {int? selectedId}) {
  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddressPicker(selectedId: selectedId),
  );
}

Future<SavedAddress?> showAddAddressSheet(BuildContext context) {
  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddAddressForm(),
  );
}

class _AddressPicker extends ConsumerWidget {
  const _AddressPicker({this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deliver to', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Flexible(
                child: addresses.when(
                  loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(addressesProvider)),
                  data: (list) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AddressTile(address: a, selected: a.id == selectedId, onTap: () => Navigator.pop(context, a)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final created = await showAddAddressSheet(context);
                  if (created != null) {
                    ref.invalidate(addressesProvider);
                    nav.pop(created);
                  }
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a new address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address, required this.selected, required this.onTap});

  final SavedAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.violet : AppColors.border, width: selected ? 1.8 : 1),
          color: selected ? AppColors.violetSoft : Colors.white,
        ),
        child: Row(
          children: [
            Icon(address.label.toLowerCase() == 'work' ? Icons.work_outline_rounded : Icons.home_outlined, color: AppColors.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        const StatusPill(label: 'Default', color: AppColors.violet, background: AppColors.violetSoft),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(address.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                  if (!address.hasLocation)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('No map pin: delivery fee is an estimate',
                          style: TextStyle(color: AppColors.mangoDeep, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.violet),
          ],
        ),
      ),
    );
  }
}

class _AddAddressForm extends ConsumerStatefulWidget {
  const _AddAddressForm();

  @override
  ConsumerState<_AddAddressForm> createState() => _AddAddressFormState();
}

class _AddAddressFormState extends ConsumerState<_AddAddressForm> {
  static const _labels = ['Home', 'Work', 'Other'];

  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  String _label = _labels.first;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await currentDeviceLocation();
      setState(() {
        _lat = loc.latitude;
        _lng = loc.longitude;
        if (loc.address != null && _address.text.trim().isEmpty) _address.text = loc.address!;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = ref.read(addressesProvider).value ?? const [];
      final created = await ref.read(customerRepositoryProvider).addAddress(
            label: _label,
            address: _address.text.trim(),
            latitude: _lat,
            longitude: _lng,
            isDefault: existing.isEmpty,
          );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New address', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in _labels)
                      ChoiceChip(
                        label: Text(l),
                        selected: _label == l,
                        selectedColor: AppColors.violet,
                        labelStyle: TextStyle(color: _label == l ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _label = l),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _address,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Street, area and landmark'),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Enter your full address' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded),
                  label: Text(_lat == null ? 'Pin my current location' : 'Location pinned'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Pinning gives you an accurate delivery fee and lets your rider find you.',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                ),
                const SizedBox(height: 18),
                CtaButton(label: 'Save address', loading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
