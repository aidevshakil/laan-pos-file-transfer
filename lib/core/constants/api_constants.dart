/// Central API Constants for the LAAN TECH POS Transfer Module.
class ApiConstants {
  ApiConstants._();

  /// Mock server base URL provided in technical assessment.
  /// Can be overridden dynamically in login screen if needed.
  static const String defaultBaseUrl = 'http://108.136.142.112:90';

  /// Auth token endpoint: POST /token
  static const String tokenEndpoint = '/token';

  /// Register endpoint: POST /register
  static const String registerEndpoint = '/register';

  /// File list / Download endpoint: GET /get (or GET /get?file=NAME)
  static const String getFilesEndpoint = '/get';

  /// Multipart File Upload endpoint: POST /upload
  static const String uploadEndpoint = '/upload';

  /// File Deletion endpoint: DELETE /delete?file=NAME
  static const String deleteEndpoint = '/delete';

  /// Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(minutes: 10);
  static const Duration sendTimeout = Duration(minutes: 15);
}
