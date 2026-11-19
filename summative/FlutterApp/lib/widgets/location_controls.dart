import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum LocationStatus { idle, locating, located }

/// The "Use my location" pill. After a successful lookup it reads "Location used".
class LocationButton extends StatelessWidget {
  final LocationStatus status;
  final VoidCallback? onPressed;

  const LocationButton({super.key, required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final located = status == LocationStatus.located;
    final label = switch (status) {
      LocationStatus.idle => 'Use my location',
      LocationStatus.locating => 'Finding you…',
      LocationStatus.located => 'Location used',
    };

    return SizedBox(
      height: AppSizes.pillHeight,
      child: OutlinedButton(
        onPressed: status == LocationStatus.locating ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.only(left: 12, right: 14),
          backgroundColor: located ? AppColors.accentTint : AppColors.surface,
          disabledBackgroundColor: AppColors.surface,
          side: BorderSide(color: located ? AppColors.accent : AppColors.border, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == LocationStatus.locating)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              )
            else
              const Icon(Icons.gps_fixed, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: AppText.inter(14, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// The light green box above the Market field. It names the nearest market after
/// a GPS lookup, or explains why the location couldn't be used.
class LocationNotice extends StatelessWidget {
  /// Text before the bold part.
  final String before;

  /// The market name, shown in bold. Null for a plain message.
  final String? bold;

  /// Text after the bold part.
  final String after;
  final bool isProblem;

  const LocationNotice({
    super.key,
    required this.before,
    this.bold,
    this.after = '',
    this.isProblem = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppText.inter(14, color: AppColors.noticeText, height: 1.45);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(isProblem ? Icons.location_off_outlined : Icons.place_outlined,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(style: style, children: [
                TextSpan(text: before),
                if (bold != null)
                  TextSpan(text: bold, style: style.copyWith(fontWeight: FontWeight.w700)),
                TextSpan(text: after),
              ])),
            ),
          ],
        ),
      ),
    );
  }
}
