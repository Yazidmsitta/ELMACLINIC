import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_store.dart';
import 'auth_session.dart';

class ApiClient {
  ApiClient(this.tokens, {String? baseUrl}) {
    final url =
        baseUrl ??
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000/api/v1/',
        );
    final uri = Uri.parse(url);
    if (!uri.hasAuthority ||
        !url.endsWith('/') ||
        (kReleaseMode && uri.scheme != 'https')) {
      throw ArgumentError(
        'API_BASE_URL must be an absolute URL with a trailing slash; release requires HTTPS.',
      );
    }
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (!['auth/login', 'auth/refresh'].contains(options.path)) {
              final token = await tokens.read();
              if (token != null) {
                options.headers['Authorization'] =
                    'Bearer ${AuthSession.decode(token).accessToken}';
              }
            }
            handler.next(options);
          } on FormatException catch (error) {
            await clearSession();
            onUnauthorized?.call();
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 401,
                ),
              ),
            );
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          final generation = _generation;
          if (error.response?.statusCode == 401 &&
              ![
                'auth/login',
                'auth/refresh',
              ].contains(error.requestOptions.path)) {
            if (error.requestOptions.extra['retried'] != true) {
              try {
                await _refresh(
                  error.requestOptions.headers['Authorization'] as String?,
                );
                error.requestOptions.extra['retried'] = true;
                handler.resolve(await dio.fetch<dynamic>(error.requestOptions));
                return;
              } on DioException catch (refreshError) {
                if (refreshError.response?.statusCode != 401 &&
                    refreshError.response?.statusCode != 403) {
                  handler.reject(refreshError);
                  return;
                }
              } on FormatException {
                // Corrupt or legacy sessions must be rejected.
              }
            }
            if (_generation == generation) {
              await clearSession();
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }
  Future<void>? _refreshing;
  Future<void> _storageQueue = Future<void>.value();
  int _generation = 0;
  Future<void> _store(Future<void> Function() operation) {
    final pending = _storageQueue.then((_) => operation());
    _storageQueue = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> saveSession(AuthSession session) async {
    _generation++;
    await _store(() => tokens.write(session.encode()));
  }

  Future<void> clearSession() async {
    _generation++;
    await _store(tokens.clear);
  }

  Future<void> _refresh(String? failedAuthorization) async {
    final current = await tokens.read();
    if (current == null) throw const FormatException('Missing session');
    final session = AuthSession.decode(current);
    // A concurrent request may already have rotated this token.
    if (failedAuthorization != 'Bearer ${session.accessToken}') return;
    if (_refreshing != null) return _refreshing!;
    final generation = _generation;
    final pending = () async {
      final response = await dio.post<Map<String, dynamic>>(
        'auth/refresh',
        data: {'refresh_token': session.refreshToken},
      );
      final next = AuthSession.fromJson(response.data!['session']);
      await _store(() async {
        if (_generation != generation) {
          throw const FormatException('Session changed');
        }
        await tokens.write(next.encode());
      });
    }();
    _refreshing = pending;
    try {
      await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  final TokenStore tokens;
  late final Dio dio;
  VoidCallback? onUnauthorized;
}

String apiErrorMessage(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode == 401 &&
        error.requestOptions.path == 'auth/login') {
      return 'Connexion refusée. Vérifiez votre adresse e-mail et votre mot de passe.';
    }
    return switch (error.response?.statusCode) {
      401 => 'Votre session a expiré. Veuillez vous reconnecter.',
      403 => 'Vous ne disposez pas des autorisations nécessaires.',
      422 => 'Vérifiez les informations saisies.',
      429 => 'Trop de tentatives. Réessayez dans une minute.',
      501 => 'Ce module sera disponible dans une prochaine phase.',
      _ => 'Connexion impossible. Vérifiez votre réseau et réessayez.',
    };
  }
  return 'Une erreur est survenue. Veuillez réessayer.';
}
