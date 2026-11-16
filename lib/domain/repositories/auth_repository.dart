abstract class AuthRepository {
  Future<void> register({required String username, required String password});
  Future<String> login({required String username, required String password});
  Future<void> logout();
  Future<String?> getSavedToken();
  Future<String?> getUsername();
  Future<bool> isAuthenticated();
}
