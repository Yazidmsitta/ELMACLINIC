import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../domain/packs/packs.dart';
import '../../domain/app_failure.dart';
import '../api/api_client.dart';

class ApiPacksRepository implements PacksRepository {
  ApiPacksRepository(this.api);
  final ApiClient api;
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AppFailure(
          'Pack modifié. Actualisez la fiche avant de réessayer.',
        );
      }
      throw AppFailure(apiErrorMessage(e));
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  @override
  Future<PackPage> list({int page = 1}) => _guard(() async {
    final b = (await api.dio.get<Map<String, dynamic>>(
      'packs',
      queryParameters: {'page': page},
    )).data!;
    return PackPage(
      (b['data'] as List)
          .map(
            (dynamic p) => ClinicPack(
              id: p['id'] as String,
              name: p['name'] as String,
              description: p['description'] as String? ?? '',
              price: p['price_centimes'] as int,
              active: p['active'] as bool,
              version: p['version'] as int,
              imageUrl: p['image_url'] as String?,
              items: {
                for (final dynamic i in p['items'] as List)
                  i['service_id'] as String: i['sessions'] as int,
              },
            ),
          )
          .toList(),
      b['has_more'] as bool,
    );
  });
  @override
  Future<String> save(ClinicPack p) => _guard(() async {
    final b = (await api.dio.post<Map<String, dynamic>>(
      'packs',
      data: {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'price_centimes': p.price,
        'active': p.active,
        'version': p.version,
        'items': [
          for (final i in p.items.entries)
            {'service_id': i.key, 'sessions': i.value},
        ],
      },
    )).data!;
    return b['id'] as String;
  });
  @override
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType) =>
      _guard(() async {
        await api.dio.put<void>(
          'packs/$id/image',
          data: bytes,
          options: Options(contentType: mimeType),
        );
      });
}
