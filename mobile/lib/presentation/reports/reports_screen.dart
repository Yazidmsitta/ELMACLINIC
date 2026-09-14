import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/reports/financial_report.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.repository});
  final ReportsRepository repository;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const periods = ["Aujourd'hui", 'Semaine', 'Mois', 'Année'];
  int _period = 2, _request = 0;
  FinancialReport? _report;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final now = ClinicTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final start = switch (_period) {
      0 => today,
      1 => today.subtract(Duration(days: today.weekday - 1)),
      2 => DateTime.utc(now.year, now.month),
      _ => DateTime.utc(now.year),
    };
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final result = await widget.repository.financial(
        from: DateFormat('yyyy-MM-dd').format(start),
        to: DateFormat('yyyy-MM-dd').format(today),
      );
      if (mounted && request == _request) setState(() => _report = result);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ElmaColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: ElmaColors.muted),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final report = _report;
    String mad(int cents) =>
        NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(cents / 100);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ElmaHeader(
              'Rapports',
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
                icon: const ElmaIcon('ChevronLeft'),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ElmaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: List.generate(
                          periods.length,
                          (index) => Expanded(
                            child: Semantics(
                              selected: _period == index,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: _period == index
                                      ? ElmaColors.brand
                                      : Colors.transparent,
                                  foregroundColor: _period == index
                                      ? Colors.white
                                      : ElmaColors.muted,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() => _period = index);
                                  _load();
                                },
                                child: Text(periods[index]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (_error != null) ...[
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElmaButton(label: 'Réessayer', onPressed: _load),
                    ],
                    if (report != null) ...[
                      Text(
                        '${report.from} — ${report.to}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ElmaColors.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _metric(
                              'Recettes encaissées',
                              mad(report.received),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric('Dépenses', mad(report.expenses)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _metric('Solde enregistré', mad(report.cashBalance)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'Encaissements',
                              '${report.receiptCount}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Dépenses enregistrées',
                              '${report.expenseCount}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Le solde correspond aux recettes encaissées moins les dépenses enregistrées. Il ne représente pas le bénéfice comptable.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ElmaColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
