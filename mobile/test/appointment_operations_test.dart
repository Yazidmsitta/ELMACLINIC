import 'package:elmaclinic/domain/appointments/appointments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/presentation/appointments/appointment_detail.dart';
import 'package:elmaclinic/presentation/payments/payment_sheet.dart';
import 'appointments_test.dart' show FakeAppointments;
import 'payments_test.dart' show FakePayments;
import 'catalog_test.dart' show FakeCatalog, catalogApp;

class StatusAppointments extends FakeAppointments {
  final changed = <AppointmentStatus>[];
  @override
  Future<void> changeStatus(
    ClinicAppointment appointment,
    AppointmentStatus status,
  ) async {
    changed.add(status);
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  for (final admin in [false, true]) {
    testWidgets(
      'Payment confirmation and status controls available for admin=$admin',
      (tester) async {
        final payments = FakePayments()..fail = false;
        final appointments = StatusAppointments();
        await tester.pumpWidget(
          catalogApp(
            PaymentScope(
              repository: payments,
              child: AppointmentDetail(
                id: 'appointment',
                repository: appointments,
                catalog: FakeCatalog(),
                isAdmin: admin,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Modifier le statut'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Modifier le statut'), findsOneWidget);
        await tester.ensureVisible(find.text('Encaisser un paiement'));
        await tester.tap(find.text('Encaisser un paiement'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Payer la totalité'));
        await tester.tap(find.text('Payer la totalité'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Confirmer le paiement'));
        await tester.tap(find.text('Confirmer le paiement'));
        await tester.pumpAndSettle();
        expect(payments.amounts, [15000]);
        await tester.scrollUntilVisible(
          find.text('Annuler le rendez-vous'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Annuler le rendez-vous'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmer'));
        await tester.pumpAndSettle();
        expect(appointments.changed, [AppointmentStatus.cancelled]);
        expect(find.text('Paiement enregistré.'), findsOneWidget);
      },
    );
  }
}
