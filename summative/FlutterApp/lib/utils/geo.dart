import 'dart:math' as math;

import '../models/market.dart';

/// A point on Earth in degrees.
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);
}

/// The closest market to a point and how far away it is.
class NearestMarket {
  final Market market;
  final double distanceKm;

  const NearestMarket(this.market, this.distanceKm);
}

const double _earthRadiusKm = 6371;

/// Straight-line distance between two points along the Earth's surface
/// (the haversine formula), in kilometres.
double distanceKm(GeoPoint a, GeoPoint b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final deltaLat = lat2 - lat1;
  final deltaLon = _radians(b.longitude - a.longitude);

  final h = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
  return 2 * _earthRadiusKm * math.asin(math.sqrt(h));
}

/// The market closest to [point]. [markets] must not be empty.
NearestMarket nearestMarket(List<Market> markets, GeoPoint point) {
  NearestMarket? nearest;
  for (final market in markets) {
    final distance = distanceKm(point, GeoPoint(market.latitude, market.longitude));
    if (nearest == null || distance < nearest.distanceKm) {
      nearest = NearestMarket(market, distance);
    }
  }
  return nearest!;
}

double _radians(double degrees) => degrees * math.pi / 180;
