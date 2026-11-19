import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'labeled_field.dart';

/// One row in a suggestion list.
class SuggestionItem {
  final String title;
  final String? subtitle;

  const SuggestionItem(this.title, {this.subtitle});
}

/// A [LabeledField] that shows matching names in a list under the input while
/// the user types. The list floats over the fields below it.
/// Used for both Market and Commodity.
class SuggestionField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final String? suffix;
  final String? tag;
  final String? errorText;
  final String? helperText;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Returns the matching items for what the user typed, best matches first.
  final List<SuggestionItem> Function(String query) search;

  /// Used in the list header: "16 MARKETS MATCH", "1 MARKET MATCHES".
  final String nounSingular;
  final String nounPlural;

  /// Called when the user types (before the list updates).
  final ValueChanged<String>? onChanged;

  /// Called when the user picks a row. The field's text is already set to its title.
  final ValueChanged<SuggestionItem> onSelected;

  const SuggestionField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.search,
    required this.nounSingular,
    required this.nounPlural,
    required this.onSelected,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.tag,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  static const _maxRows = 4;

  final _focusNode = FocusNode();
  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  List<SuggestionItem> _matches = [];
  double _inputWidth = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_updateList);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    widget.onChanged?.call(text);
    _updateList();
  }

  /// Shows the list while the field has focus and there is something useful to show.
  void _updateList() {
    final text = widget.controller.text.trim();
    final matches = widget.search(text);
    final onlyExactMatch = matches.length == 1 &&
        matches.first.title.toLowerCase() == text.toLowerCase();

    setState(() => _matches = matches);
    if (_focusNode.hasFocus && matches.isNotEmpty && !onlyExactMatch) {
      _overlay.show();
    } else {
      _overlay.hide();
    }
  }

  void _select(SuggestionItem item) {
    widget.controller.value = TextEditingValue(
      text: item.title,
      selection: TextSelection.collapsed(offset: item.title.length),
    );
    _overlay.hide();
    _focusNode.unfocus();
    widget.onSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      controller: widget.controller,
      focusNode: _focusNode,
      hint: widget.hint,
      prefixIcon: widget.prefixIcon,
      suffix: widget.suffix,
      tag: widget.tag,
      errorText: widget.errorText,
      helperText: widget.helperText,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      textCapitalization: TextCapitalization.words,
      onSubmitted: widget.onSubmitted,
      onChanged: _onChanged,
      inputWrapper: _attachList,
    );
  }

  Widget _attachList(Widget input) {
    return LayoutBuilder(builder: (context, constraints) {
      _inputWidth = constraints.maxWidth;
      return CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: _buildList,
          child: input,
        ),
      );
    });
  }

  Widget _buildList(BuildContext context) {
    final count = _matches.length;
    final header = count == 1
        ? '1 ${widget.nounSingular} MATCHES'
        : '$count ${widget.nounPlural} MATCH';

    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 8),
      child: Align(
        alignment: Alignment.topLeft,
        // Taps inside the list count as taps on the field, so the field keeps
        // focus long enough for the tap to select a row.
        child: TextFieldTapRegion(
          child: SizedBox(
            width: _inputWidth,
            child: _SuggestionList(
              header: header.toUpperCase(),
              items: _matches.take(_maxRows).toList(),
              query: widget.controller.text.trim(),
              onTap: _select,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final String header;
  final List<SuggestionItem> items;
  final String query;
  final ValueChanged<SuggestionItem> onTap;

  const _SuggestionList({
    required this.header,
    required this.items,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.14),
            offset: const Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Material(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Text(header,
                    style: AppText.mono(11, weight: FontWeight.w600, color: AppColors.inkMuted, spacing: 0.1)),
              ),
              for (var i = 0; i < items.length; i++)
                _SuggestionRow(
                  item: items[i],
                  query: query,
                  highlighted: i == 0,
                  onTap: () => onTap(items[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final SuggestionItem item;
  final String query;
  final bool highlighted;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.item,
    required this.query,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.ground : AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.rowDivider)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(_highlightMatch(item.title, query)),
            if (item.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(item.subtitle!, style: AppText.inter(13, color: AppColors.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }

  /// The name with the typed part in bold, e.g. **Ki**bungo.
  static TextSpan _highlightMatch(String name, String query) {
    final normal = AppText.inter(16, weight: FontWeight.w500);
    final start = name.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) return TextSpan(text: name, style: normal);

    final end = start + query.length;
    return TextSpan(style: normal, children: [
      TextSpan(text: name.substring(0, start)),
      TextSpan(text: name.substring(start, end), style: normal.copyWith(fontWeight: FontWeight.w700)),
      TextSpan(text: name.substring(end)),
    ]);
  }
}
