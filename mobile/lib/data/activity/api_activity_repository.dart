import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/activity/activity.dart';
import '../api/api_client.dart';

class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository(this.api);
  final ApiClient api;
  @override
  Future<ActivityPage> list({
    int page = 1,
    String? actorId,
    String? entityType,
  }) async {
    try {
      final body = (await api.dio.get<Map<String, dynamic>>(
        'activity-logs',
        queryParameters: {
          'page': page,
          'actor_id': ?actorId,
          'entity_type': ?entityType,
        },
      )).data!;
      return ActivityPage(
        (body['data'] as List).map((dynamic raw) {
          final row = raw as Map<String, dynamic>;
          return ActivityEntry(
            row['id'] as String,
            row['actor_id'] as String?,
            row['action'] as String,
            row['entity_type'] as String,
            row['entity_id'] as String?,
            DateTime.parse(row['created_at'] as String),
            actorName: row['actor_name'] as String?,
          );
        }).toList(),
        body['has_more'] as bool,
      );
    } on DioException catch (e) {
      throw AppFailure(apiErrorMessage(e));
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }
}
