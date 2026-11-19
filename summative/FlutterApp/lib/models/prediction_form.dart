import 'package:flutter/widgets.dart';

import '../utils/input_validator.dart';
import 'input_field_config.dart';
import 'market.dart';

/// The state of the 8 text fields: their text, their inline errors and which
/// ones were filled in automatically.
///
/// Keeping this outside the page keeps the page about layout, and lets tests
/// check the auto-fill rules without building any widgets.
class PredictionForm {
  static const filledInTag = 'filled in';
  static const nearestMarketTag = 'nearest market';

  /// The fields a market fills in. The market name itself is typed or picked.
  static const marketDetailKeys = [
    FieldKeys.province,
    FieldKeys.district,
    FieldKeys.latitude,
    FieldKeys.longitude,
  ];

  final Map<String, TextEditingController> controllers = {
    for (final field in predictionFields) field.key: TextEditingController(),
  };

  /// Inline error message per field key.
  final Map<String, String> errors = {};

  /// Fields that still hold an auto-filled value, with the tag to show
  /// ("filled in" or "nearest market"). Editing a field by hand removes it.
  final Map<String, String> autoFilled = {};

  String text(String key) => controllers[key]!.text;

  /// Fills Province, District, Latitude and Longitude from [market].
  /// With [includeName] (used by "Use my location") the Market field is filled too.
  void fillFromMarket(Market market, {String tag = filledInTag, bool includeName = false}) {
    final values = {
      FieldKeys.province: market.province,
      FieldKeys.district: market.district,
      FieldKeys.latitude: market.latitude.toString(),
      FieldKeys.longitude: market.longitude.toString(),
      if (includeName) FieldKeys.market: market.name,
    };
    autoFilled.clear();
    values.forEach((key, value) {
      controllers[key]!.text = value;
      autoFilled[key] = tag;
      errors.remove(key);
    });
  }

  /// Call when the user types in a field: their own value replaces the auto-filled one.
  void editedByHand(String key) {
    autoFilled.remove(key);
    errors.remove(key);
  }

  /// The tag to show next to a field's label, or null.
  String? tagFor(String key) => autoFilled[key];

  bool get coordinatesAutoFilled =>
      autoFilled.containsKey(FieldKeys.latitude) || autoFilled.containsKey(FieldKeys.longitude);

  /// Checks every field and stores the inline errors. Returns the messages in page order.
  List<String> validate() {
    errors.clear();
    for (final field in predictionFields) {
      final error = validateField(field, text(field.key));
      if (error != null) errors[field.key] = error;
    }
    return [
      for (final field in predictionFields)
        if (errors.containsKey(field.key)) errors[field.key]!,
    ];
  }

  /// The values to send to the API, converted to int, double or String.
  /// Call [validate] first.
  Map<String, Object> toInputs() => {
        for (final field in predictionFields) field.key: convertValue(field, text(field.key)),
      };

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}
