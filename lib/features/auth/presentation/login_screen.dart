import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/session_controller.dart';
import '../domain/session.dart';

/// One sign-in for everyone. Customers and riders are told apart by their
/// account, not by a switch; the role is only chosen when signing up.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
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
      final storage = ref.read(sessionStorageProvider);
      final last = await storage.readLastRole();
      final preferred = AppRole.values.where((r) => r.name == last).firstOrNull;
      final session = await ref
          .read(authRepositoryProvider)
          .login(identifier: _identifier.text, password: _password.text, preferred: preferred);
      // The router sends each role to its own half of the app once signed in.
      await ref.read(sessionControllerProvider.notifier).signIn(session);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForgotPasswordSheet(initial: _identifier.text.contains('@') ? _identifier.text.trim() : ''),
    );
    if (email == null || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.violet, size: 36),
          title: const Text('Check your email'),
          content: const Text(
            "If that address is registered, we've sent a link to reset your password. "
            'Open it, choose a new password, then come back and log in.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        Image.asset('assets/brand/logo_white.png', height: 58, fit: BoxFit.contain, alignment: Alignment.centerLeft),
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
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Welcome back', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      const Text('Log in to order food or start delivering.', style: TextStyle(color: AppColors.inkMuted)),
                      const SizedBox(height: 22),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _identifier,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: 'Email or phone',
                                prefixIcon: Icon(Icons.person_outline_rounded),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
                      ),
                      const SizedBox(height: 4),
                      CtaButton(label: 'Log in', loading: _loading, onPressed: _submit),
                      const SizedBox(height: 22),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('New to OyaEat?', style: TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: () => context.push('/join'), child: const Text('Create an account')),
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

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initial});

  final String initial;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _email = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset your password', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text("Enter your account's email and we'll send you a reset link.", style: TextStyle(color: AppColors.inkMuted)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                CtaButton(
                  label: 'Send reset link',
                  onPressed: () {
                    if (_form.currentState!.validate()) Navigator.pop(context, _email.text.trim());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
