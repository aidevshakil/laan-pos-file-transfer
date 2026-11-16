import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/local_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final LocalStorage storage;

  AuthRepositoryImpl({required this.remoteDataSource, required this.storage});

  @override
  Future<void> register({required String username, required String password}) =>
      remoteDataSource.register(username, password);

  @override
  Future<String> login({required String username, required String password}) async {
    final token = await remoteDataSource.login(username, password);
    await storage.saveSession(token, username);
    return token;
  }

  @override
  Future<void> logout() => storage.clearSession();

  @override
  Future<String?> getSavedToken() async => storage.token;

  @override
  Future<String?> getUsername() async => storage.username;

  @override
  Future<bool> isAuthenticated() async => (storage.token ?? '').isNotEmpty;
}
