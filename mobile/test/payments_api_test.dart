import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/payments/api_payments_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/payments/payments.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  final row = <String, dynamic>{
    'id': 'receipt',
    'client_name': 'Cliente',
    'service_names': 'Soin',
    'amount_centimes': 12345,
    'currency': 'MAD',
    'method': 'CARD',
    'paid_at': '2030-01-01T09:00:00Z',
  };
  Map<String, dynamic> response(Map<String, dynamic> item) => {
    'data': [item],
    'total': 51,
    'has_more': true,
    'currency': 'MAD',
    'today_centimes': 50000,
    'month_centimes': 100000,
    'clinic_date': '2030-01-01',
  };
  test(
    'ledger preserves server totals and centimes rather than summing one page',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.queryParameters['page'], 2);
        return jsonBody(response(row));
      });
      final ledger = await ApiPaymentsRepository(api).ledger(page: 2);
      expect(ledger.items.single.amount, 12345);
      expect(ledger.items.single.method, PaymentMethod.card);
      expect(ledger.today, 50000);
      expect(ledger.month, 100000);
      expect(ledger.hasMore, true);
      expect(ledger.total, 51);
    },
  );
  test(
    'unsupported currency, method and malformed values fail closed',
    () async {
      final api = ApiClient(MemoryTokens());
      for (final extra in [
        {'currency': 'EUR'},
        {'method': 'OTHER'},
        {'amount_centimes': 1.5},
        {'paid_at': 'invalid'},
      ]) {
        api.dio.httpClientAdapter = StubAdapter(
          (_) => jsonBody(response({...row, ...extra})),
        );
        await expectLater(
          ApiPaymentsRepository(api).ledger(),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'ledger authorization failure surfaces instead of showing an empty ledger',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter(
        (_) => jsonBody({'message': 'Accès administrateur requis.'}, 403),
      );
      await expectLater(
        ApiPaymentsRepository(api).ledger(),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'record sends only exact amount, method, appointment and stable request key',
    () async {
      final api = ApiClient(MemoryTokens());
      api.dio.httpClientAdapter = StubAdapter((request) {
        expect(request.data, {
          'appointment_id': 'appointment',
          'amount_centimes': 12345,
          'method': 'TRANSFER',
          'request_id': 'stable-key',
        });
        return jsonBody({'id': 'receipt'}, 201);
      });
      expect(
        await ApiPaymentsRepository(
          api,
        ).record('appointment', 12345, PaymentMethod.transfer, 'stable-key'),
        'receipt',
      );
    },
  );
}
