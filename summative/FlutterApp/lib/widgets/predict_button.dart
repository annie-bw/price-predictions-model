import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The full-width "Predict" button with a yellow arrow circle. While a request
/// is running it is disabled and shows a small yellow spinner instead.
class PredictButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const PredictButton({super.key, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.buttonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.disabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Predict',
              style: AppText.archivo(18, FontWeight.w700, color: AppColors.headerText)
                  .copyWith(letterSpacing: 18 * 0.01),
            ),
            const SizedBox(width: 12),
            isLoading ? const _Spinner() : const _ArrowCircle(),
          ],
        ),
      ),
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
      child: const Icon(Icons.arrow_forward, size: 16, color: AppColors.ink),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: AppColors.yellow,
        backgroundColor: Color(0x4DF2C94C), // yellow at 30%, like the design's track
      ),
    );
  }
}
