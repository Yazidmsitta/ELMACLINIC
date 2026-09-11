import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/website/website_bookings.dart';
import '../api/api_client.dart';

class ApiWebsiteBookingsRepository implements WebsiteBookingsRepository {
  ApiWebsiteBookingsRepository(this.api);
  final ApiClient api;
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AppFailure(apiErrorMessage(e));
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    } on StateError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  @override
  Future<void> dismiss(WebsiteBooking event, String reason) =>
      _request(() async {
        await api.dio.post<dynamic>(
          'website-bookings/${event.id}/dismiss',
          data: {'version': event.version, 'reason': reason},
        );
      });
  @override
  Future<WebsitePage> list(WebsiteState state, {int page = 1}) =>
      _request(() async {
        final body = (await api.dio.get<Map<String, dynamic>>(
          'website-bookings',
          queryParameters: {'state': state.code, 'page': page},
        )).data!;
        return WebsitePage(
          (body['data'] as List).map((dynamic raw) {
            final row = raw as Map<String, dynamic>;
            final payload = row['payload'] as Map<String, dynamic>;
            if (payload['source'] != 'WEBSITE') throw const FormatException();
            final client = payload['client'] as Map<String, dynamic>;
            return WebsiteBooking(
              id: row['id'] as String,
              version: row['version'] as int,
              state: WebsiteState.values.singleWhere(
                (s) => s.code == row['state'],
              ),
              clientName: client['full_name'] as String,
              phone: client['phone'] as String?,
              start: DateTime.parse(payload['starts_at'] as String),
              notes: payload['notes'] as String?,
              serviceReferences: (payload['service_external_ids'] as List)
                  .cast<String>(),
              appointmentId: row['appointment_id'] as String?,
              dismissalReason: row['dismissal_reason'] as String?,
            );
          }).toList(),
          body['total'] as int,
          body['has_more'] as bool,
        );
      });
  @override
  Future<String> importBooking(
    WebsiteBooking event,
    BookingSelection selection,
    BookingQuote quote,
  ) => _request(() async {
    final body = (await api.dio.post<Map<String, dynamic>>(
      'website-bookings/${event.id}/import',
      data: {
        'version': event.version,
        'client_id': selection.clientId,
        'practitioner_id': selection.practitionerId,
        'service_ids': selection.serviceIds,
        'expected_total_centimes': quote.totalCentimes,
        'expected_duration_minutes': quote.duration,
      },
    )).data!;
    return body['id'] as String;
  });
}
