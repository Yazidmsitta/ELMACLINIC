import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../api/api_client.dart';
import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../api/auth_session.dart';
import '../api/token_store.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api);
  final ApiClient api;
  AppUser _user(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid user');
    }
    final json = value;
    final role = switch (json['role']) {
      'ADMIN' => UserRole.admin,
      'USER' => UserRole.user,
      _ => throw const FormatException('Unknown role'),
    };
    if (json['id'] is! String ||
        json['name'] is! String ||
        json['email'] is! String) {
      throw const FormatException('Invalid user');
    }
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: role,
    );
  }

  @override
  Future<AppUser> login(
    String email,
    String password, {
    bool remember = true,
  }) => _guard(() async {
    final response = await api.dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    final data = response.data!;
    final user = _user(data['user']);
    if (api.tokens case final SessionTokenStore store) {
      await store.setPersistent(remember);
    }
    await api.saveSession(AuthSession.fromJson(data['session']));
    return user;
  });

  @override
  Future<AppUser?> restore() async {
    if (await api.tokens.read() == null) return null;
    try {
      final response = await api.dio.get<Map<String, dynamic>>('auth/me');
      return _user(response.data!['user']);
    } on FormatException {
      await api.clearSession();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await api.clearSession();
        return null;
      }
      throw AppFailure(apiErrorMessage(e));
    }
  }

  @override
  Future<void> logout() => _guard(() async {
    // Keep the session if revocation fails, so the user can retry securely.
    await api.dio.post<void>('auth/logout');
    await api.clearSession();
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw AppFailure(apiErrorMessage(error));
    }
  }
}
