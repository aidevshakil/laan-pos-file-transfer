import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import 'dart:developer' as developer;

abstract class AuthRemoteDataSource {
  Future<String> login(String username, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<String> login(String username, String password) async {
    try {
      final response = await dio.post(
        '${ApiConstants.defaultBaseUrl}${ApiConstants.tokenEndpoint}',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      developer.log('Login Response: ${response.statusCode} -> ${response.data}');

      if (response.statusCode == 200) {
        if (response.data is Map) {
          final data = response.data as Map;
          return (data['access_token'] ?? data['token'] ?? data['accessToken'] ?? '').toString();
        } else if (response.data is String) {
          return response.data.toString();
        }
      }
      throw Exception('Failed to obtain token: ${response.statusCode}');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      throw Exception('Authentication failed: $errorMsg');
    }
  }
}
