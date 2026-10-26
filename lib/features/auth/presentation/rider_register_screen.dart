import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/session_controller.dart';

class RiderRegisterScreen extends ConsumerStatefulWidget {
  const RiderRegisterScreen({super.key});

  @override
  ConsumerState<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends ConsumerState<RiderRegisterScreen> {
  static const _vehicles = ['Motorcycle', 'Bicycle', 'Car'];

  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _password = TextEditingController();
  String _vehicle = _vehicles.first;
  XFile? _idDocument;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _plate, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _pickId() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _idDocument = file);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_idDocument == null) {
      showError(context, 'Please upload a photo of your ID.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).registerRider(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            vehicleType: _vehicle,
            plateNumber: _plate.text.trim(),
            password: _password.text,
            idDocumentPath: _idDocument!.path,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Application received'),
          content: const Text(
            'Your account has been created. You can log in now, but you can only '
            'accept deliveries once our team has verified your ID.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride with OyaEat')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(controller: _first, decoration: const InputDecoration(labelText: 'First name'), validator: _required),
              const SizedBox(height: 14),
              TextFormField(controller: _last, decoration: const InputDecoration(labelText: 'Last name'), validator: _required),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: _required,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _vehicle,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [for (final v in _vehicles) DropdownMenuItem(value: v, child: Text(v))],
                onChanged: (v) => setState(() => _vehicle = v ?? _vehicle),
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _plate, decoration: const InputDecoration(labelText: 'Plate number (optional)')),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password (min 6 characters)'),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _pickId,
                icon: Icon(_idDocument == null ? Icons.upload_file : Icons.check_circle, color: AppColors.violet),
                label: Text(_idDocument == null ? 'Upload ID photo' : 'ID photo selected'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 24),
              CtaButton(label: 'Submit application', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
