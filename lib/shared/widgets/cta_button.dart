import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The single orange "key action" button of a screen (Order now, Accept, Pay).
class CtaButton extends StatelessWidget {
  const CtaButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        // White on orange is only comfortable at a larger, heavier size.
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.2),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Text(label),
    );
  }
}
