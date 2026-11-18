import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/market.dart';
import '../utils/name_search.dart';

/// The markets and commodities the model knows, loaded once at startup from
/// assets/markets.json and assets/commodities.json (made by tools/generate_markets.py).
class MarketRepository {
  final List<Market> markets;
  final List<String> commodities;

  const MarketRepository({required this.markets, required this.commodities});

  static Future<MarketRepository> load(AssetBundle bundle) async {
    final marketsJson = jsonDecode(await bundle.loadString('assets/markets.json')) as List;
    final commoditiesJson =
        jsonDecode(await bundle.loadString('assets/commodities.json')) as List;
    return MarketRepository(
      markets: marketsJson.map((json) => Market.fromJson(json as Map<String, dynamic>)).toList(),
      commodities: commoditiesJson.cast<String>(),
    );
  }

  List<Market> searchMarkets(String query) =>
      searchByName(markets, query, (market) => market.name);

  List<String> searchCommodities(String query) =>
      searchByName(commodities, query, (name) => name);

  /// The market with exactly this name (ignoring case and spaces), or null.
  Market? findMarket(String name) {
    final text = name.trim().toLowerCase();
    return markets.where((market) => market.name.toLowerCase() == text).firstOrNull;
  }
}
