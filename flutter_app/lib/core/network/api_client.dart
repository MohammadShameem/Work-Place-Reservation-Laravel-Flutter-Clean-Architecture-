import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_storage.dart';

/// Thin HTTP layer shared by every remote data source.
///
/// It knows how to attach the stored access token, and — the one non-obvious
/// part — how to recover from an expired access token transparently: on a
/// 401 it calls POST /refresh with the stored refresh token, saves the new
/// pair, and retries the original request exactly once. Callers never see
/// the 401 unless the refresh token itself is also gone/expired, in which
/// case [onSessionExpired] fires so the app can send the user back to login.
///
/// Everything it depends on is handed in ([baseUrl], [tokenStorage], the
/// http client) — it reads no globals — so a test can point it at a fake.
class ApiClient {
  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client _http;

  /// Called when both tokens are no longer usable. The auth data source turns
  /// this into a stream the rest of the app can listen to.
  void Function()? onSessionExpired;

  ApiClient({required this.baseUrl, required this.tokenStorage, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    String? idempotencyKey,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      auth: auth,
      extraHeaders: idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
    );
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path) {
    return _send('DELETE', path);
  }

  /// Sends one request. If it comes back 401 on an authenticated call, tries
  /// exactly one silent token refresh + retry before giving up.
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    bool auth = true,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, value.toString())),
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };

    if (auth) {
      final accessToken = await tokenStorage.accessToken;
      if (accessToken == null) {
        onSessionExpired?.call();
        throw const ApiException(statusCode: 401, message: 'Not logged in.');
      }
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await _httpSend(method, uri, headers, encodedBody);

    if (response.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          extraHeaders: extraHeaders,
          auth: auth,
          isRetry: true,
        );
      }

      await tokenStorage.clear();
      onSessionExpired?.call();
      throw ApiException.fromResponseBody(401, _tryDecode(response.body));
    }

    if (response.statusCode >= 400) {
      throw ApiException.fromResponseBody(response.statusCode, _tryDecode(response.body));
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  Future<http.Response> _httpSend(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: body);
      case 'PUT':
        return _http.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method $method');
    }
  }

  dynamic _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Trades the stored refresh token for a new pair. Returns false (without
  /// throwing) for any failure, since the caller's only decision is
  /// "retry the original request" vs "force a logout".
  Future<bool> _tryRefresh() async {
    final refreshToken = await tokenStorage.refreshToken;
    if (refreshToken == null) return false;

    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/refresh'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await tokenStorage.saveTokenPair(
        accessToken: data['access_token'] as String,
        accessTokenExpiresAt: data['access_token_expires_at'] as String,
        refreshToken: data['refresh_token'] as String,
        refreshTokenExpiresAt: data['refresh_token_expires_at'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
