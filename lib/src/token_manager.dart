import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';

/// Manages OAuth2 access tokens for Google Cloud Speech-to-Text API
class TokenManager {
  static AccessCredentials? _credentials;
  static DateTime? _tokenExpiry;
  static ServiceAccountCredentials? _serviceAccountCreds;

  /// Initialize with service account JSON
  static Future<void> initializeWithServiceAccount(
    Map<String, dynamic> serviceAccountJson,
  ) async {
    print('🔑 TokenManager - Initializing with service account');

    _serviceAccountCreds = ServiceAccountCredentials.fromJson(
      serviceAccountJson,
    );

    print(
      '🔑 TokenManager - Service account loaded: ${serviceAccountJson['client_email']}',
    );

    // Generate initial token
    await _refreshToken();
  }

  /// Initialize with service account JSON string
  static Future<void> initializeWithServiceAccountString(
    String serviceAccountJsonString,
  ) async {
    print('🔑 TokenManager - Parsing service account JSON string');
    final Map<String, dynamic> serviceAccountJson = json.decode(
      serviceAccountJsonString,
    );
    await initializeWithServiceAccount(serviceAccountJson);
  }

  /// Get current access token, refreshing if necessary
  static Future<String> getAccessToken() async {
    print('🔑 TokenManager - Getting access token');

    if (_credentials == null || _isTokenExpired()) {
      print('🔑 TokenManager - Token expired or not available, refreshing...');
      await _refreshToken();
    } else {
      print('🔑 TokenManager - Using cached token');
    }

    if (_credentials?.accessToken.data == null) {
      throw Exception('Failed to obtain access token');
    }

    return _credentials!.accessToken.data;
  }

  /// Check if token is expired or about to expire (within 5 minutes)
  static bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;

    final now = DateTime.now();
    final bufferTime = const Duration(minutes: 5);

    final isExpired = now.isAfter(_tokenExpiry!.subtract(bufferTime));
    print(
      '🔑 TokenManager - Token expired: $isExpired (expires at $_tokenExpiry)',
    );

    return isExpired;
  }

  /// Refresh the access token
  static Future<void> _refreshToken() async {
    if (_serviceAccountCreds == null) {
      throw Exception(
        'Service account credentials not initialized. Call initializeWithServiceAccount first.',
      );
    }

    print('🔑 TokenManager - Requesting new access token...');

    try {
      // Define the required scopes for Speech-to-Text API
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

      // Obtain credentials
      final client = await clientViaServiceAccount(
        _serviceAccountCreds!,
        scopes,
      );

      _credentials = client.credentials;

      // Set expiry time (typically 1 hour from now)
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

      print('🔑 TokenManager - New token obtained, expires at $_tokenExpiry');

      // Close the client as we only needed it to get credentials
      client.close();
    } catch (e) {
      print('❌ TokenManager - Error refreshing token: $e');
      rethrow;
    }
  }

  /// Clear cached credentials
  static void clearCredentials() {
    print('🔑 TokenManager - Clearing cached credentials');
    _credentials = null;
    _tokenExpiry = null;
    _serviceAccountCreds = null;
  }
}
