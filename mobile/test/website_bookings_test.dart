import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/appointments/appointments.dart';
import 'package:elmaclinic/domain/website/website_bookings.dart';
import 'package:elmaclinic/presentation/website/website_bookings_screen.dart';
import 'appointments_test.dart' show FakeAppointments;
import 'catalog_test.dart' show FakeCatalog, catalogApp;

class FakeWebsite implements WebsiteBookingsRepository {
  @override
  Future<void> archiveImported(WebsiteBooking event) async {}
  @override
  Future<void> dismiss(WebsiteBooking event, String reason) async {
    if (failDismiss) throw const AppFailure('Échec de l’enregistrement.');
    dismissedReason = reason;
  }

  bool failDismiss = false;
  String? dismissedReason;
  bool fail = false, failImport = false;
  int imports = 0;
  DateTime? importedStart;
  final filters = <WebsiteState>[];
  final event = WebsiteBooking(
    id: 'event',
    version: 1,
    state: WebsiteState.review,
    clientName: 'Cliente de démonstration',
    phone: '0600000000',
    start: DateTime.utc(2030, 1, 7, 9),
    serviceReferences: const ['soin-visage'],
  );
  @override
  Future<WebsitePage> list(WebsiteState state, {int page = 1}) async {
    filters.add(state);
    if (fail) throw const AppFailure('Liste indisponible.');
    return WebsitePage(
      state == WebsiteState.review ? [event] : [],
      state == WebsiteState.review ? 1 : 0,
      false,
    );
  }

  @override
  Future<String> importBooking(
    WebsiteBooking event,
    BookingSelection selection,
    BookingQuote quote,
    String? notes,
  ) async {
    imports++;
    importedStart = selection.start;
    if (failImport) throw const AppFailure('Import interrompu.');
    return 'appointment';
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'website filters and failed reload do not claim synchronization',
    (tester) async {
      final repo = FakeWebsite();
      await tester.pumpWidget(
        catalogApp(
          WebsiteBookingsScreen(
            repository: repo,
            appointments: FakeAppointments(),
            catalog: FakeCatalog(),
            isAdmin: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cliente de démonstration'), findsOneWidget);
      expect(find.textContaining('Synchronisé'), findsNothing);
      await tester.tap(find.text('Importées'));
      await tester.pumpAndSettle();
      expect(repo.filters.last, WebsiteState.imported);
      expect(find.text('Aucune réservation pour ce filtre'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.byTooltip('Actualiser la liste'));
      await tester.pumpAndSettle();
      expect(find.text('Liste indisponible.'), findsOneWidget);
      expect(find.text('Aucune réservation pour ce filtre'), findsNothing);
    },
  );
  testWidgets('review requires explicit mapping before the wizard', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        WebsiteBookingsScreen(
          repository: FakeWebsite(),
          appointments: FakeAppointments(),
          catalog: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente de démonstration'));
    await tester.pumpAndSettle();
    expect(find.text('Vérifier la demande'), findsOneWidget);
    await tester.tap(find.text('Associer les fiches'));
    await tester.pumpAndSettle();
    expect(find.text('Importer la réservation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'website import keeps requested instant and never creates a manual appointment',
    (tester) async {
      final repo = FakeWebsite()..failImport = true;
      final appointments = FakeAppointments();
      await tester.pumpWidget(
        catalogApp(
          WebsiteBookingsScreen(
            repository: repo,
            appointments: appointments,
            catalog: FakeCatalog(),
            isAdmin: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente de démonstration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Associer les fiches'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.text('Soin de démonstration'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Choisir une date'), findsNothing);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importer · Nouveau'));
      await tester.pumpAndSettle();
      expect(find.text('Import interrompu.'), findsOneWidget);
      expect(appointments.creates, 0);
      repo.failImport = false;
      await tester.tap(find.text('Importer · Nouveau'));
      await tester.pumpAndSettle();
      expect(repo.imports, 2);
      expect(repo.importedStart, repo.event.start);
      expect(appointments.creates, 0);
      expect(find.text('Détail du rendez-vous'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dismissal requires a reason and preserves it after failure', (
    tester,
  ) async {
    final repo = FakeWebsite()..failDismiss = true;
    await tester.pumpWidget(
      catalogApp(
        WebsiteBookingsScreen(
          repository: repo,
          appointments: FakeAppointments(),
          catalog: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cliente de démonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écarter la demande'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Écarter'));
    await tester.pumpAndSettle();
    expect(repo.dismissedReason, isNull);
    expect(
      find.text('Indiquez un motif (3 caractères minimum).'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Doublon vérifié');
    await tester.tap(find.text('Écarter'));
    await tester.pumpAndSettle();
    expect(find.text('Échec de l’enregistrement.'), findsOneWidget);
    expect(find.text('Doublon vérifié'), findsOneWidget);
    repo.failDismiss = false;
    await tester.tap(find.text('Écarter'));
    await tester.pumpAndSettle();
    expect(repo.dismissedReason, 'Doublon vérifié');
    await tester.tap(find.text('Écartées'));
    await tester.pumpAndSettle();
    expect(repo.filters.last, WebsiteState.dismissed);
  });
}
