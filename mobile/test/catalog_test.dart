import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/catalog/catalog.dart';
import 'package:elmaclinic/presentation/catalog/catalog_screen.dart';
import 'package:elmaclinic/presentation/catalog/entry_sheet.dart';
import 'package:elmaclinic/presentation/catalog/availability_sheet.dart';
import 'package:elmaclinic/presentation/theme/app_theme.dart';

class FakeCatalog implements CatalogRepository {
  bool failSave = false, failAvailability = false;
  CatalogEntry? saved;
  int listCalls = 0, availabilitySaves = 0;
  final List<(String, bool)> toggles = [];
  @override
  Future<CatalogPage> list(
    CatalogKind kind, {
    int page = 1,
    String search = '',
    String? categoryId,
  }) async {
    listCalls++;
    if (kind == CatalogKind.categories) {
      return const CatalogPage(
        [CatalogEntry(id: 'category', name: 'Visage')],
        1,
        false,
      );
    }
    return CatalogPage(
      [
        CatalogEntry(
          id: '$page',
          name: page == 1 ? 'Soin de démonstration' : 'Deuxième fiche',
          durationMinutes: 30,
          priceCentimes: 20000,
          categoryId: 'category',
          specialty: 'Laser',
          phone: '0600000000',
        ),
      ],
      2,
      page == 1,
    );
  }

  @override
  Future<String> save(
    CatalogKind kind,
    CatalogEntry entry, {
    required bool creating,
  }) async {
    if (failSave) throw const AppFailure('Enregistrement indisponible.');
    saved = entry;
    return entry.id.isEmpty ? 'created' : entry.id;
  }

  @override
  Future<void> setActive(CatalogKind kind, String id, bool active) async {
    toggles.add((id, active));
  }

  @override
  Future<void> archive(CatalogKind kind, String id) async {}
  @override
  Future<PractitionerAvailability> availability(String id) async {
    if (failAvailability) throw const AppFailure('Planning indisponible.');
    return const PractitionerAvailability([
      WeeklyShift(1, '09:00', '18:00'),
    ], []);
  }

  @override
  Future<void> saveAvailability(
    String id,
    PractitionerAvailability availability,
  ) async {
    availabilitySaves++;
  }

  @override
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType) async {}
}

Widget catalogApp(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTokens.theme,
  home: Scaffold(body: child),
);
void main() {
  testWidgets(
    'USER catalog has no management actions and paginates real results',
    (tester) async {
      final repository = FakeCatalog();
      await tester.pumpWidget(
        catalogApp(
          CatalogScreen(
            kind: CatalogKind.services,
            repository: repository,
            isAdmin: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ajouter'), findsNothing);
      expect(find.text('Archiver'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byTooltip('Modifier Soin de démonstration'), findsNothing);
      await tester.tap(find.text('Afficher plus'));
      await tester.pumpAndSettle();
      expect(find.text('Deuxième fiche'), findsOneWidget);
      expect(find.text('Soin de démonstration'), findsOneWidget);
    },
  );
  testWidgets('USER clients can edit basic fields but cannot archive', (
    tester,
  ) async {
    await tester.pumpWidget(
      catalogApp(
        CatalogScreen(
          kind: CatalogKind.clients,
          repository: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ajouter'), findsOneWidget);
    expect(find.text('Archiver'), findsNothing);
    await tester.tap(find.byTooltip('Modifier Soin de démonstration'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Prix (MAD) *'), findsNothing);
  });
  testWidgets('failed save preserves entered fields and allows retry', (
    tester,
  ) async {
    final repository = FakeCatalog()..failSave = true;
    await tester.pumpWidget(
      catalogApp(
        EntrySheet(
          kind: CatalogKind.clients,
          repository: repository,
          categories: const [],
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom complet *'),
      'Nouvelle cliente',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Enregistrement indisponible.'), findsOneWidget);
    expect(find.text('Nouvelle cliente'), findsOneWidget);
    expect(repository.saved, isNull);
    repository.failSave = false;
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(repository.saved?.name, 'Nouvelle cliente');
  });
  testWidgets('ADMIN active toggle calls repository and refreshes', (
    tester,
  ) async {
    final repository = FakeCatalog();
    await tester.pumpWidget(
      catalogApp(
        CatalogScreen(
          kind: CatalogKind.practitioners,
          repository: repository,
          isAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repository.toggles, [('1', false)]);
    expect(repository.listCalls, 2);
  });
  testWidgets(
    'failed availability load cannot overwrite stored configuration',
    (tester) async {
      final repository = FakeCatalog()..failAvailability = true;
      await tester.pumpWidget(
        catalogApp(
          AvailabilitySheet(
            entry: const CatalogEntry(id: '1', name: 'Praticienne'),
            repository: repository,
            isAdmin: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Planning indisponible.'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
      expect(repository.availabilitySaves, 0);
    },
  );
  testWidgets('USER availability is read only', (tester) async {
    await tester.pumpWidget(
      catalogApp(
        AvailabilitySheet(
          entry: const CatalogEntry(id: '1', name: 'Praticienne'),
          repository: FakeCatalog(),
          isAdmin: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('09:00 – 18:00'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.text('Ajouter un créneau'), findsNothing);
  });
}
