import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "01  When  ———————" with an optional widget on the right (e.g. the location button).
class SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.number, required this.title, this.trailing});

  /// The trailing widget may use at most this share of the row, so on narrow
  /// screens or with large text its label is shortened instead of overflowing.
  static const _maxTrailingShare = 0.55;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Row(
        children: [
          Text(number, style: AppText.mono(12, weight: FontWeight.w600, color: AppColors.accent)),
          const SizedBox(width: 10),
          Semantics(
            header: true,
            child: Text(title, style: AppText.archivo(18, FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: AppColors.line)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * _maxTrailingShare),
              child: trailing,
            ),
          ],
        ],
      );
    });
  }
}
