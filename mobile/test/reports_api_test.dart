import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/reports/api_reports_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  const body = {
    'currency': 'MAD',
    'from': '2026-09-01',
    'to': '2026-09-30',
    'received_centimes': 12345,
    'expense_centimes': 15000,
    'cash_balance_centimes': -2655,
    'receipt_count': 2,
    'expense_count': 1,
  };
  test(
    'report retains exact negative cash balance and selected dates',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.queryParameters, {
          'from': '2026-09-01',
          'to': '2026-09-30',
        });
        return jsonBody(body);
      });
      final result = await ApiReportsRepository(
        api,
      ).financial(from: '2026-09-01', to: '2026-09-30');
      expect(result.cashBalance, -2655);
      expect(result.received, 12345);
      expect(result.receiptCount, 2);
    },
  );
  test(
    'report rejects mismatched periods, currencies and inconsistent totals',
    () async {
      final api = ApiClient(MemoryTokens());
      for (final invalid in [
        {'currency': 'EUR'},
        {'to': '2026-10-01'},
        {'cash_balance_centimes': 0},
        {'receipt_count': -1},
        {'received_centimes': 1.5},
      ]) {
        api.dio.httpClientAdapter = StubAdapter(
          (_) => jsonBody({...body, ...invalid}),
        );
        await expectLater(
          ApiReportsRepository(
            api,
          ).financial(from: '2026-09-01', to: '2026-09-30'),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'invalid ranges never reach API and denied access does not become zeros',
    () async {
      final api = ApiClient(MemoryTokens());
      var calls = 0;
      api.dio.httpClientAdapter = StubAdapter((_) {
        calls++;
        return jsonBody({'message': 'Accès refusé.'}, 403);
      });
      final repo = ApiReportsRepository(api);
      for (final dates in [
        ('2026-02-30', '2026-03-01'),
        ('2026-09-30', '2026-09-01'),
        ('2024-01-01', '2026-01-01'),
      ]) {
        await expectLater(
          repo.financial(from: dates.$1, to: dates.$2),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(calls, 0);
      await expectLater(
        repo.financial(from: '2026-09-01', to: '2026-09-30'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}
