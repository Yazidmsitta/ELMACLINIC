@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/presentation/appointments/appointments_screen.dart';
import 'package:elmaclinic/presentation/appointments/appointment_detail.dart';
import 'package:elmaclinic/presentation/appointments/booking_wizard.dart';
import 'appointments_test.dart' show FakeAppointments;
import 'catalog_test.dart' show FakeCatalog, catalogApp;
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

  testWidgets('Appointment day and filters match reference composition', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(
        AppointmentsScreen(
          repository: FakeAppointments(),
          catalog: FakeCatalog(),
          isAdmin: false,
          initialDay: DateTime(2030, 1, 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appointments_day.png'),
    );
    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appointments_filters.png'),
    );
  });
  testWidgets('Appointment detail renders persisted source and services', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(
        AppointmentDetail(
          id: 'appointment',
          repository: FakeAppointments(),
          catalog: FakeCatalog(),
          isAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/appointment_detail.png'),
    );
  });
  testWidgets('Booking first step matches reference composition', (
    tester,
  ) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(
        BookingWizard(repository: FakeAppointments(), catalog: FakeCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/booking_client.png'),
    );
  });
  testWidgets('Compact booking supports large text and keyboard scrolling', (
    tester,
  ) async {
    viewport(tester, width: 320);
    await tester.pumpWidget(
      catalogApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 844),
            textScaler: TextScaler.linear(1.5),
            viewInsets: EdgeInsets.only(bottom: 260),
          ),
          child: BookingWizard(
            repository: FakeAppointments(),
            catalog: FakeCatalog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Soin de démonstration'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
