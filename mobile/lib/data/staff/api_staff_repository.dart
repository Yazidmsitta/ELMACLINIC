import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/staff/staff.dart';
import '../api/api_client.dart';

class ApiStaffRepository implements StaffRepository {
  ApiStaffRepository(this.api);
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
  Future<StaffPage> list({int page = 1}) => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'staff',
      queryParameters: {'page': page},
    )).data!;
    return StaffPage(
      (body['data'] as List).map((dynamic raw) {
        final row = raw as Map<String, dynamic>;
        if (!['ADMIN', 'USER'].contains(row['role'])) {
          throw const FormatException();
        }
        return StaffMember(
          row['id'] as String,
          row['full_name'] as String,
          row['role'] as String,
          row['active'] as bool,
          row['version'] as int,
        );
      }).toList(),
      body['has_more'] as bool,
    );
  });
  @override
  Future<void> update(
    StaffMember original,
    String name,
    String role,
    bool active,
  ) => _request(() async {
    await api.dio.patch<dynamic>(
      'staff/${original.id}',
      data: {
        'full_name': name,
        'role': role,
        'active': active,
        'version': original.version,
      },
    );
  });
}
