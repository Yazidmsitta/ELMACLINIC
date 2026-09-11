import '../../domain/dashboard/dashboard.dart';
import '../../domain/app_failure.dart';
import '../api/api_client.dart';

class ApiDashboardRepository implements DashboardRepository {
  const ApiDashboardRepository(this.api);
  final ApiClient api;
  @override
  Future<Dashboard> load() async {
    try {
      final response = await api.dio.get<Map<String, dynamic>>('dashboard');
      final data = response.data!['data'] as Map<String, dynamic>;
      return Dashboard(
        date: DateTime.parse(data['date'] as String),
        appointments: data['appointments_today'] as int,
        clients: data['clients_total'] as int,
        pending: data['pending'] as int,
        websiteNew: data['website_new'] as int,
        revenueCentimes: data['revenue_today_centimes'] as int?,
        schedule: (data['schedule'] as List<dynamic>)
            .map((dynamic value) {
              final row = value as Map<String, dynamic>;
              final source = row['source'] as String,
                  status = row['status'] as String;
              if (!['MANUAL', 'WEBSITE'].contains(source) ||
                  ![
                    'NEW',
                    'PENDING',
                    'CONFIRMED',
                    'IN_PROGRESS',
                    'COMPLETED',
                    'CANCELLED',
                    'NO_SHOW',
                  ].contains(status)) {
                throw const FormatException(
                  'Unknown appointment source or status',
                );
              }
              return ScheduleEntry(
                id: row['id'] as String,
                time: row['time'] as String,
                duration: row['duration'] as int,
                client: row['client_name'] as String,
                service: row['service_name'] as String,
                status: status,
                source: source,
              );
            })
            .toList(growable: false),
        week: ((data['week_revenue'] as List<dynamic>?) ?? [])
            .map((dynamic value) {
              final row = value as Map<String, dynamic>;
              return RevenueDay(
                DateTime.parse(row['date'] as String),
                row['amount_centimes'] as int,
              );
            })
            .toList(growable: false),
        notifications: (data['notifications'] as List<dynamic>)
            .map((dynamic value) {
              final row = value as Map<String, dynamic>;
              return ClinicNotification(
                row['id'] as String,
                row['type'] as String,
                row['read_at'] == null,
              );
            })
            .toList(growable: false),
      );
    } catch (error) {
      throw AppFailure(apiErrorMessage(error));
    }
  }
}
