import 'package:dio/dio.dart';
import '../../domain/payments/payments.dart';
import '../../domain/app_failure.dart';
import '../api/api_client.dart';

class ApiPaymentsRepository implements PaymentsRepository {
  ApiPaymentsRepository(this.api);
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
  Future<PaymentLedger> ledger({int page = 1}) => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'payments',
      queryParameters: {'page': page},
    )).data!;
    if (body['currency'] != 'MAD') throw const FormatException();
    return PaymentLedger(
      (body['data'] as List).map((dynamic item) {
        final row = item as Map<String, dynamic>;
        if (row['currency'] != 'MAD') throw const FormatException();
        final matches = PaymentMethod.values.where(
          (method) => method.code == row['method'],
        );
        if (matches.isEmpty) throw const FormatException();
        return PaymentEntry(
          row['id'] as String,
          row['client_name'] as String,
          row['service_names'] as String,
          row['amount_centimes'] as int,
          matches.first,
          DateTime.parse(row['paid_at'] as String),
        );
      }).toList(),
      body['total'] as int,
      body['has_more'] as bool,
      body['today_centimes'] as int,
      body['month_centimes'] as int,
      body['clinic_date'] as String,
    );
  });
  @override
  Future<PaymentBalance> balance(String appointmentId) => _request(() async {
    final data =
        (await api.dio.get<Map<String, dynamic>>(
              'appointments/$appointmentId/balance',
            )).data!['data']
            as Map<String, dynamic>;
    if (data['currency'] != 'MAD' || data['appointment_id'] != appointmentId) {
      throw const FormatException();
    }
    return PaymentBalance(
      data['total_centimes'] as int,
      data['paid_centimes'] as int,
      data['remaining_centimes'] as int,
    );
  });
  @override
  Future<String> record(
    String appointmentId,
    int amount,
    PaymentMethod method,
    String requestId,
  ) => _request(() async {
    return (await api.dio.post<Map<String, dynamic>>(
          'payments',
          data: {
            'appointment_id': appointmentId,
            'amount_centimes': amount,
            'method': method.code,
            'request_id': requestId,
          },
        )).data!['id']
        as String;
  });
}
