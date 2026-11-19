import '../models/input_field_config.dart';

/// Checks one raw text value against its field's rules.
/// Returns a short message saying how to fix it, or null when the value is valid.
String? validateField(InputFieldConfig field, String rawValue) {
  final value = rawValue.trim();

  if (value.isEmpty) {
    return '${field.label} is missing.';
  }
  if (!field.isNumber) {
    return null; // the API checks names against its list
  }

  // A comma is a common way to write decimals, so explain it instead of
  // just saying "not a number".
  if (field.type == FieldType.decimal && value.contains(',')) {
    return '${field.label}: use a dot, not a comma (for example ${field.example}).';
  }

  final number = _parseNumber(field, value);
  if (number == null) {
    final kind = field.type == FieldType.integer ? 'a whole number' : 'a number';
    return '${field.label} must be $kind, like ${field.example}.';
  }
  if (number < field.min! || number > field.max!) {
    return '${field.label} must be between ${field.min} and ${field.max}.';
  }
  return null;
}

/// Converts a valid raw text value into the type the API expects
/// (int, double or String). Call [validateField] first.
Object convertValue(InputFieldConfig field, String rawValue) {
  final value = rawValue.trim();
  return field.isNumber ? _parseNumber(field, value)! : value;
}

/// The title of the error box: "1 thing to fix" or "3 things to fix".
String errorTitle(int count) => count == 1 ? '1 thing to fix' : '$count things to fix';

num? _parseNumber(InputFieldConfig field, String value) {
  return field.type == FieldType.integer ? int.tryParse(value) : double.tryParse(value);
}
