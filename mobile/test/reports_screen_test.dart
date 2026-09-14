import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/reports/financial_report.dart';
import 'package:elmaclinic/presentation/reports/reports_screen.dart';
import 'catalog_test.dart' show catalogApp;

class PendingReports implements ReportsRepository {
  final requests = <Completer<FinancialReport>>[];
  @override
  Future<FinancialReport> financial({
    required String from,
    required String to,
  }) {
    final result = Completer<FinancialReport>();
    requests.add(result);
    return result.future;
  }
}

void main() {
  testWidgets(
    'period changes discard stale responses and failures never show zero totals',
    (tester) async {
      final repo = PendingReports();
      await tester.pumpWidget(catalogApp(ReportsScreen(repository: repo)));
      await tester.tap(find.text('Semaine'));
      await tester.pump();
      repo.requests[1].completeError(const AppFailure('Accès refusé.'));
      await tester.pumpAndSettle();
      repo.requests[0].complete(
        const FinancialReport(
          from: '2026-09-01',
          to: '2026-09-13',
          received: 10000,
          expenses: 20000,
          cashBalance: -10000,
          receiptCount: 1,
          expenseCount: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accès refusé.'), findsOneWidget);
      expect(find.text('Solde enregistré'), findsNothing);
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      repo.requests[2].complete(
        const FinancialReport(
          from: '2026-09-07',
          to: '2026-09-13',
          received: 10000,
          expenses: 20000,
          cashBalance: -10000,
          receiptCount: 1,
          expenseCount: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Solde enregistré'), findsOneWidget);
      expect(find.textContaining('-100,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
