import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/data/api/api_client.dart';
import 'package:elmaclinic/data/appointments/api_appointments_repository.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/appointments/appointments.dart';
import 'api_auth_test.dart' show MemoryTokens, StubAdapter, jsonBody;

void main() {
  test(
    'booking API sends reviewed totals and stable request ID, never a source',
    () async {
      final api = ApiClient(MemoryTokens());
      final key = bookingRequestId();
      api.dio.httpClientAdapter = StubAdapter((request) {
        final data = request.data as Map<String, dynamic>;
        expect(data['request_id'], key);
        expect(data['expected_total_centimes'], 12345);
        expect(data.containsKey('source'), false);
        return jsonBody({'id': 'saved'}, 201);
      });
      final selection = BookingSelection('client', 'practitioner', [
        'service',
      ], DateTime.utc(2030, 1, 7, 9));
      expect(
        await ApiAppointmentsRepository(api).create(
          selection,
          BookingQuote(
            selection.start,
            selection.start.add(const Duration(minutes: 30)),
            30,
            12345,
            const [],
          ),
          null,
          key,
        ),
        'saved',
      );
      expect(
        key,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );
  test('conflicts are surfaced as failures', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter(
      (_) => jsonBody({'message': 'Ce créneau est déjà réservé.'}, 409),
    );
    await expectLater(
      ApiAppointmentsRepository(api).quote(
        BookingSelection('client', 'practitioner', [
          'service',
        ], DateTime.utc(2030)),
      ),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.message,
          'message',
          'Ce créneau est déjà réservé.',
        ),
      ),
    );
  });
  test('unknown appointment source fails closed', () async {
    final api = ApiClient(MemoryTokens());
    api.dio.httpClientAdapter = StubAdapter(
      (_) => jsonBody({
        'data': {
          'id': 'id',
          'client_id': 'client',
          'client_name': 'Client',
          'starts_at': '2030-01-01T09:00:00Z',
          'ends_at': '2030-01-01T09:30:00Z',
          'status': 'CONFIRMED',
          'source': 'APPLICATION',
          'version': 1,
          'services': <Object>[],
          'total_centimes': 0,
        },
      }),
    );
    await expectLater(
      ApiAppointmentsRepository(api).details('id'),
      throwsA(isA<AppFailure>()),
    );
  });
}
