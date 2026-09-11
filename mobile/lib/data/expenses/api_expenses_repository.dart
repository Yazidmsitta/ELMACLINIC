import 'package:dio/dio.dart';
import '../../domain/app_failure.dart';
import '../../domain/expenses/expenses.dart';
import '../api/api_client.dart';

class ApiExpensesRepository implements ExpensesRepository {
  ApiExpensesRepository(this.api);
  final ApiClient api;
  bool _validDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value)?.toIso8601String().substring(0, 10) == value;
  @override
  Future<ExpenseSummary> summary() => _request(() async {
    final body = (await api.dio.get<Map<String, dynamic>>(
      'expenses/summary',
    )).data!;
    final amount = body['month_centimes'] as int;
    final count = body['month_transactions'] as int;
    final date = body['clinic_date'] as String;
    if (body['currency'] != 'MAD' ||
        amount < 0 ||
        count < 0 ||
        !_validDate(date)) {
      throw const FormatException('Invalid expense summary');
    }
    return ExpenseSummary(amount, count, date);
  });
  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AppFailure(apiErrorMessage(e));
    } on FormatException {
      throw const AppFailure('Réponse du serveur invalide.');
    } on TypeError {
      throw const AppFailure('Réponse du serveur invalide.');
    }
  }

  Map<String, dynamic> _draft(ExpenseDraft draft) => {
    'description': draft.description,
    'category': draft.category,
    'amount_centimes': draft.amount,
    'spent_on': draft.spentOn,
  };
  @override
  Future<ExpensePage> list({bool voided = false, int page = 1}) => _request(
    () async {
      final body = (await api.dio.get<Map<String, dynamic>>(
        'expenses',
        queryParameters: {'state': voided ? 'voided' : 'active', 'page': page},
      )).data!;
      return ExpensePage(
        (body['data'] as List).map((dynamic raw) {
          final row = raw as Map<String, dynamic>;
          if (!_validDate(row['spent_on'] as String) ||
              (row['amount_centimes'] as int) <= 0 ||
              (row['version'] as int) < 1) {
            throw const FormatException('Invalid expense record');
          }
          return Expense(
            id: row['id'] as String,
            description: row['description'] as String,
            category: row['category'] as String,
            amount: row['amount_centimes'] as int,
            spentOn: row['spent_on'] as String,
            version: row['version'] as int,
            voidedAt: row['voided_at'] == null
                ? null
                : DateTime.parse(row['voided_at'] as String),
            voidReason: row['void_reason'] as String?,
          );
        }).toList(),
        body['total'] as int,
        body['has_more'] as bool,
      );
    },
  );
  @override
  Future<String> create(ExpenseDraft draft, String requestId) => _request(
    () async =>
        (await api.dio.post<Map<String, dynamic>>(
              'expenses',
              data: {..._draft(draft), 'request_id': requestId},
            )).data!['id']
            as String,
  );
  @override
  Future<void> update(Expense expense, ExpenseDraft draft) =>
      _request(() async {
        await api.dio.patch<dynamic>(
          'expenses/${expense.id}',
          data: {..._draft(draft), 'version': expense.version},
        );
      });
  @override
  Future<void> voidExpense(Expense expense, String reason) =>
      _request(() async {
        await api.dio.delete<dynamic>(
          'expenses/${expense.id}',
          data: {'version': expense.version, 'reason': reason},
        );
      });
}
