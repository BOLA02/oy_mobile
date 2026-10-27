import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Where the role is chosen: once, when creating an account.
class JoinScreen extends StatelessWidget {
  const JoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('How will you use OyaEat?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text('Pick one to get started. You can always log in the same way later.', style: TextStyle(color: AppColors.inkMuted, height: 1.4)),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.restaurant_menu_rounded,
              title: 'Order food',
              subtitle: 'Browse restaurants, order, and track your delivery in real time.',
              gradient: AppColors.brandGradient,
              onTap: () => context.push('/signup'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.two_wheeler_rounded,
              title: 'Deliver with us',
              subtitle: 'Ride as a delivery partner. Accept orders nearby and earn on every trip.',
              gradient: const LinearGradient(colors: [Color(0xFFFFC94D), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              dark: true,
              onTap: () => context.push('/rider-register'),
            ),
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('I already have an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.ink : Colors.white;
    return Container(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.card),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(color: fg.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 30, color: dark ? AppColors.ink : AppColors.mango),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 13.5, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
