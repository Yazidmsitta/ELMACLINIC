@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/main.dart';
import 'package:elmaclinic/domain/auth/app_user.dart';
import 'package:elmaclinic/domain/dashboard/dashboard.dart';
import 'package:elmaclinic/presentation/auth/auth_controller.dart';
import 'auth_navigation_test.dart' show FakeAuth;

class ElmaVisualBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

// Deliberate visual fixtures, never imported into production code.
class VisualDashboard implements DashboardRepository {
  VisualDashboard({this.empty = false, this.failure = false});
  final bool empty, failure;
  @override
  Future<Dashboard> load() async {
    if (failure) throw Exception('Test outage');
    return Dashboard(
      date: DateTime(2026, 9, 9),
      appointments: empty ? 0 : 4,
      clients: empty ? 0 : 128,
      pending: empty ? 0 : 2,
      websiteNew: empty ? 0 : 2,
      revenueCentimes: empty ? 0 : 150000,
      schedule: empty
          ? []
          : const [
              ScheduleEntry(
                id: 'test',
                time: '10:30',
                duration: 45,
                client: 'Cliente de démonstration',
                service: 'Soin du visage',
                status: 'CONFIRMED',
                source: 'MANUAL',
              ),
            ],
      notifications: const [],
      week: List.generate(
        7,
        (i) =>
            RevenueDay(DateTime(2026, 9, 7 + i), empty ? 0 : (i + 1) * 20000),
      ),
    );
  }
}

void main() {
  ElmaVisualBinding();
  setUpAll(() async {
    await initializeDateFormatting('fr');
    for (final font in [
      ('Plus Jakarta Sans', 'PlusJakartaSans.ttf'),
      ('DM Serif Display', 'DMSerifDisplay-Regular.ttf'),
      ('Noto Color Emoji', 'NotoColorEmoji.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });
  Future<void> viewport(WidgetTester tester, {double width = 390}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/branding/logo.png'),
        tester.element(find.byType(MaterialApp)),
      );
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Login reference layout', (tester) async {
    await viewport(tester);
    final auth = AuthController(FakeAuth(UserRole.user));
    await auth.restore();
    await tester.pumpWidget(ElmaClinicApp(auth: auth));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login.png'),
    );
    await tester.tap(find.text('Connexion'));
    await settle(tester);
    expect(find.text('Saisissez une adresse e-mail valide.'), findsOneWidget);
  });
  for (final role in UserRole.values) {
    testWidgets('Dashboard and Plus ${role.name}', (tester) async {
      await viewport(tester);
      final auth = AuthController(FakeAuth(role));
      await auth.login('staff@example.test', 'test');
      await tester.pumpWidget(
        ElmaClinicApp(auth: auth, dashboard: VisualDashboard()),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.text('Chiffre du jour'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Recettes — Cette semaine'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dashboard_${role.name}.png'),
      );
      await tester.tap(find.text('Plus'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/more_${role.name}.png'),
      );
    });
  }
  testWidgets('Compact large-text and keyboard login remain scrollable', (
    tester,
  ) async {
    await viewport(tester, width: 320);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    final auth = AuthController(FakeAuth(UserRole.user));
    await auth.restore();
    await tester.pumpWidget(ElmaClinicApp(auth: auth));
    await settle(tester);
    await tester.ensureVisible(find.text('Connexion'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Dashboard empty and retry states', (tester) async {
    await viewport(tester, width: 360);
    final auth = AuthController(FakeAuth(UserRole.user));
    await auth.login('staff@example.test', 'test');
    await tester.pumpWidget(
      ElmaClinicApp(auth: auth, dashboard: VisualDashboard(empty: true)),
    );
    await settle(tester);
    expect(find.text('Votre agenda est libre'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/empty.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ElmaClinicApp(auth: auth, dashboard: VisualDashboard(failure: true)),
    );
    await settle(tester);
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await settle(tester);
    expect(find.text('Connexion indisponible'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/error.png'),
    );
    expect(tester.takeException(), isNull);
  });
}
