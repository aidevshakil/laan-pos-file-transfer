import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  String? _token;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> register({required String username, required String password}) async {
    await remoteDataSource.register(username, password);
  }

  @override
  Future<String> login({required String username, required String password}) async {
    final token = await remoteDataSource.login(username, password);
    _token = token;
    return token;
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<String?> getSavedToken() async {
    return _token;
  }

  @override
  Future<bool> isAuthenticated() async {
    return _token != null && _token!.isNotEmpty;
  }
}
