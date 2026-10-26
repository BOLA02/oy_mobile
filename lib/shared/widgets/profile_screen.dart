import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/application/session_controller.dart';

/// Account screen shared by both roles.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.violet,
              child: Text(
                (session?.name?.isNotEmpty == true ? session!.name![0] : session?.role.label[0] ?? '?').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(session?.name ?? session?.role.label ?? '', style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(session?.role.label ?? '', style: const TextStyle(color: AppColors.inkMuted))),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: const StadiumBorder()),
          ),
        ],
      ),
    );
  }
}
