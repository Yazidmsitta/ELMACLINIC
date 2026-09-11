import 'app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser?> restore();
  Future<AppUser> login(String email, String password, {bool remember = true});
  Future<void> logout();
}
