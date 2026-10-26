import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ui.dart';
import '../../domain/order.dart';

extension OrderStatusStyle on OrderStatus {
  Color get color => switch (this) {
        OrderStatus.pending => AppColors.mangoDeep,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.danger,
        _ => AppColors.violet,
      };

  Color get background => switch (this) {
        OrderStatus.pending => AppColors.cream,
        OrderStatus.delivered => AppColors.successSoft,
        OrderStatus.cancelled => AppColors.dangerSoft,
        _ => AppColors.violetSoft,
      };
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: status.label, color: status.color, background: status.background);
}

/// Four-step progress line: placed → preparing → on the way → delivered.
class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status, this.onDark = false});

  final OrderStatus status;
  final bool onDark;

  static const _labels = ['Placed', 'Preparing', 'On the way', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    final current = status.step;
    final on = onDark ? AppColors.mango : AppColors.violet;
    final off = onDark ? Colors.white.withValues(alpha: 0.25) : AppColors.border;
    final text = onDark ? Colors.white : AppColors.ink;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, color: i <= current ? on : off)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? on : off,
                      ),
                      child: i <= current
                          ? Icon(Icons.check_rounded, size: 15, color: onDark ? AppColors.ink : Colors.white)
                          : null,
                    ),
                    Expanded(
                        child: i == _labels.length - 1 ? const SizedBox() : Container(height: 3, color: i < current ? on : off)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i <= current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current ? text : text.withValues(alpha: 0.55),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
