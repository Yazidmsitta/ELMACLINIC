import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/inventory/inventory.dart';
import '../api/api_client.dart';

class ApiInventoryRepository implements InventoryRepository {
  ApiInventoryRepository(this.api);
  final ApiClient api;
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AppFailure(apiErrorMessage(e));
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  @override
  Future<InventoryPage> list({int page = 1}) => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'inventory',
      queryParameters: {'page': page},
    )).data!;
    return InventoryPage(
      (body['data'] as List).map((dynamic raw) {
        final row = raw as Map<String, dynamic>;
        final quantity = row['quantity'] as String,
            threshold = row['reorder_level'] as String;
        if (quantityMilli(quantity) == null ||
            quantityMilli(threshold) == null) {
          throw const FormatException();
        }
        return StockProduct(
          row['id'] as String,
          row['sku'] as String,
          row['name'] as String,
          row['unit'] as String,
          row['cost_centimes'] as int,
          threshold,
          quantity,
          row['active'] as bool,
          row['version'] as int,
        );
      }).toList(),
      body['total'] as int,
      body['has_more'] as bool,
    );
  });
  @override
  Future<String> save(ProductDraft draft, {StockProduct? product}) =>
      _request(() async {
        final body = <String, dynamic>{
          'sku': draft.sku.trim(),
          'name': draft.name.trim(),
          'unit': draft.unit.trim(),
          'cost_centimes': draft.cost,
          'reorder_level': draft.threshold.trim(),
          'initial_quantity': draft.initialQuantity.trim(),
          'active': draft.active,
        };

        if (product == null) {
          final r = await api.dio.post<Map<String, dynamic>>(
            'inventory',
            data: body,
          );
          return r.data!['id'] as String;
        }

        await api.dio.patch<dynamic>(
          'inventory/${product.id}',
          data: {...body, 'version': product.version},
        );
        return product.id;
      });
  @override Future<void> uploadImage(String id, Uint8List bytes, String mimeType) => _request(()async{await api.dio.put<void>('inventory/$id/image',data:bytes,options:Options(contentType:mimeType));});
  @override
  Future<void> adjust(
    StockProduct product,
    String quantity,
    String reason,
    String requestId,
  ) => _request(() async {
    await api.dio.post<dynamic>(
      'inventory/adjustments',
      data: {
        'product_id': product.id,
        'quantity': quantity,
        'reason': reason,
        'request_id': requestId,
      },
    );
  });
}
