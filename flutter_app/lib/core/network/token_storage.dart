import 'package:shared_preferences/shared_preferences.dart';

/// Persists the access/refresh token pair between app launches.
///
/// Uses shared_preferences (not flutter_secure_storage) so the exact same
/// code works on both mobile and web with no platform-specific setup. For a
/// production app handling more sensitive data you'd want secure storage on
/// mobile; for this token pair (short-lived access token, revocable refresh
/// token) plain local storage is an accepted trade-off.
class TokenStorage {
  static const _keyAccessToken = 'access_token';
  static const _keyAccessExpiresAt = 'access_token_expires_at';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyRefreshExpiresAt = 'refresh_token_expires_at';

  Future<void> saveTokenPair({
    required String accessToken,
    required String accessTokenExpiresAt,
    required String refreshToken,
    required String refreshTokenExpiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyAccessToken, accessToken),
      prefs.setString(_keyAccessExpiresAt, accessTokenExpiresAt),
      prefs.setString(_keyRefreshToken, refreshToken),
      prefs.setString(_keyRefreshExpiresAt, refreshTokenExpiresAt),
    ]);
  }

  Future<String?> get accessToken async =>
      (await SharedPreferences.getInstance()).getString(_keyAccessToken);

  Future<String?> get refreshToken async =>
      (await SharedPreferences.getInstance()).getString(_keyRefreshToken);

  Future<bool> get hasRefreshToken async => (await refreshToken) != null;

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyAccessToken),
      prefs.remove(_keyAccessExpiresAt),
      prefs.remove(_keyRefreshToken),
      prefs.remove(_keyRefreshExpiresAt),
    ]);
  }
}
