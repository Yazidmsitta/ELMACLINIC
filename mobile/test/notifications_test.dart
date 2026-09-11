import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/notifications/notifications.dart';
import 'package:elmaclinic/presentation/notifications/notifications_screen.dart';
import 'catalog_test.dart' show catalogApp;

class FakeNotifications implements NotificationsRepository {
  bool fail = true, read = false;
  @override
  Future<NotificationPage> list({int page = 1}) async => NotificationPage([
    ClinicNotification(
      'id',
      'WEBSITE_BOOKING',
      DateTime.utc(2026, 9, 11, 9),
      read ? DateTime.utc(2026, 9, 11, 10) : null,
    ),
  ], false);
  @override
  Future<void> markRead(String id) async {
    if (fail) throw const AppFailure('Connexion interrompue.');
    read = true;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'failed read stays unread and successful retry reloads server state',
    (tester) async {
      final repo = FakeNotifications();
      await tester.pumpWidget(
        catalogApp(NotificationsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marquer comme lue'));
      await tester.pumpAndSettle();
      expect(find.text('Connexion interrompue.'), findsOneWidget);
      expect(find.text('Lue'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Marquer comme lue'));
      await tester.pumpAndSettle();
      expect(find.text('Lue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
