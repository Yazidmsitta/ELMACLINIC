@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/presentation/inventory/inventory_screen.dart';
import 'inventory_test.dart' show FakeInventory;
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

  testWidgets('Inventory cards follow Figma reference', (tester) async {
    viewport(tester);
    await tester.pumpWidget(
      catalogApp(Scaffold(body: InventoryScreen(repository: FakeInventory()))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/inventory.png'),
    );
  });
}
