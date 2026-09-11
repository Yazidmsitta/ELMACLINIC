import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/notifications/notifications.dart';
import '../api/api_client.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this.api);
  final ApiClient api;
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AppFailure(apiErrorMessage(e));
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  @override
  Future<NotificationPage> list({int page = 1}) => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'notifications',
      queryParameters: {'page': page},
    )).data!;
    return NotificationPage(
      (body['data'] as List).map((dynamic raw) {
        final row = raw as Map<String, dynamic>;
        return ClinicNotification(
          row['id'] as String,
          row['type'] as String,
          DateTime.parse(row['created_at'] as String),
          row['read_at'] == null
              ? null
              : DateTime.parse(row['read_at'] as String),
        );
      }).toList(),
      body['has_more'] as bool,
    );
  });
  @override
  Future<void> markRead(String id) => _request(() async {
    await api.dio.post<dynamic>('notifications/$id/read');
  });
}
