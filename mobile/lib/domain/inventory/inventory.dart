import 'dart:typed_data';

class StockProduct {
  const StockProduct(
    this.id,
    this.sku,
    this.name,
    this.unit,
    this.cost,
    this.threshold,
    this.quantity,
    this.active,
    this.version,
  );
  final String id, sku, name, unit, threshold, quantity;
  final int cost, version;
  final bool active;
}

class InventoryPage {
  const InventoryPage(this.items, this.total, this.hasMore);
  final List<StockProduct> items;
  final int total;
  final bool hasMore;
}

class ProductDraft {
  const ProductDraft(
    this.sku,
    this.name,
    this.unit,
    this.cost,
    this.threshold,
    this.active, {
    this.initialQuantity = '0',
  });
  final String sku, name, unit, threshold;
  final int cost;
  final bool active;
  final String initialQuantity;
}

abstract interface class InventoryRepository {
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType);
  Future<InventoryPage> list({int page = 1});
  Future<String> save(ProductDraft draft, {StockProduct? product});
  Future<void> adjust(
    StockProduct product,
    String quantity,
    String reason,
    String requestId,
  );
}

int? quantityMilli(String input) {
  if (!RegExp(r'^-?\d{1,9}(?:\.\d{1,3})?$').hasMatch(input)) return null;
  final negative = input.startsWith('-');
  final parts = (negative ? input.substring(1) : input).split('.');
  return (int.parse(parts[0]) * 1000 +
          int.parse(parts.length == 2 ? parts[1].padRight(3, '0') : '0')) *
      (negative ? -1 : 1);
}
