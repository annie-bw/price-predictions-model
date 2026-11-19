import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maths_summative/main.dart';
import 'package:maths_summative/models/market.dart';
import 'package:maths_summative/services/location_service.dart';
import 'package:maths_summative/services/market_repository.dart';
import 'package:maths_summative/services/prediction_service.dart';
import 'package:maths_summative/utils/geo.dart';

/// The real market and commodity lists from assets/, read from disk.
MarketRepository loadTestRepository() {
  final markets = jsonDecode(File('assets/markets.json').readAsStringSync()) as List;
  final commodities = jsonDecode(File('assets/commodities.json').readAsStringSync()) as List;
  return MarketRepository(
    markets: markets.map((json) => Market.fromJson(json as Map<String, dynamic>)).toList(),
    commodities: commodities.cast<String>(),
  );
}

/// A prediction service whose API always answers with [body] and [status].
PredictionService fakeApi(Object body, {int status = 200}) {
  final client = MockClient((request) async => http.Response(jsonEncode(body), status));
  return PredictionService(client: client);
}

/// A location service that returns [point], or fails with [error].
class FakeLocationService extends LocationService {
  final GeoPoint? point;
  final String? error;

  const FakeLocationService({this.point, this.error});

  @override
  Future<GeoPoint> currentPosition() async {
    if (error != null) throw LocationException(error!);
    return point!;
  }
}

/// Builds the app on a tall phone-sized screen, so every part of the page is visible.
Future<void> pumpApp(
  WidgetTester tester, {
  PredictionService? api,
  LocationService location = const FakeLocationService(error: 'not used'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(FoodPriceApp(
    repository: loadTestRepository(),
    predictionService: api,
    locationService: location,
  ));
}

/// The text field with this label.
Finder fieldLabelled(String label) => find.byKey(ValueKey('field-$label'));

String fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(fieldLabelled(label)).controller!.text;

/// Finds text, including text inside rich text with bold parts.
Finder richText(String text) => find.textContaining(text, findRichText: true);
