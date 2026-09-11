import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/reports/financial_report.dart';
import '../api/api_client.dart';

class ApiReportsRepository implements ReportsRepository {
  ApiReportsRepository(this.api);
  final ApiClient api;
  DateTime _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Invalid date');
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  @override
  Future<FinancialReport> financial({
    required String from,
    required String to,
  }) async {
    try {
      final days = _date(to).difference(_date(from)).inDays;
      if (days < 0 || days > 366) {
        throw const AppFailure('Choisissez une période de 367 jours maximum.');
      }
      final body = (await api.dio.get<Map<String, dynamic>>(
        'reports/financial',
        queryParameters: {'from': from, 'to': to},
      )).data!;
      final received = body['received_centimes'] as int,
          expenses = body['expense_centimes'] as int,
          balance = body['cash_balance_centimes'] as int,
          receipts = body['receipt_count'] as int,
          expenseCount = body['expense_count'] as int;
      if (body['currency'] != 'MAD' ||
          body['from'] != from ||
          body['to'] != to ||
          received < 0 ||
          expenses < 0 ||
          receipts < 0 ||
          expenseCount < 0 ||
          balance != received - expenses) {
        throw const FormatException('Invalid report');
      }
      return FinancialReport(
        from: from,
        to: to,
        received: received,
        expenses: expenses,
        cashBalance: balance,
        receiptCount: receipts,
        expenseCount: expenseCount,
      );
    } on DioException catch (error) {
      throw AppFailure(apiErrorMessage(error));
    } on FormatException {
      throw const AppFailure('Dates ou réponse du serveur invalides.');
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }
}
