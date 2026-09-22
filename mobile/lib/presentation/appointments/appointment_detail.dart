import '../payments/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/payments/payments.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../widgets/appointment_card.dart';
import 'catalog_picker.dart';
import 'clinic_time.dart';

class AppointmentDetail extends StatefulWidget {
  const AppointmentDetail({
    super.key,
    required this.id,
    required this.repository,
    required this.catalog,
    required this.isAdmin,
  });
  final String id;
  final AppointmentsRepository repository;
  final CatalogRepository catalog;
  final bool isAdmin;
  @override
  State<AppointmentDetail> createState() => _AppointmentDetailState();
}

class _AppointmentDetailState extends State<AppointmentDetail> {
  int _generation = 0;
  ClinicAppointment? _appointment;
  Future<PaymentBalance>? _paymentBalance;
  String? _error;
  bool _loading = true, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appointment = await widget.repository.details(widget.id);
      if (mounted && generation == _generation) {
        final payments = PaymentScope.of(context);
        setState(() {
          _appointment = appointment;
          _paymentBalance = payments?.balance(appointment.id);
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _action(AppointmentStatus status) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passer à « ${status.label} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.changeStatus(_appointment!, status);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RescheduleSheet(
        appointment: _appointment!,
        repository: widget.repository,
        catalog: widget.catalog,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _editTotal() async {
    final appointment = _appointment!;
    final total = await showDialog<int>(
      context: context,
      builder: (_) => TotalOverrideDialog(totalCentimes: appointment.totalCentimes),
    );
    if (total == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.updateTotal(appointment, total);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver ce rendez-vous ?'),
        content: const Text('Son historique sera conservé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.archive(_appointment!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _paymentButton(ClinicAppointment appointment, bool ready) {
    final repository = PaymentScope.of(context);
    if (repository == null ||
        ![
          AppointmentStatus.confirmed,
          AppointmentStatus.inProgress,
          AppointmentStatus.completed,
        ].contains(appointment.status)) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<PaymentBalance>(
      future: _paymentBalance,
      builder: (context, snapshot) {
        final remaining = snapshot.data?.remaining;
        final paid = remaining != null && remaining <= 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElmaButton(
                label: paid ? 'Déjà encaissé' : 'Encaisser un paiement',
                onPressed:
                    !ready ||
                        paid ||
                        snapshot.connectionState != ConnectionState.done
                    ? null
                    : () async {
                        final saved = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          isDismissible: false,
                          enableDrag: false,
                          builder: (_) => PaymentSheet(
                            appointment: appointment,
                            repository: repository,
                          ),
                        );
                        if (mounted && context.mounted && saved != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Paiement enregistré.'),
                            ),
                          );
                          await _load();
                        }
                      },
              ),
              if (remaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    paid
                        ? 'Solde réglé.'
                        : 'Reste à encaisser : ${NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(remaining / 100)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: paid ? ElmaColors.green : ElmaColors.red,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String label, Widget child, {Color color = Colors.white}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: ElmaColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: ElmaType.label),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final a = _appointment;
    final ready = !_loading && !_busy && _error == null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ElmaHeader(
                'Détail du rendez-vous',
                titleStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leading: IconButton(
                  tooltip: 'Retour',
                  onPressed: _busy ? null : () => Navigator.maybePop(context),
                  icon: const ElmaIcon('ChevronLeft', size: 18),
                ),
                trailing: a != null && a.canReschedule
                    ? IconButton(
                        tooltip: 'Reporter',
                        onPressed: ready ? _edit : null,
                        icon: const ElmaIcon('Edit', size: 18),
                      )
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_loading || _busy) const LinearProgressIndicator(),
                      if (_error != null)
                        ElmaStatePanel(
                          title: 'Action indisponible',
                          message: _error!,
                          onRetry: _busy ? null : _load,
                        ),
                      if (a != null) ...[
                        _section(
                          'Statut actuel',
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                a.status.label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              AppointmentSourceBadge(a.source.code),
                            ],
                          ),
                          color: switch (a.status) {
                            AppointmentStatus.confirmed =>
                              ElmaColors.greenLight,
                            AppointmentStatus.pending => ElmaColors.amberLight,
                            AppointmentStatus.inProgress =>
                              ElmaColors.purpleLight,
                            AppointmentStatus.cancelled => ElmaColors.redLight,
                            AppointmentStatus.fresh => ElmaColors.blueLight,
                            _ => ElmaColors.completedLight,
                          },
                        ),
                        _section(
                          'Client',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.clientName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (a.clientPhone != null)
                                SelectableText(a.clientPhone!),
                            ],
                          ),
                        ),
                        _section(
                          'Rendez-vous',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat(
                                  'EEEE d MMMM yyyy · HH:mm',
                                  'fr',
                                ).format(ClinicTime.local(a.start)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a.practitionerName ??
                                    'Praticienne non affectée',
                              ),
                              Text(
                                '${a.end.difference(a.start).inMinutes} minutes · Casablanca',
                              ),
                              if (a.canReschedule) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: ready ? _edit : null,
                                  icon: const ElmaIcon('Calendar', size: 16),
                                  label: const Text('Reporter à une autre date'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _section(
                          'Prestations',
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in a.services)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '${item.name} × ${item.quantity} · ${NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(item.priceCentimes / 100)}',
                                  ),
                                ),
                              const Divider(),
                              Text(
                                'Total : ${NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(a.totalCentimes / 100)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ElmaColors.brand,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: ready && !_busy ? _editTotal : null,
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Modifier le total'),
                              ),
                            ],
                          ),
                        ),
                        if (a.notes != null && a.notes!.isNotEmpty)
                          _section('Notes', Text(a.notes!)),
                        _paymentButton(a, ready),
                        if (a.status.next.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            child: Text(
                              'Modifier le statut',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        if ([
                          AppointmentStatus.fresh,
                          AppointmentStatus.pending,
                        ].contains(a.status))
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Confirmez le rendez-vous pour pouvoir encaisser un paiement.',
                              style: TextStyle(
                                fontSize: 12,
                                color: ElmaColors.secondary,
                              ),
                            ),
                          ),
                        for (final status in a.status.next.where(
                          (s) =>
                              ![
                                AppointmentStatus.inProgress,
                                AppointmentStatus.noShow,
                              ].contains(s) ||
                              !a.start.isAfter(DateTime.now()),
                        ))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton(
                              onPressed: ready ? () => _action(status) : null,
                              child: Text(switch (status) {
                                AppointmentStatus.pending =>
                                  'Mettre en attente',
                                AppointmentStatus.confirmed =>
                                  'Confirmer le RDV',
                                AppointmentStatus.inProgress =>
                                  'Démarrer la séance',
                                AppointmentStatus.completed =>
                                  'Confirmer séance terminée',
                                AppointmentStatus.cancelled =>
                                  'Annuler le rendez-vous',
                                AppointmentStatus.noShow => 'Marquer absent',
                                _ => status.label,
                              }),
                            ),
                          ),
                        if (widget.isAdmin)
                          TextButton(
                            onPressed: ready ? _archive : null,
                            child: const Text(
                              'Archiver',
                              style: TextStyle(color: ElmaColors.red),
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
      ),
    );
  }
}

class TotalOverrideDialog extends StatefulWidget {
  const TotalOverrideDialog({super.key, required this.totalCentimes});
  final int totalCentimes;
  @override
  State<TotalOverrideDialog> createState() => _TotalOverrideDialogState();
}

class _TotalOverrideDialogState extends State<TotalOverrideDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = (widget.totalCentimes / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Modifier le total'),
    content: TextFormField(
      initialValue: _value,
      onChanged: (value) => _value = value,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Nouveau total (MAD)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final cents = parseMadCentimes(_value);
          if (cents != null) Navigator.pop(context, cents);
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class RescheduleSheet extends StatefulWidget {
  const RescheduleSheet({
    super.key,
    required this.appointment,
    required this.repository,
    required this.catalog,
  });
  final ClinicAppointment appointment;
  final AppointmentsRepository repository;
  final CatalogRepository catalog;
  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  late DateTime _day;
  late TimeOfDay _time;
  late TextEditingController _notes;
  String? _practitioner, _name, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final local = ClinicTime.local(widget.appointment.start);
    _day = DateTime(local.year, local.month, local.day);
    _time = TimeOfDay(hour: local.hour, minute: local.minute);
    _notes = TextEditingController(text: widget.appointment.notes);
    _practitioner = widget.appointment.practitionerId;
    _name = widget.appointment.practitionerName;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPractitioner() async {
    final result = await showModalBottomSheet<CatalogEntry>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CatalogPicker(
              kind: CatalogKind.practitioners,
              repository: widget.catalog,
              selected: {?_practitioner},
              onSelect: (entry) => Navigator.pop(context, entry),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _practitioner = result.id;
        _name = result.name;
      });
    }
  }

  Future<void> _date() async {
    final now = ClinicTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(first) ? first : _day,
      firstDate: first,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _hour() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Heure de Casablanca',
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reschedule(
        widget.appointment,
        _practitioner!,
        ClinicTime.at(_day, _time),
        _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Reporter le rendez-vous',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Les prestations et leurs tarifs enregistrés sont conservés.',
                  style: TextStyle(fontSize: 12, color: ElmaColors.muted),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _pickPractitioner,
                  child: Text(_name ?? 'Choisir une praticienne'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _date,
                  child: Text(DateFormat('dd/MM/yyyy').format(_day)),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _hour,
                  child: Text('${_time.format(context)} · Casablanca'),
                ),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 2000,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: ElmaColors.red)),
                ElmaButton(
                  label: 'Reporter',
                  loading: _busy,
                  onPressed: _practitioner == null ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
