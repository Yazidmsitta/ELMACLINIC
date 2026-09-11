@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/presentation/payments/payment_sheet.dart';
import 'payments_test.dart' show FakePayments;
import 'appointments_test.dart' show FakeAppointments;
import 'catalog_test.dart' show catalogApp;
import 'visual_shell_test.dart' show ElmaVisualBinding;

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

  testWidgets('Payment form follows the reference sheet', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PaymentSheet(
              appointment: FakeAppointments().appointment,
              repository: FakePayments(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/payment_sheet.png'),
    );
  });
}
