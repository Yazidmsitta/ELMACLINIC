import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/expenses/expenses.dart';
import '../../domain/payments/payments.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

String expenseMoney(int value) =>
    '${NumberFormat('#,##0.00', 'fr').format(value / 100)} MAD';

Widget _summaryCard(
  String value,
  String label,
  Color background,
  Color foreground,
) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: ElmaColors.secondary),
      ),
    ],
  ),
);

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.repository});
  final ExpensesRepository repository;
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final List<Expense> _items = [];
  bool _voided = false, _busy = false, _more = false;
  int _page = 0, _total = 0, _generation = 0;
  String? _error;
  ExpenseSummary? _summary;
  String? _summaryError;
  Future<void> _loadSummary(int generation) async {
    try {
      final value = await widget.repository.summary();
      if (mounted && generation == _generation) {
        setState(() => _summary = value);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _summaryError = friendlyError(error));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (next && _busy) return;
    final generation = ++_generation;
    final page = next ? _page + 1 : 1;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) _items.clear();
      if (!next) {
        _summary = null;
        _summaryError = null;
      }
    });
    final summaryLoad = !next ? _loadSummary(generation) : Future<void>.value();
    try {
      final result = await widget.repository.list(voided: _voided, page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _more = result.hasMore;
        _page = page;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      await summaryLoad;
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Expense? expense, bool voiding = false]) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ExpenseSheet(
        repository: widget.repository,
        expense: expense,
        voiding: voiding,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Dépenses',
            leading: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const ElmaIcon('ChevronLeft'),
            ),
            trailing: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const ElmaIcon('Plus', size: 15, color: Colors.white),
              label: const Text('Ajouter'),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_summary != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _summaryCard(
                            expenseMoney(_summary!.monthCentimes),
                            'Ce mois',
                            ElmaColors.redLight,
                            ElmaColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryCard(
                            '${_summary!.monthTransactions}',
                            'Transactions du mois',
                            ElmaColors.light,
                            ElmaColors.brand,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_summaryError != null) ...[
                    Text('Résumé indisponible : $_summaryError'),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Réessayer le résumé'),
                    ),
                  ],
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final state in [false, true])
                        ChoiceChip(
                          label: Text(state ? 'Annulées' : 'Actives'),
                          selected: _voided == state,
                          onSelected: (_) {
                            setState(() => _voided = state);
                            _load();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_busy && _error == null)
                    Text(
                      '$_total transactions',
                      style: const TextStyle(color: ElmaColors.secondary),
                    ),
                  const SizedBox(height: 12),
                  for (final expense in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ElmaColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: ElmaDecor.brand,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    expense.category.characters
                                        .take(2)
                                        .toString()
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.category,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${expense.description} · ${DateFormat.yMMMd('fr').format(DateTime.parse(expense.spentOn))}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ElmaColors.muted,
                                        ),
                                      ),
                                      Text(
                                        expenseMoney(expense.amount),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: ElmaColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (expense.voidedAt == null)
                                  PopupMenuButton<String>(
                                    tooltip: 'Actions',
                                    icon: const ElmaIcon('Edit', size: 18),
                                    onSelected: (value) =>
                                        _edit(expense, value == 'void'),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Modifier'),
                                      ),
                                      PopupMenuItem(
                                        value: 'void',
                                        child: Text('Annuler la dépense'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (expense.voidReason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text('Annulée : ${expense.voidReason}'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(next: _items.isNotEmpty),
                      child: const Text('Réessayer'),
                    ),
                  ],
                  if (!_busy && _error == null && _items.isEmpty)
                    const Text('Aucune dépense.'),
                  if (!_busy && _error == null && _more)
                    TextButton(
                      onPressed: () => _load(next: true),
                      child: const Text('Charger la suite'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({
    super.key,
    required this.repository,
    this.expense,
    this.voiding = false,
  });
  final ExpensesRepository repository;
  final Expense? expense;
  final bool voiding;
  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _description, _amount;
  late final TextEditingController _label;
  final _reason = TextEditingController();
  late DateTime _date;
  final _requestId = bookingRequestId();
  bool _busy = false, _submitted = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _description = TextEditingController(text: expense?.description);
    _label = TextEditingController(text: expense?.category ?? '');
    _amount = TextEditingController(
      text: expense == null
          ? ''
          : '${expense.amount ~/ 100}.${(expense.amount % 100).toString().padLeft(2, '0')}',
    );
    _date = expense == null
        ? ClinicTime.now()
        : DateTime.parse(expense.spentOn);
  }

  @override
  void dispose() {
    _description.dispose();
    _label.dispose();
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _submitted = true;
      _error = null;
    });
    try {
      if (widget.voiding) {
        await widget.repository.voidExpense(
          widget.expense!,
          _reason.text.trim(),
        );
      } else {
        final draft = ExpenseDraft(
          _description.text.trim(),
          _label.text.trim(),
          parseMadCentimes(_amount.text)!,
          DateFormat('yyyy-MM-dd').format(_date),
        );
        if (widget.expense == null) {
          await widget.repository.create(draft, _requestId);
        } else {
          await widget.repository.update(widget.expense!, draft);
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || (_submitted && widget.expense == null);
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.voiding
                              ? 'Annuler la dépense'
                              : widget.expense == null
                              ? 'Nouvelle dépense'
                              : 'Modifier la dépense',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const ElmaIcon('X'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.voiding)
                    TextFormField(
                      controller: _reason,
                      enabled: !_busy,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Motif d’annulation',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 3
                          ? 'Saisissez au moins 3 caractères.'
                          : null,
                    )
                  else ...[
                    TextFormField(
                      controller: _label,
                      enabled: !locked,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Libellé',
                        hintText: 'Ex. Achat produits soins',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Libellé obligatoire.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      enabled: !locked,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Description obligatoire.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amount,
                      enabled: !locked,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Montant (MAD)',
                      ),
                      validator: (value) =>
                          parseMadCentimes(value ?? '') == null
                          ? 'Saisissez un montant positif, avec 2 décimales maximum.'
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: locked
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100),
                              );
                              if (date != null && mounted) {
                                setState(() => _date = date);
                              }
                            },
                      icon: const ElmaIcon('Calendar', size: 16),
                      label: Text(DateFormat.yMMMMd('fr').format(_date)),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: ElmaColors.red),
                      ),
                    ),
                  if (_submitted && widget.expense == null && !_busy)
                    const Text(
                      'Réessayez avec les mêmes informations pour éviter un doublon.',
                    ),
                  const SizedBox(height: 16),
                  ElmaButton(
                    label: widget.voiding
                        ? 'Confirmer l’annulation'
                        : 'Enregistrer la dépense',
                    loading: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
