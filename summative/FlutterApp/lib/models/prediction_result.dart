/// What the API returns for one prediction, in RWF per kg.
class PredictionResult {
  final double price;

  /// The likely range: 8 out of 10 real prices fall between [low] and [high].
  final double low;
  final double high;

  const PredictionResult({required this.price, required this.low, required this.high});

  factory PredictionResult.fromJson(Map<String, dynamic> json) => PredictionResult(
        price: (json['predicted_price'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
      );
}
