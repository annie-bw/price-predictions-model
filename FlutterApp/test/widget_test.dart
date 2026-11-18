import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maths_summative/models/input_field_config.dart';
import 'package:maths_summative/utils/geo.dart';

import 'test_helpers.dart';

const _validInputs = {
  'Year': '2026',
  'Month': '6',
  'Market': 'Butare',
  'Province': 'Southern Province',
  'District': 'Huye',
  'Latitude': '-2.6',
  'Longitude': '29.74',
  'Commodity': 'Maize',
};

Future<void> _fillAllFields(WidgetTester tester) async {
  for (final entry in _validInputs.entries) {
    await tester.enterText(fieldLabelled(entry.key), entry.value);
  }
  // Leave the last field, like a user tapping elsewhere: this closes the
  // commodity suggestion list, which would otherwise cover the Predict button.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<void> _tapPredict(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Predict'));
  await tester.pumpAndSettle();
}

void main() {
  group('Page layout', () {
    testWidgets('has 8 labelled text fields, a Predict button and the display area',
        (tester) async {
      await pumpApp(tester);

      expect(find.byType(TextField), findsNWidgets(8));
      for (final field in predictionFields) {
        expect(find.text(field.label.toUpperCase()), findsOneWidget, reason: field.label);
      }
      expect(find.widgetWithText(FilledButton, 'Predict'), findsOneWidget);
      expect(find.text('Your estimate appears here'), findsOneWidget);
      expect(find.text('Fill in all 8 fields, then tap Predict.'), findsOneWidget);
    });
  });

  group('Input errors', () {
    testWidgets('empty fields show the error box and an inline message per field',
        (tester) async {
      await pumpApp(tester);
      await _tapPredict(tester);

      expect(find.text('8 things to fix'), findsOneWidget);
      // Once under the field and once in the error box.
      expect(find.text('Year is missing.'), findsNWidgets(2));
      expect(find.text('Commodity is missing.'), findsNWidgets(2));
    });

    testWidgets('a single problem uses "1 thing to fix"', (tester) async {
      await pumpApp(tester);
      await _fillAllFields(tester);
      await tester.enterText(fieldLabelled('Longitude'), '29,72');
      await _tapPredict(tester);

      expect(find.text('1 thing to fix'), findsOneWidget);
      expect(find.text('Longitude: use a dot, not a comma (for example 29.72).'),
          findsNWidgets(2));
    });
  });

  group('Market suggestions and auto-fill', () {
    testWidgets('typing shows matching markets; picking one fills the section',
        (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldLabelled('Market'), 'Ki');
      await tester.pump();
      expect(find.text('16 MARKETS MATCH'), findsOneWidget);
      expect(find.text('Eastern Province · Ngoma'), findsOneWidget); // Kibungo

      await tester.tap(find.text('Eastern Province · Ngoma'));
      await tester.pumpAndSettle();

      expect(find.text('16 MARKETS MATCH'), findsNothing);
      expect(fieldText(tester, 'Market'), 'Kibungo');
      expect(fieldText(tester, 'Province'), 'Eastern Province');
      expect(fieldText(tester, 'District'), 'Ngoma');
      expect(find.text('filled in'), findsNWidgets(2)); // Province and District
      expect(find.text('Filled in from the market. You can still change any field.'),
          findsOneWidget);
    });

    testWidgets('typing an exact name fills the section, and editing removes the tag',
        (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldLabelled('Market'), 'huye');
      await tester.pump();
      expect(fieldText(tester, 'District'), 'Huye');
      expect(find.text('filled in'), findsNWidgets(2));

      await tester.enterText(fieldLabelled('District'), 'Gisagara');
      await tester.pump();
      expect(find.text('filled in'), findsOneWidget); // only Province keeps its tag
    });

    testWidgets('commodity suggestions use the same list', (tester) async {
      await pumpApp(tester);

      await tester.enterText(fieldLabelled('Commodity'), 'potat');
      await tester.pump();
      expect(find.textContaining('MATCH'), findsOneWidget);

      await tester.tap(richText('Potatoes (Irish)'));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'Commodity'), 'Potatoes (Irish)');
    });
  });

  group('Use my location', () {
    testWidgets('fills the nearest market and shows the notice', (tester) async {
      await pumpApp(tester, location: const FakeLocationService(point: GeoPoint(-2.596, 29.739)));

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'Market'), 'Butare');
      expect(fieldText(tester, 'District'), 'Huye');
      expect(richText('The nearest market to you is Butare, 0.5 km away.'), findsOneWidget);
      expect(find.text('nearest market'), findsNWidgets(3)); // Market, Province, District
      expect(find.text('Location used'), findsOneWidget);
    });

    testWidgets('a far-away position still fills the market but says so', (tester) async {
      await pumpApp(tester, location: const FakeLocationService(point: GeoPoint(-1.0, 32.0)));

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(richText('You seem far from the markets in our data.'), findsOneWidget);
      expect(fieldText(tester, 'Market'), isNotEmpty);
    });

    testWidgets('a location problem is shown in the notice, not the display area',
        (tester) async {
      await pumpApp(tester,
          location: const FakeLocationService(error: 'Location is turned off. Type a market instead.'));

      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();

      expect(richText('Location is turned off. Type a market instead.'), findsOneWidget);
      expect(find.text('Your estimate appears here'), findsOneWidget);
      expect(find.text('Use my location'), findsOneWidget);
    });
  });

  group('Prediction result', () {
    testWidgets('shows the price ticket from the API response', (tester) async {
      await pumpApp(tester,
          api: fakeApi({'predicted_price': 486.2, 'unit': 'RWF/kg', 'low': 385.0, 'high': 615.4}));
      await _fillAllFields(tester);
      await _tapPredict(tester);

      expect(find.text('ESTIMATED PRICE'), findsOneWidget);
      expect(find.text('JUN 2026'), findsOneWidget);
      expect(find.text('486'), findsOneWidget);
      expect(find.text('RWF'), findsOneWidget);
      expect(find.text('Maize · Butare market, Southern Province'), findsOneWidget);
      expect(richText('Likely between 385 and 615 RWF per kg'), findsOneWidget);
    });

    testWidgets('API errors appear as plain text under "Something went wrong"',
        (tester) async {
      await pumpApp(tester,
          api: fakeApi({
            'detail': [
              {'loc': ['body', 'market'], 'msg': 'Unknown market. Did you mean: Butare?'}
            ]
          }, status: 422));
      await _fillAllFields(tester);
      await _tapPredict(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('That market isn’t in our list. Pick one from the suggestions.'),
          findsOneWidget);
    });
  });
}
