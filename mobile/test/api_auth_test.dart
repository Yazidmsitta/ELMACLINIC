import 'dart:convert';
import 'package:elmaclinic/data/api/auth_session.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/api/token_store.dart';
import 'package:elmaclinic/data/auth/api_auth_repository.dart';
import 'package:elmaclinic/domain/auth/app_user.dart';
import 'package:elmaclinic/domain/app_failure.dart';

class MemoryTokens implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int code = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  code,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test(
    'Login stores token and uses backend role without sending a role',
    () async {
      final tokens = MemoryTokens();
      final api = ApiClient(tokens);
      api.dio.httpClientAdapter = StubAdapter((options) {
        expect(
          (options.data as Map<String, dynamic>).containsKey('role'),
          false,
        );
        expect(options.headers.containsKey('Authorization'), false);
        return jsonBody({
          'session': {
            'access_token': 'test-token',
            'refresh_token': 'refresh',
            'expires_at': 2000000000,
          },
          'user': {
            'id': '00000000-0000-4000-8000-000000000001',
            'name': 'Admin',
            'email': 'a@example.test',
            'role': 'ADMIN',
          },
        });
      });
      final user = await ApiAuthRepository(
        api,
      ).login('a@example.test', 'secret');
      expect(user.role, UserRole.admin);
      expect(AuthSession.decode(tokens.value!).accessToken, 'test-token');
    },
  );
  test('An unknown role fails closed before token persistence', () async {
    final tokens = MemoryTokens();
    final api = ApiClient(tokens);
    api.dio.httpClientAdapter = StubAdapter(
      (_) => jsonBody({
        'session': {
          'access_token': 'test-token',
          'refresh_token': 'refresh',
          'expires_at': 2000000000,
        },
        'user': {'role': 'OWNER'},
      }),
    );
    await expectLater(
      ApiAuthRepository(api).login('a@example.test', 'secret'),
      throwsFormatException,
    );
    expect(tokens.value, isNull);
  });
  test('401 clears token and notifies session controller', () async {
    final tokens = MemoryTokens()
      ..value = const AuthSession('expired', 'refresh', 1).encode();
    final api = ApiClient(tokens);
    bool expired = false;
    api.onUnauthorized = () => expired = true;
    api.dio.httpClientAdapter = StubAdapter((options) {
      if (options.path != 'auth/refresh') {
        expect(options.headers['Authorization'], 'Bearer expired');
      }
      return jsonBody({'message': 'Unauthenticated'}, 401);
    });
    expect(await ApiAuthRepository(api).restore(), isNull);
    expect(tokens.value, isNull);
    expect(expired, true);
  });
  test(
    'Transient restore and logout failure preserve token for retry',
    () async {
      final tokens = MemoryTokens()
        ..value = const AuthSession('valid', 'refresh', 2000000000).encode();
      final api = ApiClient(tokens);
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'message': 'Unavailable'}, 503),
      );
      final repository = ApiAuthRepository(api);
      await expectLater(repository.restore(), throwsA(isA<AppFailure>()));
      expect(AuthSession.decode(tokens.value!).accessToken, 'valid');
      await expectLater(repository.logout(), throwsA(isA<AppFailure>()));
      expect(AuthSession.decode(tokens.value!).accessToken, 'valid');
    },
  );
  test(
    'Concurrent expired requests rotate the session once and retry',
    () async {
      final tokens = MemoryTokens()
        ..value = const AuthSession('old', 'refresh', 1).encode();
      final api = ApiClient(tokens);
      var refreshes = 0;
      api.dio.httpClientAdapter = StubAdapter((options) {
        if (options.path == 'auth/refresh') {
          refreshes++;
          expect(options.data, {'refresh_token': 'refresh'});
          return jsonBody({
            'session': {
              'access_token': 'new',
              'refresh_token': 'rotated',
              'expires_at': 2000000000,
            },
          });
        }
        if (options.headers['Authorization'] == 'Bearer old') {
          return jsonBody({}, 401);
        }
        expect(options.headers['Authorization'], 'Bearer new');
        return jsonBody({'data': <dynamic>[]});
      });
      await Future.wait([
        api.dio.get<dynamic>('clients'),
        api.dio.get<dynamic>('services'),
      ]);
      expect(refreshes, 1);
      expect(AuthSession.decode(tokens.value!).refreshToken, 'rotated');
    },
  );
  test('Transient refresh failure preserves the session', () async {
    final tokens = MemoryTokens()
      ..value = const AuthSession('old', 'refresh', 1).encode();
    final api = ApiClient(tokens);
    api.dio.httpClientAdapter = StubAdapter(
      (options) => jsonBody({}, options.path == 'auth/refresh' ? 503 : 401),
    );
    await expectLater(
      ApiAuthRepository(api).restore(),
      throwsA(isA<AppFailure>()),
    );
    expect(AuthSession.decode(tokens.value!).accessToken, 'old');
  });
  test(
    'Se souvenir controls durable storage without persisting passwords',
    () async {
      final secure = MemoryTokens();
      final session = SessionTokenStore(secure);
      await session.setPersistent(false);
      await session.write('session-only');
      expect(await session.read(), 'session-only');
      expect(secure.value, isNull);
      expect(await SessionTokenStore(secure).read(), isNull);
      await session.setPersistent(true);
      await session.write('remembered');
      expect(await SessionTokenStore(secure).read(), 'remembered');
      await session.clear();
      expect(await session.read(), isNull);
    },
  );
}
