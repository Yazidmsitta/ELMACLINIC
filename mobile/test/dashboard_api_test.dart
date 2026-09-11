import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/dashboard/api_dashboard_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  test(
    'Dashboard decodes operational data without requiring financial keys',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({
          'data': {
            'date': '2026-09-09',
            'appointments_today': 0,
            'clients_total': 3,
            'pending': 0,
            'website_new': 0,
            'schedule': <dynamic>[],
            'notifications': <dynamic>[],
          },
        }),
      );
      final data = await ApiDashboardRepository(api).load();
      expect(data.clients, 3);
      expect(data.revenueCentimes, isNull);
      expect(data.week, isEmpty);
    },
  );
  test('An API failure is not turned into fabricated zero metrics', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter((_) => jsonBody({}, 503));
    await expectLater(
      ApiDashboardRepository(api).load(),
      throwsA(isA<AppFailure>()),
    );
  });
}
