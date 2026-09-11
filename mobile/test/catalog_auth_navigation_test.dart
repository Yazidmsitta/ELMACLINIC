import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/main.dart';
import 'package:elmaclinic/domain/auth/app_user.dart';
import 'package:elmaclinic/presentation/auth/auth_controller.dart';
import 'package:elmaclinic/presentation/auth/login_screen.dart';
import 'package:elmaclinic/presentation/catalog/catalog_screen.dart';
import 'auth_navigation_test.dart' show FakeAuth;
import 'catalog_test.dart' show FakeCatalog;

void main() {
  testWidgets('expired identity closes open catalog routes', (tester) async {
    await initializeDateFormatting('fr');
    final auth = AuthController(FakeAuth(UserRole.admin));
    await auth.login('admin@example.test', 'password');
    await tester.pumpWidget(ElmaClinicApp(auth: auth, catalog: FakeCatalog()));
    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prestations'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    auth.expire();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
