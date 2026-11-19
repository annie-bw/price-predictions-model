import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/market.dart';
import '../utils/name_search.dart';

/// The markets and commodities the model knows, used for suggestions and auto-fill.
///
/// The app starts with the lists built into assets/ (made by tools/generate_markets.py),
/// so it opens at once and works offline. [refreshFromApi] then swaps in the API's
/// /reference lists, which also include names added by a retrain (e.g. a new commodity).
class MarketRepository {
  List<Market> _markets;
  List<String> _commodities;

  MarketRepository({required this._markets, required this._commodities});

  List<Market> get markets => _markets;
  List<String> get commodities => _commodities;

  static Future<MarketRepository> load(AssetBundle bundle) async {
    return MarketRepository(
      markets: _parseMarkets(jsonDecode(await bundle.loadString('assets/markets.json'))),
      commodities: _parseCommodities(jsonDecode(await bundle.loadString('assets/commodities.json'))),
    );
  }

  /// Replaces the lists with the API's. Returns false and keeps the current lists if
  /// the API can't be reached or sends something unexpected.
  Future<bool> refreshFromApi({http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.referencePath}'))
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final markets = _parseMarkets(body['markets']);
      final commodities = _parseCommodities(body['commodities']);
      if (markets.isEmpty || commodities.isEmpty) return false;

      _markets = markets;
      _commodities = commodities;
      return true;
    } catch (_) {
      return false; // no internet, timeout or a bad answer: the built-in lists still work
    } finally {
      if (client == null) httpClient.close();
    }
  }

  List<Market> searchMarkets(String query) =>
      searchByName(_markets, query, (market) => market.name);

  List<String> searchCommodities(String query) =>
      searchByName(_commodities, query, (name) => name);

  /// The market with exactly this name (ignoring case and spaces), or null.
  Market? findMarket(String name) {
    final text = name.trim().toLowerCase();
    return _markets.where((market) => market.name.toLowerCase() == text).firstOrNull;
  }

  static List<Market> _parseMarkets(Object? json) => (json as List)
      .map((item) => Market.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);

  static List<String> _parseCommodities(Object? json) =>
      (json as List).cast<String>().toList(growable: false);
}
