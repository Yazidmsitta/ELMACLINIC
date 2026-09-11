import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Non-remembered sessions live only in memory, never on disk.
class SessionTokenStore implements TokenStore {
  SessionTokenStore(this.secure);
  final TokenStore secure;
  bool _persistent = true;
  String? _memory;
  Future<void> setPersistent(bool value) async {
    await secure.clear();
    _memory = null;
    _persistent = value;
  }

  @override
  Future<String?> read() async => _persistent ? secure.read() : _memory;
  @override
  Future<void> write(String token) async {
    if (_persistent) {
      await secure.write(token);
    } else {
      _memory = token;
    }
  }

  @override
  Future<void> clear() async {
    _memory = null;
    await secure.clear();
  }
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'elmaclinic.supabase_session.v1';
  @override
  Future<String?> read() async {
    // The Laravel token cannot authenticate with the new backend.
    await _storage.delete(key: 'elmaclinic.access_token');
    return _storage.read(key: _key);
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
