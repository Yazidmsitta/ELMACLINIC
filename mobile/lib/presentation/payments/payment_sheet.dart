import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/payments/payments.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.appointment,
    required this.repository,
  });
  final ClinicAppointment appointment;
  final PaymentsRepository repository;
  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.card;
  PaymentBalance? _balance;
  String? _error, _key;
  bool _busy = false, _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balance = await widget.repository.balance(widget.appointment.id);
      if (mounted) setState(() => _balance = balance);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _loading || _balance == null) return;
    final cents = parseMadCentimes(_amount.text);
    if (cents == null || cents > _balance!.remaining) {
      setState(
        () =>
            _error = 'Saisissez un montant positif inférieur ou égal au solde.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _key ??= bookingRequestId();
    });
    try {
      final id = await widget.repository.record(
        widget.appointment.id,
        cents,
        _method,
        _key!,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String money(int value) =>
      NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(value / 100);
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encaisser un paiement',
                style: ElmaType.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.appointment.clientName, style: ElmaType.body),
              const SizedBox(height: 12),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_balance != null) ...[
                Text(
                  'Solde : ${money(_balance!.remaining)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Déjà encaissé : ${money(_balance!.paid)}',
                  style: const TextStyle(color: ElmaColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  enabled: !_busy && _key == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant (MAD)',
                    hintText: '0,00',
                  ),
                ),
                const SizedBox(height: 20),
                Text('MÉTHODE DE PAIEMENT', style: ElmaType.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final method in PaymentMethod.values)
                      ChoiceChip(
                        backgroundColor: ElmaColors.white,
                        selectedColor: ElmaColors.light,
                        side: BorderSide(
                          color: method == _method
                              ? ElmaColors.brand
                              : ElmaColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ElmaRadii.control,
                          ),
                        ),
                        label: Text(method.label),
                        selected: method == _method,
                        onSelected: _busy || _key != null
                            ? null
                            : (_) => setState(() => _method = method),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ElmaColors.red),
                  ),
                ),
              if (!_loading && _balance == null)
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              if (_key != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Réessayez avec le même montant pour vérifier cet encaissement. Ne créez pas un autre paiement sans vérifier le solde.',
                    style: TextStyle(fontSize: 12, color: ElmaColors.secondary),
                  ),
                ),
              ElmaButton(
                label: _key == null
                    ? 'Confirmer le paiement'
                    : 'Réessayer le paiement',
                loading: _busy,
                onPressed:
                    _loading || _balance == null || _balance!.remaining <= 0
                    ? null
                    : _save,
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PaymentScope extends InheritedWidget {
  const PaymentScope({
    super.key,
    required this.repository,
    required super.child,
  });
  final PaymentsRepository? repository;
  static PaymentsRepository? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaymentScope>()?.repository;
  @override
  bool updateShouldNotify(PaymentScope oldWidget) =>
      repository != oldWidget.repository;
}
