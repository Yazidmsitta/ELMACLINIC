import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/catalog/catalog.dart';
import '../api/api_client.dart';

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this.api);
  final ApiClient api;
  @override
  Future<PractitionerAvailability> availability(String id) =>
      _request(() async {
        final response = await api.dio.get<Map<String, dynamic>>(
          'practitioners/$id/availability',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return PractitionerAvailability(
          (data['shifts'] as List)
              .map(
                (dynamic s) => WeeklyShift(
                  s['weekday'] as int,
                  (s['starts_at'] as String).substring(0, 5),
                  (s['ends_at'] as String).substring(0, 5),
                ),
              )
              .toList(),
          (data['absences'] as List)
              .map(
                (dynamic s) => TimeOff(
                  DateTime.parse(s['starts_at'] as String),
                  DateTime.parse(s['ends_at'] as String),
                ),
              )
              .toList(),
        );
      });
  @override
  Future<void> saveAvailability(
    String id,
    PractitionerAvailability availability,
  ) => _request(() async {
    await api.dio.put<dynamic>(
      'practitioners/$id/availability',
      data: {
        'shifts': availability.shifts
            .map(
              (s) => {
                'weekday': s.weekday,
                'starts_at': s.start,
                'ends_at': s.end,
              },
            )
            .toList(),
        'absences': availability.absences
            .map(
              (s) => {
                'starts_at': s.start.toUtc().toIso8601String(),
                'ends_at': s.end.toUtc().toIso8601String(),
              },
            )
            .toList(),
      },
    );
  });
  @override
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType) =>
      _request(() async {
        await api.dio.put<dynamic>(
          'services/$id/image',
          data: bytes,
          options: Options(contentType: mimeType),
        );
      });
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw AppFailure(apiErrorMessage(error));
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  @override
  Future<CatalogPage> list(
    CatalogKind kind, {
    int page = 1,
    String search = '',
    String? categoryId,
  }) => _request(() async {
    final response = await api.dio.get<Map<String, dynamic>>(
      kind.path,
      queryParameters: {
        'page': page,
        'search': search,
        'category_id': ?categoryId,
      },
    );
    final data = response.data!;
    return CatalogPage(
      (data['data'] as List)
          .map((raw) {
            final row = raw as Map<String, dynamic>;
            return CatalogEntry(
              id: row['id'] as String,
              name: (row['full_name'] ?? row['name']) as String,
              phone: row['phone'] as String?,
              email: row['email'] as String?,
              birthDate: row['birth_date'] as String?,
              specialty: row['specialty'] as String?,
              jobTitle: row['job_title'] as String?,
              description: row['description'] as String?,
              categoryId: row['category_id'] as String?,
              durationMinutes: row['duration_minutes'] as int?,
              priceCentimes: row['price_centimes'] as int?,
              active: row['active'] as bool? ?? true,
              imageUrl: row['image_url'] as String?,
              parentId: row['parent_id'] as String?,
              sortOrder: row['sort_order'] as int? ?? 0,
            );
          })
          .toList(growable: false),
      data['total'] as int,
      data['has_more'] as bool,
    );
  });
  @override
  Future<String> save(
    CatalogKind kind,
    CatalogEntry entry, {
    required bool creating,
  }) => _request(() async {
    final body = <String, dynamic>{
      if (kind == CatalogKind.clients || kind == CatalogKind.practitioners) ...{
        'full_name': entry.name,
        'phone': entry.phone,
        'email': entry.email,
      } else
        'name': entry.name,
      if (kind == CatalogKind.clients) 'birth_date': entry.birthDate,
      if (kind == CatalogKind.practitioners) ...{
        'specialty': entry.specialty,
        'job_title': entry.jobTitle,
      },
      if (kind == CatalogKind.services) ...{
        'category_id': entry.categoryId,
        'description': entry.description,
        'duration_minutes': entry.durationMinutes,
        'price_centimes': entry.priceCentimes,
      },
      if (kind == CatalogKind.categories) ...{
        'parent_id': entry.parentId,
        'sort_order': entry.sortOrder,
      },
      if (kind != CatalogKind.clients) 'active': entry.active,
    };
    if (creating) {
      final response=await api.dio.post<Map<String,dynamic>>(kind.path,data:body); return (response.data!['data'] as Map<String,dynamic>)['id'] as String;
    } else {
      await api.dio.patch<dynamic>('${kind.path}/${entry.id}', data: body); return entry.id;
    }
  });
  @override
  Future<void> setActive(CatalogKind kind, String id, bool active) =>
      _request(() async {
        await api.dio.patch<dynamic>(
          '${kind.path}/$id',
          data: {'active': active},
        );
      });
  @override
  Future<void> archive(CatalogKind kind, String id) => _request(() async {
    await api.dio.delete<dynamic>('${kind.path}/$id');
  });
}
