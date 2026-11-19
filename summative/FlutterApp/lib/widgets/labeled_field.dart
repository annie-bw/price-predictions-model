import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One labelled text field from the design: the label above (with an optional
/// accent tag on the right), the 52 px input, and either an inline error or a
/// helper text below.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;
  final String? suffix;
  final String? tag;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// Wraps only the input box. The suggestion list uses it to attach itself
  /// right under the input, not under the helper text.
  final Widget Function(Widget input)? inputWrapper;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    this.suffix,
    this.tag,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.inputWrapper,
  });

  bool get _hasError => errorText != null;

  @override
  Widget build(BuildContext context) {
    final input = _buildInput();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabelRow(),
        const SizedBox(height: 6),
        inputWrapper?.call(input) ?? input,
        if (_hasError) ...[
          const SizedBox(height: 6),
          InlineError(errorText!),
        ] else if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: AppText.helper),
        ],
      ],
    );
  }

  Widget _buildLabelRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(label.toUpperCase(), style: AppText.fieldLabel, overflow: TextOverflow.ellipsis),
        ),
        if (tag != null) Text(tag!, style: AppText.mono(11, color: AppColors.accent)),
      ],
    );
  }

  Widget _buildInput() {
    // Rebuild when the text changes, because the border colour depends on
    // whether the field is empty or filled.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final idleColor = controller.text.isEmpty ? AppColors.border : AppColors.borderFilled;
        // The visible label sits above the box, so give screen readers the label too.
        return Semantics(
          label: label,
          child: TextField(
          key: ValueKey('field-$label'),
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: AppText.input,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.inter(17, color: AppColors.inkSoft.withValues(alpha: 0.7)),
            filled: true,
            fillColor: _hasError ? AppColors.errorFieldBg : AppColors.surface,
            constraints: const BoxConstraints.tightFor(height: AppSizes.inputHeight),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            prefixIcon: prefixIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: Icon(prefixIcon, size: 18, color: AppColors.inkSoft),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8, right: 14),
                    child: Text(suffix!,
                        style: AppText.mono(suffix == '°' ? 14 : 13,
                            weight: FontWeight.w400, color: AppColors.inkSoft)),
                  ),
            suffixIconConstraints: const BoxConstraints(),
            enabledBorder: _border(_hasError ? AppColors.error : idleColor),
            disabledBorder: _border(idleColor),
            focusedBorder: _border(_hasError ? AppColors.error : AppColors.ink, width: 2),
          ),
          ),
        );
      },
    );
  }

  OutlineInputBorder _border(Color color, {double width = AppSizes.inputBorder}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// An alert icon and a short message under a field with a problem.
class InlineError extends StatelessWidget {
  final String message;
  const InlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.error_outline, size: 15, color: AppColors.errorText),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: AppText.inter(13, color: AppColors.errorText, height: 1.35)),
        ),
      ],
    );
  }
}
