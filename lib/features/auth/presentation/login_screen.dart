import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  AppRole _role = AppRole.customer;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final id = _identifier.text.trim();
      final session = _role == AppRole.customer
          ? await repo.loginCustomer(emailOrPhone: id, password: _password.text)
          : await repo.loginRider(email: id, password: _password.text);
      // The router redirects to the right half of the app once signed in.
      await ref.read(sessionControllerProvider.notifier).signIn(session);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = _role == AppRole.customer;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text('OyaEat', style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.violet)),
            const SizedBox(height: 4),
            const Text('Order sharp sharp. Chop happy.', style: TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: 28),
            SegmentedButton<AppRole>(
              segments: const [
                ButtonSegment(value: AppRole.customer, label: Text('Customer'), icon: Icon(Icons.restaurant_menu)),
                ButtonSegment(value: AppRole.rider, label: Text('Rider'), icon: Icon(Icons.two_wheeler)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() {
                _role = s.first;
                _identifier.clear();
              }),
            ),
            const SizedBox(height: 24),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _identifier,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(labelText: isCustomer ? 'Email or phone' : 'Email'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CtaButton(label: 'Log in', loading: _loading, onPressed: _submit),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push(isCustomer ? '/signup' : '/rider-register'),
              child: Text(isCustomer ? 'New here? Create an account' : 'Want to ride with us? Register as a rider'),
            ),
          ],
        ),
      ),
    );
  }
}
