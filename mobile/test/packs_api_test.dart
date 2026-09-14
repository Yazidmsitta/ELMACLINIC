import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/packs/api_packs_repository.dart';
import 'package:elmaclinic/domain/packs/packs.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  test('pack sends independent price, sessions, and edit version', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((r) {
      final d = r.data as Map;
      expect(d['price_centimes'], 70000);
      expect(d['version'], 2);
      expect(d['items'], [
        {'service_id': 'laser', 'sessions': 6},
        {'service_id': 'visage', 'sessions': 2},
      ]);
      return jsonBody({'id': 'pack'});
    });
    expect(
      await ApiPacksRepository(api).save(
        const ClinicPack(
          id: 'pack',
          name: 'Mixte',
          price: 70000,
          version: 2,
          items: {'laser': 6, 'visage': 2},
        ),
      ),
      'pack',
    );
  });
  test('stale pack edit is explained without network error', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((_) => jsonBody({}, 409));
    await expectLater(
      ApiPacksRepository(
        api,
      ).save(const ClinicPack(name: 'Pack', price: 100, items: {'service': 1})),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('Actualisez'),
        ),
      ),
    );
  });
}
