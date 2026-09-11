import 'package:flutter/foundation.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.repository);
  final AuthRepository repository;
  AppUser? user;
  bool loading = true;
  bool initialized = false;
  Object? error;
  Future<void> restore() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await repository.restore();
    } catch (e) {
      error = e;
    }
    initialized = true;
    loading = false;
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    bool remember = true,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await repository.login(email, password, remember: remember);
    } catch (e) {
      error = e;
    }
    initialized = true;
    loading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.logout();
    expire();
  }

  void expire() {
    user = null;
    error = null;
    notifyListeners();
  }
}
