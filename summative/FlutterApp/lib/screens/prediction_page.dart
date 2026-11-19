import 'package:flutter/material.dart';

import '../models/input_field_config.dart';
import '../models/prediction_form.dart';
import '../models/prediction_result.dart';
import '../services/location_service.dart';
import '../services/market_repository.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../utils/geo.dart';
import '../widgets/labeled_field.dart';
import '../widgets/location_controls.dart';
import '../widgets/page_header.dart';
import '../widgets/predict_button.dart';
import '../widgets/price_ticket.dart';
import '../widgets/result_display.dart';
import '../widgets/section_header.dart';
import '../widgets/suggestion_field.dart';

/// The single page of the app: 8 labelled text fields in three sections,
/// the Predict button, and one display area for the result or the errors.
class PredictionPage extends StatefulWidget {
  final MarketRepository repository;

  /// Passed in by tests; the app uses the real services.
  final PredictionService? predictionService;
  final LocationService locationService;

  const PredictionPage({
    super.key,
    required this.repository,
    this.predictionService,
    this.locationService = const LocationService(),
  });

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  /// Beyond this distance the notice says the user seems far from the markets.
  static const _farAwayKm = 30.0;

  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  final PredictionForm _form = PredictionForm();
  final GlobalKey _displayKey = GlobalKey();

  DisplayState _display = const DisplayState.idle();
  LocationStatus _locationStatus = LocationStatus.idle;
  LocationNotice? _locationNotice;

  bool get _isLoading => _display.status == DisplayStatus.loading;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  // ---------- Typing and auto-fill ----------

  void _onFieldEdited(String key) {
    setState(() => _form.editedByHand(key));
  }

  void _onMarketTyped(String text) {
    setState(() {
      _form.editedByHand(FieldKeys.market);
      _forgetLocation();
      // Typing an exact market name fills the section, like picking it from the list.
      final market = widget.repository.findMarket(text);
      if (market != null) _form.fillFromMarket(market);
    });
  }

  void _onMarketPicked(SuggestionItem item) {
    final market = widget.repository.findMarket(item.title);
    if (market == null) return;
    setState(() {
      _form.editedByHand(FieldKeys.market);
      _forgetLocation();
      _form.fillFromMarket(market);
    });
  }

  /// The user chose a market by hand, so the GPS result no longer applies.
  void _forgetLocation() {
    _locationStatus = LocationStatus.idle;
    _locationNotice = null;
  }

  // ---------- "Use my location" ----------

  Future<void> _useMyLocation() async {
    setState(() {
      _locationStatus = LocationStatus.locating;
      _locationNotice = null;
    });

    try {
      final position = await widget.locationService.currentPosition();
      final nearest = nearestMarket(widget.repository.markets, position);
      if (!mounted) return;
      setState(() {
        // Fill in the market's own values, not the raw GPS coordinates,
        // because the model learned market coordinates.
        _form.fillFromMarket(nearest.market,
            tag: PredictionForm.nearestMarketTag, includeName: true);
        _locationStatus = LocationStatus.located;
        _locationNotice = _nearestMarketNotice(nearest);
      });
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _locationStatus = LocationStatus.idle;
        _locationNotice = LocationNotice(before: error.message, isProblem: true);
      });
    }
  }

  LocationNotice _nearestMarketNotice(NearestMarket nearest) {
    final after = ', ${nearest.distanceKm.toStringAsFixed(1)} km away. '
        'Its details are filled in below.';
    final before = nearest.distanceKm > _farAwayKm
        ? 'You seem far from the markets in our data. The nearest one is '
        : 'The nearest market to you is ';
    return LocationNotice(before: before, bold: nearest.market.name, after: after);
  }

  // ---------- Predict ----------

  Future<void> _onPredictPressed() async {
    FocusScope.of(context).unfocus(); // close the keyboard

    // 1. Check every field first and show all the problems at once.
    final problems = _form.validate();
    if (problems.isNotEmpty) {
      _show(DisplayState.inputErrors(problems));
      return;
    }

    // 2. Call the API with the converted values.
    final inputs = _form.toInputs();
    _show(const DisplayState.loading());
    try {
      final result = await _predictionService.predictPrice(inputs);
      if (!mounted) return;
      _show(DisplayState.result(_ticketFor(result, inputs)));
    } on PredictionException catch (error) {
      if (!mounted) return;
      _show(DisplayState.serviceError(error.messages));
    }
  }

  TicketData _ticketFor(PredictionResult result, Map<String, Object> inputs) {
    return TicketData(
      price: result.price,
      low: result.low,
      high: result.high,
      monthTag: monthTag(inputs[FieldKeys.year] as int, inputs[FieldKeys.month] as int),
      commodity: inputs[FieldKeys.commodity] as String,
      market: inputs[FieldKeys.market] as String,
      province: inputs[FieldKeys.province] as String,
    );
  }

  void _show(DisplayState state) {
    setState(() => _display = state);
    _scrollToDisplayArea();
  }

  /// Scrolls so the display area is visible on small screens.
  void _scrollToDisplayArea() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final displayContext = _displayKey.currentContext;
      if (displayContext == null) return;
      Scrollable.ensureVisible(
        displayContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  // ---------- Layout ----------

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(),
              // The sheet overlaps the header by 28 px.
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.ground,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.sheetRadius)),
                  ),
                  // 4 + the 28 px left free by the overlap = 32 px of bottom space.
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 4 + bottomInset),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                      child: _buildSheetContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWhenSection(),
        const SizedBox(height: 28),
        _buildWhereSection(),
        const SizedBox(height: 28),
        _buildWhatSection(),
        const SizedBox(height: 28),
        PredictButton(isLoading: _isLoading, onPressed: _onPredictPressed),
        const SizedBox(height: 16),
        KeyedSubtree(key: _displayKey, child: ResultDisplay(state: _display)),
      ],
    );
  }

  Widget _buildWhenSection() {
    return _Section(
      header: const SectionHeader(number: '01', title: 'When'),
      children: [_sideBySide(FieldKeys.year, FieldKeys.month)],
    );
  }

  Widget _buildWhereSection() {
    final marketIsEmpty = _form.text(FieldKeys.market).trim().isEmpty;
    return _Section(
      header: SectionHeader(
        number: '02',
        title: 'Where',
        trailing: LocationButton(
          status: _locationStatus,
          onPressed: _isLoading ? null : _useMyLocation,
        ),
      ),
      children: [
        ?_locationNotice, // "?" adds it only when it isn't null
        _suggestionField(
          FieldKeys.market,
          prefixIcon: Icons.search,
          helperText: marketIsEmpty
              ? 'Pick a market and we’ll fill in the rest of this section for you.'
              : null,
          search: (query) => widget.repository
              .searchMarkets(query)
              .map((market) =>
                  SuggestionItem(market.name, subtitle: '${market.province} · ${market.district}'))
              .toList(),
          nounSingular: 'market',
          nounPlural: 'markets',
          onChanged: _onMarketTyped,
          onSelected: _onMarketPicked,
        ),
        _textField(FieldKeys.province),
        _textField(FieldKeys.district),
        _sideBySide(FieldKeys.latitude, FieldKeys.longitude),
        if (_form.coordinatesAutoFilled)
          Text('Filled in from the market. You can still change any field.',
              style: AppText.helper),
      ],
    );
  }

  Widget _buildWhatSection() {
    return _Section(
      header: const SectionHeader(number: '03', title: 'What'),
      children: [
        _suggestionField(
          FieldKeys.commodity,
          search: (query) =>
              widget.repository.searchCommodities(query).map(SuggestionItem.new).toList(),
          nounSingular: 'commodity',
          nounPlural: 'commodities',
          onChanged: (_) => _onFieldEdited(FieldKeys.commodity),
          onSelected: (_) => _onFieldEdited(FieldKeys.commodity),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onPredictPressed(),
        ),
      ],
    );
  }

  /// Two fields in equal columns, 12 px apart.
  Widget _sideBySide(String leftKey, String rightKey) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _textField(leftKey)),
        const SizedBox(width: 12),
        Expanded(child: _textField(rightKey)),
      ],
    );
  }

  Widget _textField(String key) {
    final field = fieldFor(key);
    return LabeledField(
      label: field.label,
      controller: _form.controllers[key]!,
      hint: field.hint,
      keyboardType: _keyboardFor(field),
      textCapitalization: field.isNumber ? TextCapitalization.none : TextCapitalization.words,
      suffix: field.suffix,
      tag: _tagFor(key),
      errorText: _form.errors[key],
      enabled: !_isLoading,
      onChanged: (_) => _onFieldEdited(key),
    );
  }

  Widget _suggestionField(
    String key, {
    required List<SuggestionItem> Function(String query) search,
    required String nounSingular,
    required String nounPlural,
    required ValueChanged<String> onChanged,
    required ValueChanged<SuggestionItem> onSelected,
    IconData? prefixIcon,
    String? helperText,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    final field = fieldFor(key);
    return SuggestionField(
      label: field.label,
      controller: _form.controllers[key]!,
      hint: field.hint,
      prefixIcon: prefixIcon,
      suffix: field.suffix,
      tag: _tagFor(key),
      errorText: _form.errors[key],
      helperText: helperText,
      enabled: !_isLoading,
      search: search,
      nounSingular: nounSingular,
      nounPlural: nounPlural,
      onChanged: onChanged,
      onSelected: onSelected,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }

  /// Only Market, Province and District show a tag next to their label.
  String? _tagFor(String key) {
    const taggedFields = [FieldKeys.market, FieldKeys.province, FieldKeys.district];
    return taggedFields.contains(key) ? _form.tagFor(key) : null;
  }

  static TextInputType _keyboardFor(InputFieldConfig field) {
    return switch (field.type) {
      FieldType.integer => TextInputType.number,
      FieldType.decimal => const TextInputType.numberWithOptions(decimal: true, signed: true),
      FieldType.text => TextInputType.text,
    };
  }
}

/// A section: its header row, then its fields 14 px apart.
class _Section extends StatelessWidget {
  final Widget header;
  final List<Widget> children;

  const _Section({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        for (final child in children) ...[const SizedBox(height: 14), child],
      ],
    );
  }
}
