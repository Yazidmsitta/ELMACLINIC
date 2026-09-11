@Tags(['visual'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/catalog/catalog.dart';
import 'package:elmaclinic/presentation/catalog/catalog_screen.dart';
import 'package:elmaclinic/presentation/catalog/entry_sheet.dart';
import 'catalog_test.dart' show FakeCatalog, catalogApp;
import 'visual_shell_test.dart' show ElmaVisualBinding;

void main() {
  ElmaVisualBinding();
  setUpAll(() async {
    for (final font in [
      ('Plus Jakarta Sans', 'PlusJakartaSans.ttf'),
      ('DM Serif Display', 'DMSerifDisplay-Regular.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });
  for (final fixture in [
    (CatalogKind.services, true),
    (CatalogKind.services, false),
    (CatalogKind.practitioners, true),
    (CatalogKind.clients, false),
  ]) {
    testWidgets('Catalog ${fixture.$1.name} ${fixture.$2}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        catalogApp(
          CatalogScreen(
            kind: fixture.$1,
            repository: FakeCatalog(),
            isAdmin: fixture.$2,
            standalone: fixture.$1 != CatalogKind.clients,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/catalog_${fixture.$1.name}_${fixture.$2 ? 'admin' : 'user'}.png',
        ),
      );
    });
  }
  testWidgets('Client form fits compact large-text keyboard viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      catalogApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 720),
            textScaler: TextScaler.linear(1.5),
            viewInsets: EdgeInsets.only(bottom: 240),
          ),
          child: EntrySheet(
            kind: CatalogKind.clients,
            repository: FakeCatalog(),
            categories: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
