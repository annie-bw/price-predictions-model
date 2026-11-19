/// One market from assets/markets.json, with the values that auto-fill the form.
class Market {
  final String name;
  final String province;
  final String district;
  final double latitude;
  final double longitude;

  const Market({
    required this.name,
    required this.province,
    required this.district,
    required this.latitude,
    required this.longitude,
  });

  factory Market.fromJson(Map<String, dynamic> json) => Market(
        name: json['market'] as String,
        province: json['province'] as String,
        district: json['district'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}
