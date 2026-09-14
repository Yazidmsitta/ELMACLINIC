@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/presentation/reports/reports_screen.dart';
import 'package:elmaclinic/domain/reports/financial_report.dart';

import 'catalog_test.dart' show catalogApp;
import 'visual_shell_test.dart' show ElmaVisualBinding;

class DemoReport implements ReportsRepository {
  @override
  Future<FinancialReport> financial({
    required String from,
    required String to,
  }) async => const FinancialReport(
    from: '2026-09-01',
    to: '2026-09-13',
    received: 3210000,
    expenses: 800000,
    cashBalance: 2410000,
    receiptCount: 47,
    expenseCount: 12,
  );
}

void main() {
  ElmaVisualBinding();
  setUpAll(() async {
    await initializeDateFormatting('fr');
    for (final font in [
      ('Plus Jakarta Sans', 'PlusJakartaSans.ttf'),
      ('DM Serif Display', 'DMSerifDisplay-Regular.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });
  void viewport(WidgetTester tester, {double width = 390}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Reports layout follows inspected Figma cards', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(Scaffold(body: ReportsScreen(repository: DemoReport()))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/reports.png'),
    );
  });
}
