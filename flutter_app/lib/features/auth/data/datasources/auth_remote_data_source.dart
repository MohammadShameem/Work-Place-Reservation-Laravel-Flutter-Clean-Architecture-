import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/token_storage.dart';

/// Talks to /register, /login, /user and /logout, and keeps the saved tokens.
/// Returns raw JSON; turning it into entities is the repository's job.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required this.client,
    required this.tokenStorage,
    required this.deviceName,
  }) {
    client.onSessionExpired = () => _sessionExpired.add(null);
  }

  final ApiClient client;
  final TokenStorage tokenStorage;
  final String deviceName;
  final _sessionExpired = StreamController<void>.broadcast();

  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<bool> hasStoredSession() => tokenStorage.hasRefreshToken;

  Future<void> clearSession() => tokenStorage.clear();

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await client.post(
      '/register',
      auth: false,
      body: {'name': name, 'email': email, 'password': password, 'device_name': deviceName},
    );
    return _saveTokensAndReturnUser(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final data = await client.post(
      '/login',
      auth: false,
      body: {'email': email, 'password': password, 'device_name': deviceName},
    );
    return _saveTokensAndReturnUser(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> currentUser() async {
    return (await client.get('/user')) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await client.post('/logout');
  }

  Future<void> dispose() => _sessionExpired.close();

  Future<Map<String, dynamic>> _saveTokensAndReturnUser(Map<String, dynamic> data) async {
    await tokenStorage.saveTokenPair(
      accessToken: data['access_token'] as String,
      accessTokenExpiresAt: data['access_token_expires_at'] as String,
      refreshToken: data['refresh_token'] as String,
      refreshTokenExpiresAt: data['refresh_token_expires_at'] as String,
    );
    return data['user'] as Map<String, dynamic>;
  }
}
