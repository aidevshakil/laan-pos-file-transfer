class ApiConstants {
  ApiConstants._();

  static const String defaultBaseUrl = 'http://108.136.142.112:90';

  static const String tokenEndpoint = '/token';

  static const String registerEndpoint = '/register';

  static const String getFilesEndpoint = '/get';

  static const String uploadEndpoint = '/upload';

  static const String deleteEndpoint = '/delete';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(minutes: 10);
  static const Duration sendTimeout = Duration(minutes: 15);
}
