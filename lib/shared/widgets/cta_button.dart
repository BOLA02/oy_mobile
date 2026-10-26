import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The single mango "key action" button of a screen (Order now, Accept, Pay).
class CtaButton extends StatelessWidget {
  const CtaButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mango,
        foregroundColor: AppColors.ink,
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink),
            )
          : Text(label),
    );
  }
}
