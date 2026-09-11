import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/settings/clinic_settings.dart';
import '../api/api_client.dart';

class ApiClinicSettingsRepository implements ClinicSettingsRepository {
  ApiClinicSettingsRepository(this.api);
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
  Future<ClinicSettings> load() => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'clinic-settings',
    )).data!;
    final version = body['version'] as int;
    final data = body['data'] as Map<String, dynamic>?;
    if (version < 0 || (data == null) != (version == 0)) {
      throw const FormatException();
    }
    return data == null
        ? const ClinicSettings('', '', '', 0)
        : ClinicSettings(
            data['name'] as String,
            data['phone'] as String,
            data['address'] as String,
            version,
          );
  });
  @override
  Future<int> save(ClinicSettings draft) => _request(() async {
    final body = (await api.dio.put<Map<String, dynamic>>(
      'clinic-settings',
      data: {
        'name': draft.name,
        'phone': draft.phone,
        'address': draft.address,
        'version': draft.version,
      },
    )).data!;
    final version = body['version'] as int;
    if (body['saved'] != true || version != draft.version + 1) {
      throw const FormatException();
    }
    return version;
  });
}
