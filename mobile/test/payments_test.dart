import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/payments/payments.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/presentation/payments/payment_sheet.dart';
import 'appointments_test.dart' show FakeAppointments;
import 'catalog_test.dart' show catalogApp;

class FakePayments implements PaymentsRepository {
  @override
  Future<PaymentLedger> ledger({int page = 1}) async => PaymentLedger(
    [
      PaymentEntry(
        'payment',
        'Cliente de démonstration',
        'Soin du visage',
        15000,
        PaymentMethod.card,
        DateTime.utc(2030, 1, 7, 10),
      ),
    ],
    1,
    false,
    15000,
    45000,
    '2030-01-07',
  );
  bool fail = true;
  final keys = <String>[];
  final amounts = <int>[];
  @override
  Future<PaymentBalance> balance(String id) async =>
      const PaymentBalance(20000, 5000, 15000);
  @override
  Future<String> record(
    String id,
    int amount,
    PaymentMethod method,
    String key,
  ) async {
    keys.add(key);
    amounts.add(amount);
    if (fail) throw const AppFailure('Connexion interrompue.');
    return 'payment';
  }
}

void main() {
  test('MAD parsing preserves centimes and rejects invalid precision', () {
    expect(parseMadCentimes('12,34'), 1234);
    expect(parseMadCentimes('12.3'), 1230);
    for (final value in [
      '0',
      '-1',
      '1.234',
      '1e2',
      'NaN',
      '1 000',
      '21474836.48',
    ]) {
      expect(parseMadCentimes(value), isNull);
    }
  });
  testWidgets(
    'payment retry preserves key and amount after uncertain failure',
    (tester) async {
      final repo = FakePayments();
      await tester.pumpWidget(
        catalogApp(
          Scaffold(
            body: PaymentSheet(
              appointment: FakeAppointments().appointment,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '151');
      await tester.tap(find.text('Confirmer le paiement'));
      await tester.pumpAndSettle();
      expect(repo.keys, isEmpty);
      await tester.enterText(find.byType(TextField), '12,34');
      await tester.tap(find.text('Confirmer le paiement'));
      await tester.pumpAndSettle();
      expect(find.text('Connexion interrompue.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      await tester.tap(find.text('Réessayer le paiement'));
      await tester.pumpAndSettle();
      expect(repo.keys.length, 2);
      expect(repo.keys.first, repo.keys.last);
      expect(repo.amounts, [1234, 1234]);
      expect(tester.takeException(), isNull);
    },
  );
}
