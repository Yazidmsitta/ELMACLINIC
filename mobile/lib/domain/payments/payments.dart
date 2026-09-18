enum PaymentMethod {
  cash('CASH', 'Espèces'),
  card('CARD', 'Carte'),
  transfer('TRANSFER', 'Virement');

  const PaymentMethod(this.code, this.label);
  final String code, label;
}

class PaymentBalance {
  const PaymentBalance(this.total, this.paid, this.remaining);
  final int total, paid, remaining;
}

abstract interface class PaymentsRepository {
  Future<PaymentLedger> ledger({int page = 1});
  Future<PaymentBalance> balance(String appointmentId);
  Future<String> record(
    String appointmentId,
    int amount,
    PaymentMethod method,
    String requestId,
  );
}

/// Exact decimal conversion, without floating-point rounding or locale guesses.
int? parseMadCentimes(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d{1,8}([.,]\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.replaceAll(',', '.').split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  return cents > 0 && cents <= 2147483647 ? cents : null;
}

class PaymentEntry {
  const PaymentEntry(
    this.id,
    this.clientName,
    this.services,
    this.amount,
    this.method,
    this.paidAt, {
    this.clientId,
    this.remaining = 0,
  });
  final String id, clientName, services;
  final int amount;
  final PaymentMethod method;
  final DateTime paidAt;
  final String? clientId;
  final int remaining;
}

class PaymentLedger {
  const PaymentLedger(
    this.items,
    this.total,
    this.hasMore,
    this.today,
    this.month,
    this.clinicDate,
  );
  final List<PaymentEntry> items;
  final int total, today, month;
  final bool hasMore;
  final String clinicDate;
}
