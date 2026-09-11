import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/catalog/api_catalog_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/catalog/catalog.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  test('catalog mapper uses persisted fields, count and pagination', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((request) {
      expect(request.queryParameters['search'], 'Soin');
      expect(request.queryParameters['page'], 2);
      return jsonBody({
        'data': [
          {
            'id': 'service',
            'name': 'Soin',
            'duration_minutes': 45,
            'price_centimes': 12345,
            'active': false,
            'image_url': 'https://example.test/signed',
          },
        ],
        'total': 51,
        'has_more': false,
      });
    });
    final page = await ApiCatalogRepository(
      api,
    ).list(CatalogKind.services, page: 2, search: 'Soin');
    expect(page.total, 51);
    expect(page.entries.single.priceCentimes, 12345);
    expect(page.entries.single.active, false);
    expect(page.entries.single.imageUrl, 'https://example.test/signed');
  });
  test('service save sends integer centimes and all editable fields', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((request) {
      expect(request.method, 'PATCH');
      expect(request.path, 'services/service');
      expect(request.data, {
        'name': 'Soin',
        'description': 'Description',
        'category_id': 'category',
        'duration_minutes': 45,
        'price_centimes': 12345,
        'active': true,
      });
      return jsonBody({
        'data': {'id': 'service'},
      });
    });
    await ApiCatalogRepository(api).save(
      CatalogKind.services,
      const CatalogEntry(
        id: 'service',
        name: 'Soin',
        description: 'Description',
        categoryId: 'category',
        durationMinutes: 45,
        priceCentimes: 12345,
      ),
      creating: false,
    );
  });
  test(
    'availability saves absolute UTC instants and clinic wall-time shifts',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.data, {
          'shifts': [
            {'weekday': 1, 'starts_at': '09:00', 'ends_at': '18:00'},
          ],
          'absences': [
            {
              'starts_at': '2026-10-01T08:00:00.000Z',
              'ends_at': '2026-10-01T17:00:00.000Z',
            },
          ],
        });
        return jsonBody({'message': 'saved'});
      });
      await ApiCatalogRepository(api).saveAvailability(
        'practitioner',
        PractitionerAvailability(
          const [WeeklyShift(1, '09:00', '18:00')],
          [
            TimeOff(
              DateTime.parse('2026-10-01T09:00:00+01:00'),
              DateTime.parse('2026-10-01T18:00:00+01:00'),
            ),
          ],
        ),
      );
    },
  );
  test('403 writes are failures rather than simulated success', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter(
      (_) => jsonBody({'message': 'Action non autorisée.'}, 403),
    );
    await expectLater(
      ApiCatalogRepository(
        api,
      ).setActive(CatalogKind.services, 'service', false),
      throwsA(isA<AppFailure>()),
    );
  });
}
