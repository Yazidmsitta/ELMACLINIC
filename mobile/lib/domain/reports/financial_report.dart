class FinancialReport {
  const FinancialReport({
    required this.from,
    required this.to,
    required this.received,
    required this.expenses,
    required this.cashBalance,
    required this.receiptCount,
    required this.expenseCount,
  });
  final String from, to;
  final int received, expenses, cashBalance, receiptCount, expenseCount;
}

abstract interface class ReportsRepository {
  Future<FinancialReport> financial({required String from, required String to});
}
