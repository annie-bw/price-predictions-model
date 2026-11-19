import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/input_field_config.dart';
import '../models/prediction_result.dart';

/// An error with messages that can be shown directly to the user.
class PredictionException implements Exception {
  final List<String> messages;
  const PredictionException(this.messages);

  @override
  String toString() => messages.join('\n');
}

/// Sends the inputs to the API's /predict endpoint and returns the predicted
/// price with its likely range.
class PredictionService {
  static const unreachableMessage =
      'Can’t reach the price service. Check your internet and try again.';
  static const timeoutMessage =
      'The price service is taking too long. Please try again in a minute.';

  final http.Client _client;

  PredictionService({http.Client? client}) : _client = client ?? http.Client();

  Future<PredictionResult> predictPrice(Map<String, Object> inputs) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.predictPath}');

    final http.Response response;
    try {
      response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(inputs))
          .timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const PredictionException([timeoutMessage]);
    } on http.ClientException {
      throw const PredictionException([unreachableMessage]);
    }

    final body = _decodeJson(response.body);
    if (response.statusCode == 200 && body is Map<String, dynamic>) {
      try {
        return PredictionResult.fromJson(body);
      } on TypeError {
        throw const PredictionException(
            ['The price service sent an unexpected answer. Please try again.']);
      }
    }
    throw PredictionException(_readApiErrors(response.statusCode, body));
  }

  Object? _decodeJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Turns the API's error response into short, plain messages.
  ///
  /// FastAPI validation errors (status 422) look like:
  /// {"detail": [{"loc": ["body", "market"], "msg": "Unknown market. ..."}]}
  List<String> _readApiErrors(int statusCode, Object? body) {
    final detail = body is Map<String, dynamic> ? body['detail'] : null;

    if (statusCode == 422 && detail is List) {
      return detail.map((error) {
        final key = (error['loc'] as List).last.toString();
        return messageForField(key, error['msg'].toString());
      }).toList();
    }
    return ['The price service had a problem (error $statusCode). Please try again in a minute.'];
  }

  /// A plain message for a field the API rejected.
  static String messageForField(String key, String apiMessage) {
    final field = predictionFields.where((field) => field.key == key).firstOrNull;
    if (field == null) return apiMessage;
    if (!field.isNumber) {
      // The app sends only names typed by the user, so a text field is
      // rejected because the name isn't in the model's list.
      final noun = field.label.toLowerCase();
      return 'That $noun isn’t in our list. Pick one from the suggestions.';
    }
    return '${field.label}: $apiMessage';
  }
}
