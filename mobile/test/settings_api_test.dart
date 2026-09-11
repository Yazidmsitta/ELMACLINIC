import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/settings/api_clinic_settings_repository.dart';
import 'package:elmaclinic/domain/settings/clinic_settings.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  test('settings send reviewed version and retain returned version', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((request) {
      expect(request.data, {
        'name': 'Clinic',
        'phone': '',
        'address': '',
        'version': 2,
      });
      return jsonBody({'saved': true, 'version': 3});
    });
    expect(
      await ApiClinicSettingsRepository(
        api,
      ).save(const ClinicSettings('Clinic', '', '', 2)),
      3,
    );
  });
  test(
    'missing settings start at version zero; conflicts and malformed responses fail',
    () async {
      final api = ApiClient(MemoryTokens());
      final repo = ApiClinicSettingsRepository(api);
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'data': null, 'version': 0}),
      );
      expect((await repo.load()).version, 0);
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'data': null, 'version': 2}),
      );
      await expectLater(repo.load(), throwsA(isA<AppFailure>()));
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'message': 'Actualisez.'}, 409),
      );
      await expectLater(
        repo.save(const ClinicSettings('Clinic', '', '', 2)),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
