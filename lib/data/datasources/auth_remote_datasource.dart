import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/transfer_exception.dart';

abstract class AuthRemoteDataSource {
  Future<String> login(String username, String password);
  Future<void> register(String username, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  Options get _formOptions => Options(contentType: Headers.formUrlEncodedContentType);

  @override
  Future<void> register(String username, String password) async {
    try {
      final response = await dio.post(
        ApiConstants.registerEndpoint,
        data: {'username': username, 'password': password},
        options: _formOptions,
      );
      final data = response.data;
      if (data is Map && data['success'] == false) {
        throw Exception(TransferException.serverMessage(data) ?? 'Registration failed');
      }
    } on DioException catch (e) {
      throw Exception(_authMessage(e, fallback: 'Registration failed'));
    }
  }

  @override
  Future<String> login(String username, String password) async {
    try {
      final response = await dio.post(
        ApiConstants.tokenEndpoint,
        data: {'username': username, 'password': password},
        options: _formOptions,
      );
      final data = response.data;
      String token = '';
      if (data is Map) {
        token = (data['access_token'] ?? data['token'] ?? data['accessToken'] ?? '').toString();
      } else if (data is String) {
        token = data.trim();
      }
      if (token.isEmpty) throw Exception('Server did not return a token');
      return token;
    } on DioException catch (e) {
      throw Exception(_authMessage(e, fallback: 'Login failed'));
    }
  }

  String _authMessage(DioException e, {required String fallback}) {
    final serverMsg = TransferException.serverMessage(e.response?.data);
    if (serverMsg != null) return serverMsg;
    final mapped = TransferException.fromDio(e);
    return mapped.kind == TransferErrorKind.unknown ? fallback : mapped.message;
  }
}
