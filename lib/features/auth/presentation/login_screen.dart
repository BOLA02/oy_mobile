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
    FocusScope.of(context).unfocus();
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
      backgroundColor: AppColors.violetDeep,
      body: Column(
        children: [
          // ── Brand header ──
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              children: [
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient))),
                Positioned(
                  right: -50,
                  top: -30,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: 10,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mango.withValues(alpha: 0.16)),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: AppColors.mango, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.ramen_dining_rounded, color: AppColors.ink),
                            ),
                            const SizedBox(width: 12),
                            Text('OyaEat', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('Better chow,\nno wahala.',
                            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontSize: 34)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Form sheet ──
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          children: [
                            _RoleTab(
                              icon: Icons.restaurant_menu_rounded,
                              label: 'Customer',
                              selected: isCustomer,
                              onTap: () => setState(() {
                                _role = AppRole.customer;
                                _identifier.clear();
                              }),
                            ),
                            _RoleTab(
                              icon: Icons.two_wheeler_rounded,
                              label: 'Rider',
                              selected: !isCustomer,
                              onTap: () => setState(() {
                                _role = AppRole.rider;
                                _identifier.clear();
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(isCustomer ? 'Welcome back' : 'Ready to ride?', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(isCustomer ? 'Log in to order your favourite meals.' : 'Log in to start accepting deliveries.',
                          style: const TextStyle(color: AppColors.inkMuted)),
                      const SizedBox(height: 20),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _identifier,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              decoration: InputDecoration(
                                labelText: isCustomer ? 'Email or phone' : 'Email',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push(isCustomer ? '/signup' : '/rider-register'),
                        child: Text(isCustomer ? 'New here? Create an account' : 'Want to ride with us? Register as a rider'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.violet : AppColors.inkMuted),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.violet : AppColors.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
