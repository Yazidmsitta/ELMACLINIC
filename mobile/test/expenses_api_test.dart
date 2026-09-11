import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/expenses/api_expenses_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/expenses/expenses.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  const summary = {
    'currency': 'MAD',
    'clinic_date': '2026-09-11',
    'month_centimes': 6273,
    'month_transactions': 51,
  };
  const row = {
    'id': 'expense',
    'description': 'Produits',
    'category': 'Soins',
    'amount_centimes': 1234,
    'spent_on': '2026-09-11',
    'version': 3,
    'voided_at': null,
    'void_reason': null,
  };
  test(
    'summary retains complete server totals and rejects invalid financial data',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.path, 'expenses/summary');
        return jsonBody(summary);
      });
      final result = await ApiExpensesRepository(api).summary();
      expect(result.monthCentimes, 6273);
      expect(result.monthTransactions, 51);
      for (final invalid in [
        {'currency': 'EUR'},
        {'month_centimes': -1},
        {'month_transactions': 1.5},
        {'clinic_date': '2026-02-30'},
      ]) {
        api.dio.httpClientAdapter = StubAdapter(
          (_) => jsonBody({...summary, ...invalid}),
        );
        await expectLater(
          ApiExpensesRepository(api).summary(),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'malformed dates and invalid amounts fail before reaching presentation',
    () async {
      final api = ApiClient(MemoryTokens());
      for (final invalid in [
        {'spent_on': 'not-a-date'},
        {'spent_on': '2026-02-30'},
        {'amount_centimes': 0},
        {'version': 0},
      ]) {
        api.dio.httpClientAdapter = StubAdapter(
          (_) => jsonBody({
            'data': [
              {...row, ...invalid},
            ],
            'total': 1,
            'has_more': false,
          }),
        );
        await expectLater(
          ApiExpensesRepository(api).list(),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'history pagination preserves cancellation reason and reviewed version',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.queryParameters, {'state': 'voided', 'page': 2});
        return jsonBody({
          'data': [
            {
              ...row,
              'voided_at': '2026-09-11T10:00:00Z',
              'void_reason': 'Doublon',
            },
          ],
          'total': 51,
          'has_more': false,
        });
      });
      final result = await ApiExpensesRepository(
        api,
      ).list(voided: true, page: 2);
      expect(result.items.single.voidReason, 'Doublon');
      expect(result.items.single.version, 3);
    },
  );
  test(
    'mutations send exact centimes, stable create key and reviewed version',
    () async {
      final api = ApiClient(MemoryTokens());
      const draft = ExpenseDraft('Produits', 'Soins', 1234, '2026-09-11');
      const expense = Expense(
        id: 'expense',
        description: 'Produits',
        category: 'Soins',
        amount: 1234,
        spentOn: '2026-09-11',
        version: 3,
      );
      final bodies = <Object?>[];
      api.dio.httpClientAdapter = StubAdapter((request) {
        bodies.add(request.data);
        return jsonBody({'id': 'expense'});
      });
      final repo = ApiExpensesRepository(api);
      await repo.create(draft, 'stable-key');
      await repo.update(expense, draft);
      await repo.voidExpense(expense, 'Doublon');
      expect(bodies, [
        {
          'description': 'Produits',
          'category': 'Soins',
          'amount_centimes': 1234,
          'spent_on': '2026-09-11',
          'request_id': 'stable-key',
        },
        {
          'description': 'Produits',
          'category': 'Soins',
          'amount_centimes': 1234,
          'spent_on': '2026-09-11',
          'version': 3,
        },
        {'version': 3, 'reason': 'Doublon'},
      ]);
    },
  );
  test('permission denial and stale version remain failures', () async {
    final api = ApiClient(MemoryTokens());
    for (final status in [403, 409]) {
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'message': 'Action refusée.'}, status),
      );
      final repo = ApiExpensesRepository(api);
      await expectLater(repo.summary(), throwsA(isA<AppFailure>()));
      await expectLater(
        repo.create(
          const ExpenseDraft('Produits', 'Soins', 1234, '2026-09-11'),
          'key',
        ),
        throwsA(isA<AppFailure>()),
      );
    }
  });
}
