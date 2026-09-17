import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/appointments/appointments.dart';
import 'package:elmaclinic/presentation/appointments/appointments_screen.dart';
import 'package:elmaclinic/presentation/appointments/appointment_detail.dart';
import 'package:elmaclinic/presentation/appointments/booking_wizard.dart';
import 'catalog_test.dart' show FakeCatalog, catalogApp;

class FakeAppointments implements AppointmentsRepository {
  bool fail = false, failCreate = false;
  int reads = 0, creates = 0;
  final List<String> keys = [];
  final List<DateTime> days = [];
  final List<AppointmentSource?> sources = [];
  ClinicAppointment appointment = ClinicAppointment(
    id: 'appointment',
    clientId: 'client',
    clientName: 'Cliente de démonstration',
    clientPhone: '0600000000',
    practitionerId: 'practitioner',
    practitionerName: 'Praticienne de démonstration',
    start: DateTime.utc(2030, 1, 7, 9),
    end: DateTime.utc(2030, 1, 7, 9, 30),
    status: AppointmentStatus.confirmed,
    source: AppointmentSource.website,
    version: 1,
    services: const [BookingItem('service', 'Soin du visage', 30, 20000, 1)],
    totalCentimes: 20000,
  );
  @override
  Future<AppointmentPage> list(
    DateTime day, {
    int page = 1,
    AppointmentStatus? status,
    AppointmentSource? source,
    String? practitionerId,
  }) async {
    days.add(day);
    sources.add(source);
    if (fail) throw const AppFailure('Agenda indisponible.');
    return AppointmentPage([appointment], 1, false);
  }

  @override
  Future<ClinicAppointment> details(String id) async {
    reads++;
    if (fail) throw const AppFailure('Rendez-vous introuvable.');
    return appointment;
  }

  @override
  Future<BookingQuote> quote(BookingSelection selection) async => BookingQuote(
    selection.start,
    selection.start.add(const Duration(minutes: 30)),
    30,
    20000,
    appointment.services,
  );
  @override
  Future<String> create(
    BookingSelection selection,
    BookingQuote quote,
    String? notes,
    String requestId,
  ) async {
    creates++;
    keys.add(requestId);
    if (failCreate) throw const AppFailure('Connexion interrompue. Réessayez.');
    return appointment.id;
  }

  @override
  Future<void> changeStatus(
    ClinicAppointment appointment,
    AppointmentStatus status,
  ) async {}
  @override
  Future<void> archive(ClinicAppointment appointment) async {}
  @override
  Future<void> reschedule(
    ClinicAppointment appointment,
    String practitionerId,
    DateTime start,
    String? notes,
  ) async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets('booking service step uses prestation cards and category pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        BookingWizard(repository: FakeAppointments(), catalog: FakeCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soin de démonstration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir la prestation'), findsOneWidget);
    expect(find.text('Sélectionnez le soin ou service'), findsOneWidget);
    expect(find.text('Toutes'), findsOneWidget);
    expect(find.text('Soin de démonstration'), findsOneWidget);
  });

  testWidgets('day navigation and source filters request authoritative data', (
    tester,
  ) async {
    final repository = FakeAppointments();
    await tester.pumpWidget(
      catalogApp(
        AppointmentsScreen(
          repository: repository,
          catalog: FakeCatalog(),
          isAdmin: false,
          initialDay: DateTime(2030, 1, 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cliente de démonstration'), findsOneWidget);
    await tester.tap(find.byTooltip('Semaine suivante'));
    await tester.pumpAndSettle();
    expect(repository.days.last, DateTime(2030, 1, 14));
    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Site web'));
    await tester.pumpAndSettle();
    expect(repository.sources.last, AppointmentSource.website);
  });
  testWidgets('failed detail load never substitutes another appointment', (
    tester,
  ) async {
    final repository = FakeAppointments()..fail = true;
    await tester.pumpWidget(
      catalogApp(
        AppointmentDetail(
          id: 'missing',
          repository: repository,
          catalog: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rendez-vous introuvable.'), findsOneWidget);
    expect(find.text('Cliente de démonstration'), findsNothing);
    expect(find.text('Archiver'), findsNothing);
  });
  testWidgets('USER detail hides archive and premature attendance actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        AppointmentDetail(
          id: 'appointment',
          repository: FakeAppointments(),
          catalog: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Archiver'), findsNothing);
    expect(find.text('Démarrer la séance'), findsNothing);
    expect(find.byTooltip('Modifier'), findsOneWidget);
  });
  testWidgets(
    'failed confirmation keeps draft and reuses idempotency key on retry',
    (tester) async {
      final repository = FakeAppointments()..failCreate = true;
      String? result;
      await tester.pumpWidget(
        catalogApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingWizard(
                      repository: repository,
                      catalog: FakeCatalog(),
                    ),
                  ),
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.text('Soin de démonstration'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Choisir une date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir une heure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer le rendez-vous'));
      await tester.pumpAndSettle();
      expect(find.text('Connexion interrompue. Réessayez.'), findsOneWidget);
      expect(result, isNull);
      repository.failCreate = false;
      await tester.tap(find.text('Confirmer le rendez-vous'));
      await tester.pumpAndSettle();
      expect(result, 'appointment');
      expect(repository.keys.length, 2);
      expect(repository.keys.first, repository.keys.last);
    },
  );
}
