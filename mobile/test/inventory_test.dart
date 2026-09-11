import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/inventory/inventory.dart';
import 'package:elmaclinic/presentation/inventory/inventory_screen.dart';
import 'catalog_test.dart' show catalogApp;

class FakeInventory implements InventoryRepository {
  static const product = StockProduct(
    'id',
    'SERUM',
    'Hyaluron Serum 50ml',
    'unité',
    18000,
    '5.000',
    '2.000',
    true,
    1,
  );
  final keys = <String>[];
  @override
  Future<InventoryPage> list({int page = 1}) async =>
      const InventoryPage([product], 1, false);
  @override
  Future<void> save(ProductDraft draft, {StockProduct? product}) async {}
  @override
  Future<void> adjust(
    StockProduct product,
    String quantity,
    String reason,
    String requestId,
  ) async {
    keys.add(requestId);
    throw const AppFailure('Connexion interrompue.');
  }
}

void main() {
  test('quantities retain exact thousandths and reject excess precision', () {
    expect(quantityMilli('-0.125'), -125);
    expect(quantityMilli('2.001'), 2001);
    for (final value in ['1e3', '0.0001', 'NaN', '1,2']) {
      expect(quantityMilli(value), isNull);
    }
  });
  testWidgets('failed adjustment retains its request key and draft', (
    tester,
  ) async {
    final repo = FakeInventory();
    await tester.pumpWidget(
      catalogApp(
        Scaffold(
          body: InventorySheet(
            repository: repo,
            product: FakeInventory.product,
            adjust: true,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), '-0.125');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Utilisation soin',
    );
    await tester.tap(find.text('Mettre à jour le stock'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion interrompue.'), findsOneWidget);
    await tester.tap(find.text('Mettre à jour le stock'));
    await tester.pumpAndSettle();
    expect(repo.keys.length, 2);
    expect(repo.keys.toSet().length, 1);
    expect(find.text('-0.125'), findsOneWidget);
  });
}
