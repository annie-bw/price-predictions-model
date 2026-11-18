import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/input_validator.dart';
import 'dashed_border.dart';
import 'price_ticket.dart';

enum DisplayStatus { idle, loading, result, error }

/// What the display area under the Predict button shows.
class DisplayState {
  final DisplayStatus status;
  final TicketData? ticket;
  final String title; // title of the error box
  final List<String> messages;

  const DisplayState._(this.status, {this.ticket, this.title = '', this.messages = const []});

  const DisplayState.idle() : this._(DisplayStatus.idle);
  const DisplayState.loading() : this._(DisplayStatus.loading);
  const DisplayState.result(TicketData ticket) : this._(DisplayStatus.result, ticket: ticket);

  /// Problems with the values typed in: "3 things to fix".
  DisplayState.inputErrors(List<String> messages)
      : this._(DisplayStatus.error, title: errorTitle(messages.length), messages: messages);

  /// API and network problems.
  const DisplayState.serviceError(List<String> messages)
      : this._(DisplayStatus.error, title: 'Something went wrong', messages: messages);
}

/// The single display area: a hint, a loading card, the price ticket or an error box.
class ResultDisplay extends StatelessWidget {
  final DisplayState state;

  const ResultDisplay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: switch (state.status) {
        DisplayStatus.idle => const _IdleCard(),
        DisplayStatus.loading => const _LoadingCard(),
        DisplayStatus.result => PriceTicket(data: state.ticket!),
        DisplayStatus.error => _ErrorBox(title: state.title, messages: state.messages),
      },
    );
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedRoundedRectPainter(
        color: AppColors.dashed,
        strokeWidth: 1.5,
        radius: AppSizes.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.tile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sell_outlined, size: 20, color: AppColors.inkMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your estimate appears here', style: AppText.archivo(16, FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('Fill in all 8 fields, then tap Predict.', style: AppText.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ESTIMATING PRICE', style: AppText.eyebrow()),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
              minHeight: 6,
              color: AppColors.accent,
              backgroundColor: AppColors.tile,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Getting your estimate. The first one can take up to a minute.',
            style: AppText.inter(14, color: AppColors.bodyText, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String title;
  final List<String> messages;

  const _ErrorBox({required this.title, required this.messages});

  @override
  Widget build(BuildContext context) {
    final textStyle = AppText.inter(14, color: AppColors.errorDark, height: 1.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: AppColors.errorText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: AppText.archivo(17, FontWeight.w700, color: AppColors.errorDark)),
              ),
            ],
          ),
          const SizedBox(height: 6), // 12 px in total above the first message
          for (final message in messages) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: Text('•', style: textStyle),
                ),
                Expanded(child: Text(message, style: textStyle)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
