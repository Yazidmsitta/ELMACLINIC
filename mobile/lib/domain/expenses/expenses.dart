class Expense {
  const Expense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.spentOn,
    required this.version,
    this.voidedAt,
    this.voidReason,
  });
  final String id, description, category, spentOn;
  final int amount, version;
  final DateTime? voidedAt;
  final String? voidReason;
}

class ExpenseDraft {
  const ExpenseDraft(
    this.description,
    this.category,
    this.amount,
    this.spentOn,
  );
  final String description, category, spentOn;
  final int amount;
}

class ExpensePage {
  const ExpensePage(this.items, this.total, this.hasMore);
  final List<Expense> items;
  final int total;
  final bool hasMore;
}

abstract interface class ExpensesRepository {
  Future<ExpenseSummary> summary();
  Future<ExpensePage> list({bool voided = false, int page = 1});
  Future<String> create(ExpenseDraft draft, String requestId);
  Future<void> update(Expense expense, ExpenseDraft draft);
  Future<void> voidExpense(Expense expense, String reason);
}

class ExpenseSummary {
  const ExpenseSummary(
    this.monthCentimes,
    this.monthTransactions,
    this.clinicDate,
  );
  final int monthCentimes, monthTransactions;
  final String clinicDate;
}
