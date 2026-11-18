/// Settings for talking to the prediction API.
///
/// The API runs on Render. [baseUrl] has no trailing slash.
class ApiConfig {
  static const String baseUrl = 'https://food-price-api-w69y.onrender.com';
  static const String predictPath = '/predict';

  /// A free Render service sleeps after 15 minutes without traffic and can
  /// take up to a minute to wake up, so we wait longer than usual.
  static const Duration requestTimeout = Duration(seconds: 90);
}
