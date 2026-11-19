import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/prediction_page.dart';
import 'services/location_service.dart';
import 'services/market_repository.dart';
import 'services/prediction_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open with the market and commodity lists built into the app...
  final repository = await MarketRepository.load(rootBundle);
  runApp(FoodPriceApp(repository: repository));
  // ...then, in the background, switch to the API's lists, which include names
  // added by a retrain. If the API can't be reached, the built-in lists stay.
  unawaited(repository.refreshFromApi());
}

/// Root of the app: sets the theme and opens the prediction page.
class FoodPriceApp extends StatelessWidget {
  final MarketRepository repository;

  /// Passed in by tests; the app uses the real services.
  final PredictionService? predictionService;
  final LocationService locationService;

  const FoodPriceApp({
    super.key,
    required this.repository,
    this.predictionService,
    this.locationService = const LocationService(),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rwanda Food Price Predictor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: PredictionPage(
        repository: repository,
        predictionService: predictionService,
        locationService: locationService,
      ),
    );
  }
}
