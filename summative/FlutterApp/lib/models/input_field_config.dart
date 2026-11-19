/// The kind of value a text field expects.
enum FieldType { integer, decimal, text }

/// Describes one input of the model: its label, the type it must have and,
/// for numbers, the allowed range. The validator and the page both read it.
class InputFieldConfig {
  /// The name the API expects in the JSON body.
  final String key;
  final String label;
  final String hint;
  final FieldType type;
  final num? min;
  final num? max;

  /// A valid value, used in error messages ("like 2026").
  final String example;

  /// Text shown inside the field on the right, e.g. "1–12" or "per kg".
  final String? suffix;

  const InputFieldConfig({
    required this.key,
    required this.label,
    required this.hint,
    required this.type,
    required this.example,
    this.min,
    this.max,
    this.suffix,
  });

  bool get isNumber => type != FieldType.text;
}

/// Keys of the 8 inputs, so other files don't repeat the strings.
abstract final class FieldKeys {
  static const year = 'year';
  static const month = 'month';
  static const market = 'market';
  static const province = 'admin1';
  static const district = 'admin2';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const commodity = 'commodity';
}

/// The 8 inputs in the order they appear on the page.
/// Keys and ranges must match the API's request model.
const List<InputFieldConfig> predictionFields = [
  InputFieldConfig(
    key: FieldKeys.year,
    label: 'Year',
    hint: 'e.g. 2026',
    type: FieldType.integer,
    example: '2026',
    min: 2008,
    max: 2035,
  ),
  InputFieldConfig(
    key: FieldKeys.month,
    label: 'Month',
    hint: 'e.g. 6',
    type: FieldType.integer,
    example: '6',
    min: 1,
    max: 12,
    suffix: '1–12',
  ),
  InputFieldConfig(
    key: FieldKeys.market,
    label: 'Market',
    hint: 'Search a market, e.g. Huye',
    type: FieldType.text,
    example: 'Huye',
  ),
  InputFieldConfig(
    key: FieldKeys.province,
    label: 'Province',
    hint: 'e.g. Southern Province',
    type: FieldType.text,
    example: 'Southern Province',
  ),
  InputFieldConfig(
    key: FieldKeys.district,
    label: 'District',
    hint: 'e.g. Huye',
    type: FieldType.text,
    example: 'Huye',
  ),
  InputFieldConfig(
    key: FieldKeys.latitude,
    label: 'Latitude',
    hint: 'e.g. -2.58',
    type: FieldType.decimal,
    example: '-2.58',
    min: -2.9,
    max: -1.0,
    suffix: '°',
  ),
  InputFieldConfig(
    key: FieldKeys.longitude,
    label: 'Longitude',
    hint: 'e.g. 29.72',
    type: FieldType.decimal,
    example: '29.72',
    min: 28.8,
    max: 31.0,
    suffix: '°',
  ),
  InputFieldConfig(
    key: FieldKeys.commodity,
    label: 'Commodity',
    hint: 'e.g. Maize or Beans (dry)',
    type: FieldType.text,
    example: 'Maize',
    suffix: 'per kg',
  ),
];

/// Looks up a field's settings by its key.
InputFieldConfig fieldFor(String key) =>
    predictionFields.firstWhere((field) => field.key == key);
