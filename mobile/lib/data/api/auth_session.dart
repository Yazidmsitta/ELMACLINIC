import 'dart:convert';

class AuthSession {
  const AuthSession(this.accessToken, this.refreshToken, this.expiresAt);
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  factory AuthSession.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid session');
    }
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiry = json['expires_at'];
    if (access is! String ||
        refresh is! String ||
        expiry is! int ||
        access.isEmpty ||
        refresh.isEmpty ||
        expiry <= 0) {
      throw const FormatException('Invalid session');
    }
    return AuthSession(access, refresh, expiry);
  }
  factory AuthSession.decode(String value) =>
      AuthSession.fromJson(jsonDecode(value));
  String encode() => jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt,
  });
}
