import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/payments/payments.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/app_failure.dart';
import '../catalog/client_detail_screen.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class PaymentLedgerScreen extends StatefulWidget {
  const PaymentLedgerScreen({
    super.key,
    required this.repository,
    required this.onCollect,
    this.canCollect = true,
    this.catalog,
    this.appointments,
    this.refreshToken = 0,
  });
  final PaymentsRepository repository;
  final VoidCallback onCollect;
  final bool canCollect;
  final CatalogRepository? catalog;
  final AppointmentsRepository? appointments;
  final int refreshToken;
  @override
  State<PaymentLedgerScreen> createState() => _PaymentLedgerScreenState();
}

class _PaymentLedgerScreenState extends State<PaymentLedgerScreen> {
  PaymentLedger? _ledger;
  List<PaymentEntry> _items = [];
  int _page = 1, _generation = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PaymentLedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load({bool next = false}) async {
    if (next && _busy) return;
    final generation = ++_generation;
    final page = next ? _page + 1 : 1;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) {
        _items = [];
        _ledger = null;
      }
    });
    try {
      final result = await widget.repository.ledger(page: page);
      if (mounted && generation == _generation) {
        setState(() {
          _ledger = result;
          _items = next ? [..._items, ...result.items] : result.items;
          _page = page;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  String money(int cents) =>
      NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(cents / 100);

  Future<void> _openClient(PaymentEntry entry) async {
    if (widget.catalog == null || entry.clientId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          entry: CatalogEntry(id: entry.clientId!, name: entry.clientName),
          repository: widget.catalog!,
          appointments: widget.appointments,
          isAdmin: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => _load(),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ElmaHeader(
          'Paiements',
          trailing: widget.canCollect
              ? TextButton.icon(
                  onPressed: widget.onCollect,
                  icon: const ElmaIcon('Plus', size: 15),
                  label: const Text('Encaisser'),
                )
              : null,
        ),
        if (_ledger != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        "Aujourd’hui",
                        _ledger!.today,
                        ElmaColors.light,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metric(
                        'Ce mois',
                        _ledger!.month,
                        ElmaColors.greenLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_ledger!.total} transaction(s) · ${_ledger!.clinicDate}',
                  style: const TextStyle(fontSize: 12, color: ElmaColors.muted),
                ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_error!, style: const TextStyle(color: ElmaColors.red)),
                TextButton(
                  onPressed: () => _load(next: _items.isNotEmpty),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        if (!_busy && _error == null && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Text(
              'Aucun paiement enregistré.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final entry in _items)
          InkWell(
            onTap: entry.clientId == null ? null : () => _openClient(entry),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: ElmaColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const ElmaIcon('Wallet'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.clientName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          entry.remaining > 0
                              ? 'Reste à payer : ${money(entry.remaining)}'
                              : 'Solde payé',
                          style: TextStyle(
                            fontSize: 12,
                            color: entry.remaining > 0
                                ? ElmaColors.red
                                : ElmaColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          entry.services,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ElmaColors.muted,
                          ),
                        ),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(ClinicTime.local(entry.paidAt))} · ${entry.method.label}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: ElmaColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(entry.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Encaissé',
                          style: TextStyle(
                            fontSize: 11,
                            color: ElmaColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_busy && (_ledger?.hasMore ?? false))
          TextButton(
            onPressed: () => _load(next: true),
            child: const Text('Afficher plus'),
          ),
      ],
    ),
  );
  Widget _metric(String label, int value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          money(value),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: ElmaColors.secondary),
        ),
      ],
    ),
  );
}
