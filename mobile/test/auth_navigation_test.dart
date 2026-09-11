import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/main.dart';
import 'package:elmaclinic/domain/auth/app_user.dart';
import 'package:elmaclinic/domain/auth/auth_repository.dart';
import 'package:elmaclinic/presentation/auth/auth_controller.dart';

class FakeAuth implements AuthRepository {
  FakeAuth(this.role);
  final UserRole role;
  @override
  Future<AppUser?> restore() async => null;
  @override
  Future<AppUser> login(
    String email,
    String password, {
    bool remember = true,
  }) async => AppUser(
    id: '00000000-0000-4000-8000-000000000001',
    name: 'Équipe',
    email: email,
    role: role,
  );
  @override
  Future<void> logout() async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets('Login has email and password without a role selector', (
    tester,
  ) async {
    final auth = AuthController(FakeAuth(UserRole.user));
    await auth.restore();
    await tester.pumpWidget(ElmaClinicApp(auth: auth));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('ADMIN'), findsNothing);
    expect(find.text('USER'), findsNothing);
  });
  for (final role in UserRole.values) {
    testWidgets('Navigation uses authenticated $role role', (tester) async {
      final auth = AuthController(FakeAuth(role));
      await auth.login('team@example.test', 'password');
      await tester.pumpWidget(ElmaClinicApp(auth: auth));
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      expect(find.text('Prestations'), findsOneWidget);
      expect(
        find.text('Utilisateurs'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Consultation uniquement'),
        role == UserRole.user ? findsNWidgets(2) : findsNothing,
      );
    });
  }
}
