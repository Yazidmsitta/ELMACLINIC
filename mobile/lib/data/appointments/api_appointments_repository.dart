import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../api/api_client.dart';

class ApiAppointmentsRepository implements AppointmentsRepository {
  ApiAppointmentsRepository(this.api);
  final ApiClient api;
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
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

  List<BookingItem> _items(dynamic raw) => (raw as List)
      .map(
        (dynamic s) => BookingItem(
          s['service_id'] as String,
          s['name'] as String,
          s['duration_minutes'] as int,
          s['price_centimes'] as int,
          s['quantity'] as int,
        ),
      )
      .toList();
  ClinicAppointment _appointment(Map<String, dynamic> row) => ClinicAppointment(
    id: row['id'] as String,
    clientId: row['client_id'] as String,
    clientName: row['client_name'] as String,
    clientPhone: row['client_phone'] as String?,
    practitionerId: row['practitioner_id'] as String?,
    practitionerName: row['practitioner_name'] as String?,
    start: DateTime.parse(row['starts_at'] as String),
    end: DateTime.parse(row['ends_at'] as String),
    notes: row['notes'] as String?,
    status: AppointmentStatus.values.singleWhere(
      (s) => s.code == row['status'],
    ),
    source: AppointmentSource.values.singleWhere(
      (s) => s.code == row['source'],
    ),
    version: row['version'] as int,
    services: _items(row['services']),
    totalCentimes: row['total_centimes'] as int,
  );
  Map<String, dynamic> _selection(BookingSelection s) => {
    'client_id': s.clientId,
    'practitioner_id': s.practitionerId,
    'service_ids': s.serviceIds,
    'starts_at': s.start.toUtc().toIso8601String(),
  };
  @override
  Future<AppointmentPage> list(
    DateTime day, {
    int page = 1,
    AppointmentStatus? status,
    AppointmentSource? source,
    String? practitionerId,
  }) => _request(() async {
    final response = await api.dio.get<Map<String, dynamic>>(
      'appointments',
      queryParameters: {
        'date': DateFormat('yyyy-MM-dd').format(day),
        'page': page,
        'status': ?status?.code,
        'source': ?source?.code,
        'practitioner_id': ?practitionerId,
      },
    );
    final data = response.data!;
    return AppointmentPage(
      (data['data'] as List)
          .map((dynamic row) => _appointment(row as Map<String, dynamic>))
          .toList(),
      data['total'] as int,
      data['has_more'] as bool,
    );
  });
  @override
  Future<ClinicAppointment> details(String id) => _request(
    () async => _appointment(
      (await api.dio.get<Map<String, dynamic>>(
            'appointments/$id',
          )).data!['data']
          as Map<String, dynamic>,
    ),
  );
  @override
  Future<BookingQuote> quote(BookingSelection selection) => _request(() async {
    final data =
        (await api.dio.post<Map<String, dynamic>>(
              'appointments/quote',
              data: _selection(selection),
            )).data!['data']
            as Map<String, dynamic>;
    return BookingQuote(
      DateTime.parse(data['starts_at'] as String),
      DateTime.parse(data['ends_at'] as String),
      data['duration_minutes'] as int,
      data['total_centimes'] as int,
      _items(data['services']),
    );
  });
  @override
  Future<String> create(
    BookingSelection selection,
    BookingQuote quote,
    String? notes,
    String requestId,
  ) => _request(() async {
    final data = (await api.dio.post<Map<String, dynamic>>(
      'appointments',
      data: {
        ..._selection(selection),
        'notes': notes,
        'request_id': requestId,
        'expected_total_centimes': quote.totalCentimes,
        'expected_duration_minutes': quote.duration,
      },
    )).data!;
    return data['id'] as String;
  });
  @override
  Future<void> reschedule(
    ClinicAppointment appointment,
    String practitionerId,
    DateTime start,
    String? notes,
  ) => _request(() async {
    await api.dio.patch<dynamic>(
      'appointments/${appointment.id}',
      data: {
        'action': 'RESCHEDULE',
        'version': appointment.version,
        'practitioner_id': practitionerId,
        'starts_at': start.toUtc().toIso8601String(),
        'notes': notes,
      },
    );
  });
  @override
  Future<void> changeStatus(
    ClinicAppointment appointment,
    AppointmentStatus status,
  ) => _request(() async {
    await api.dio.patch<dynamic>(
      'appointments/${appointment.id}',
      data: {
        'action': 'STATUS',
        'version': appointment.version,
        'status': status.code,
      },
    );
  });
  @override
  Future<void> archive(ClinicAppointment appointment) => _request(() async {
    await api.dio.delete<dynamic>(
      'appointments/${appointment.id}',
      data: {'version': appointment.version},
    );
  });
}
