/// Settings for talking to the prediction API.
///
/// After deploying the API on Render, replace [baseUrl] with your own
/// service address (without a trailing slash).
class ApiConfig {
  static const String baseUrl = 'https://your-service.onrender.com';
  static const String predictPath = '/predict';

  /// A free Render service sleeps after 15 minutes without traffic and can
  /// take up to a minute to wake up, so we wait longer than usual.
  static const Duration requestTimeout = Duration(seconds: 90);
}
