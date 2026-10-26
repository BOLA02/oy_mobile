import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/application/session_controller.dart';
import 'ui.dart';

/// Account screen for the rider (customers have their own, with addresses).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    final title = session?.name ?? session?.role.label ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.mango,
                  child: Icon(Icons.two_wheeler_rounded, size: 30, color: AppColors.ink.withValues(alpha: 0.9)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.isEmpty ? 'Rider' : title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      Text(session?.role.label ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text('You will stop receiving delivery offers.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(sessionControllerProvider.notifier).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
