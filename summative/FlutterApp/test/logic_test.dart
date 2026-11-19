import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maths_summative/models/input_field_config.dart';
import 'package:maths_summative/models/prediction_form.dart';
import 'package:maths_summative/services/prediction_service.dart';
import 'package:maths_summative/utils/formatting.dart';
import 'package:maths_summative/utils/geo.dart';
import 'package:maths_summative/utils/input_validator.dart';
import 'package:maths_summative/utils/name_search.dart';

import 'test_helpers.dart';

void main() {
  group('Input validation', () {
    final year = fieldFor(FieldKeys.year);
    final longitude = fieldFor(FieldKeys.longitude);

    test('missing value', () {
      expect(validateField(year, '  '), 'Year is missing.');
    });
    test('wrong type', () {
      expect(validateField(year, 'abc'), 'Year must be a whole number, like 2026.');
      expect(validateField(longitude, 'east'), 'Longitude must be a number, like 29.72.');
    });
    test('comma instead of a dot', () {
      expect(validateField(longitude, '29,72'),
          'Longitude: use a dot, not a comma (for example 29.72).');
    });
    test('out of range', () {
      expect(validateField(year, '1990'), 'Year must be between 2008 and 2035.');
    });
    test('valid values are converted to the right type', () {
      expect(validateField(year, '2026'), isNull);
      expect(convertValue(year, ' 2026 '), 2026);
      expect(convertValue(longitude, '29.72'), 29.72);
      expect(convertValue(fieldFor(FieldKeys.market), ' Huye '), 'Huye');
    });
  });

  group('Error title wording', () {
    test('one problem', () => expect(errorTitle(1), '1 thing to fix'));
    test('several problems', () => expect(errorTitle(3), '3 things to fix'));
  });

  group('Name search', () {
    test('names that start with the text come first, then names that contain it', () {
      final names = ['Akibu', 'Kibuye', 'Bukiza', 'Kicukiro', 'Huye'];
      expect(searchByName(names, 'KI', (name) => name),
          ['Kibuye', 'Kicukiro', 'Akibu', 'Bukiza']);
    });

    test('market search on the real list puts prefix matches first', () {
      // "bu": 6 markets start with it (Bubare, ...), 6 contain it (Kabuga, ...).
      final results = loadTestRepository().searchMarkets('bu').map((m) => m.name).toList();
      bool startsWithBu(String name) => name.toLowerCase().startsWith('bu');

      expect(results, hasLength(12));
      expect(results.take(6).every(startsWithBu), isTrue);
      expect(results.skip(6).any(startsWithBu), isFalse);
      expect(results.first, 'Bubare');
    });

    test('empty text matches nothing', () {
      expect(searchByName(['Huye'], ' ', (name) => name), isEmpty);
    });
  });

  group('Auto-fill', () {
    test('picking a market fills exactly Province, District, Latitude and Longitude', () {
      final form = PredictionForm();
      form.controllers[FieldKeys.year]!.text = '2026';
      form.controllers[FieldKeys.market]!.text = 'Butare';
      final butare = loadTestRepository().findMarket('butare')!;

      form.fillFromMarket(butare);

      expect(form.text(FieldKeys.province), 'Southern Province');
      expect(form.text(FieldKeys.district), 'Huye');
      expect(form.text(FieldKeys.latitude), butare.latitude.toString());
      expect(form.text(FieldKeys.longitude), butare.longitude.toString());
      // Untouched:
      expect(form.text(FieldKeys.year), '2026');
      expect(form.text(FieldKeys.month), '');
      expect(form.text(FieldKeys.market), 'Butare');
      expect(form.text(FieldKeys.commodity), '');
      expect(form.autoFilled.keys, unorderedEquals(PredictionForm.marketDetailKeys));
    });

    test('editing a filled field by hand removes its tag', () {
      final form = PredictionForm()..fillFromMarket(loadTestRepository().findMarket('Huye')!);

      form.editedByHand(FieldKeys.district);

      expect(form.tagFor(FieldKeys.district), isNull);
      expect(form.tagFor(FieldKeys.province), PredictionForm.filledInTag);
    });
  });

  group('Nearest market', () {
    test('a point near Huye returns Butare or Huye', () {
      final nearest = nearestMarket(loadTestRepository().markets, const GeoPoint(-2.596, 29.739));

      expect(nearest.market.name, anyOf('Butare', 'Huye'));
      expect(nearest.distanceKm, lessThan(3));
    });

    test('distance between Kigali and Huye is about 80 km', () {
      final km = distanceKm(const GeoPoint(-1.95, 30.06), const GeoPoint(-2.60, 29.74));
      expect(km, closeTo(80, 5));
    });
  });

  group('Formatting', () {
    test('prices are rounded with thousands separators', () {
      expect(formatPrice(486.2), '486');
      expect(formatPrice(12499.6), '12,500');
    });
    test('month tag', () => expect(monthTag(2026, 6), 'JUN 2026'));
  });

  group('Prediction service', () {
    test('returns the price and its range', () async {
      final result = await fakeApi({'predicted_price': 486.2, 'low': 385.0, 'high': 615.0})
          .predictPrice({'year': 2026});

      expect(result.price, 486.2);
      expect(result.low, 385.0);
      expect(result.high, 615.0);
    });

    test('an unknown name becomes a plain message', () async {
      final api = fakeApi({
        'detail': [
          {'loc': ['body', 'market'], 'msg': 'Unknown market.'},
          {'loc': ['body', 'commodity'], 'msg': 'Unknown commodity.'},
        ]
      }, status: 422);

      expect(
        () => api.predictPrice({}),
        throwsA(isA<PredictionException>().having((error) => error.messages, 'messages', [
          'That market isn’t in our list. Pick one from the suggestions.',
          'That commodity isn’t in our list. Pick one from the suggestions.',
        ])),
      );
    });

    test('no connection gives a plain message', () async {
      final api = PredictionService(
          client: MockClient((request) async => throw http.ClientException('offline')));

      expect(
        () => api.predictPrice({}),
        throwsA(isA<PredictionException>().having(
            (error) => error.messages, 'messages', [PredictionService.unreachableMessage])),
      );
    });
  });

  group('Market and commodity lists', () {
    test('the API lists replace the built-in ones, so new names are suggested', () async {
      final repository = loadTestRepository();
      expect(repository.searchCommodities('peach'), isEmpty);

      final apiLists = {
        'markets': [
          {'market': 'Butare', 'province': 'Southern Province', 'district': 'Huye',
           'latitude': -2.6, 'longitude': 29.74},
        ],
        'commodities': [...repository.commodities, 'Peaches'],
      };
      final client = MockClient((request) async {
        expect(request.url.path, '/reference');
        return http.Response(jsonEncode(apiLists), 200);
      });

      expect(await repository.refreshFromApi(client: client), isTrue);
      expect(repository.searchCommodities('peach'), ['Peaches']);
      expect(repository.findMarket('butare')?.district, 'Huye');
    });

    test('the built-in lists stay when the API cannot be reached or answers badly', () async {
      final repository = loadTestRepository();
      final before = repository.commodities.length;
      final responses = [
        MockClient((request) async => throw http.ClientException('offline')),
        MockClient((request) async => http.Response('Server error', 500)),
        MockClient((request) async => http.Response('{"markets": "oops"}', 200)),
      ];

      for (final client in responses) {
        expect(await repository.refreshFromApi(client: client), isFalse);
      }
      expect(repository.commodities.length, before);
    });
  });
}
