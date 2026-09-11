import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/website/website_bookings.dart';
import '../appointments/appointment_detail.dart';
import '../appointments/booking_wizard.dart';
import '../appointments/clinic_time.dart';
import '../shell/more_screen.dart' show initials;
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class WebsiteBookingsScreen extends StatefulWidget {
  const WebsiteBookingsScreen({
    super.key,
    required this.repository,
    required this.appointments,
    required this.catalog,
    required this.isAdmin,
  });
  final WebsiteBookingsRepository repository;
  final AppointmentsRepository appointments;
  final CatalogRepository catalog;
  final bool isAdmin;
  @override
  State<WebsiteBookingsScreen> createState() => _WebsiteBookingsScreenState();
}

class _WebsiteBookingsScreenState extends State<WebsiteBookingsScreen> {
  WebsiteState _state = WebsiteState.review;
  List<WebsiteBooking> _items = [];
  int _page = 1, _generation = 0, _total = 0;
  bool _busy = false, _more = false;
  String? _error;
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
      if (!next) {
        _items = [];
        _total = 0;
        _more = false;
      }
    });
    try {
      final result = await widget.repository.list(_state, page: page);
      if (mounted && generation == _generation) {
        setState(() {
          _items = next ? [..._items, ...result.items] : result.items;
          _total = result.total;
          _more = result.hasMore;
          _page = page;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _open(WebsiteBooking event) async {
    if (event.state == WebsiteState.dismissed) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Demande écartée'),
          content: Text(event.dismissalReason ?? 'Motif non disponible'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }
    String? id = event.appointmentId;
    if (event.state == WebsiteState.review) {
      final proceed = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérifier la demande'),
          content: SingleChildScrollView(
            child: Text(
              '${event.clientName}\n${event.phone ?? "Téléphone non fourni"}\n${DateFormat('dd/MM/yyyy · HH:mm').format(ClinicTime.local(event.start))}\n\nRéférences prestations : ${event.serviceReferences.join(', ')}\n${event.notes ?? ""}\n\nSélectionnez les fiches du cabinet correspondantes. La date demandée sera conservée.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'dismiss'),
              child: const Text('Écarter la demande'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'back'),
              child: const Text('Retour'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'import'),
              child: const Text('Associer les fiches'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed == 'dismiss') {
        await showDialog<void>(
          context: context,
          builder: (_) =>
              _DismissDialog(event: event, repository: widget.repository),
        );
        if (mounted) await _load();
        return;
      }
      if (proceed != 'import') return;
      id = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => BookingWizard(
            repository: widget.appointments,
            catalog: widget.catalog,
            websiteBooking: event,
            websiteRepository: widget.repository,
          ),
        ),
      );
    }
    if (id != null && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AppointmentDetail(
            id: id!,
            repository: widget.appointments,
            catalog: widget.catalog,
            isAdmin: widget.isAdmin,
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Réservations en ligne',
            titleStyle: ElmaType.display.copyWith(fontSize: 20),
            subtitle: 'elmaclinic.ma · Demandes reçues',
            leading: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.pop(context),
              icon: const ElmaIcon('ChevronLeft'),
            ),
            trailing: IconButton(
              tooltip: 'Actualiser la liste',
              onPressed: _busy ? null : () => _load(),
              icon: const ElmaIcon('Refresh'),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_total réservation(s) · ${_state.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: ElmaColors.muted,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final state in [
                      WebsiteState.review,
                      WebsiteState.imported,
                      WebsiteState.dismissed,
                    ])
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => _state = state);
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color: state == _state
                                      ? ElmaColors.blue
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Text(
                              state.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: state == _state
                                    ? ElmaColors.statusNew
                                    : ElmaColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: ElmaColors.red),
                    ),
                    TextButton(
                      onPressed: () => _load(next: _items.isNotEmpty),
                      child: const Text('Réessayer'),
                    ),
                  ],
                  if (!_busy && _error == null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Text(
                        'Aucune réservation pour ce filtre',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final event in _items) _card(event),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                  if (_more && !_busy)
                    TextButton(
                      onPressed: () => _load(next: true),
                      child: const Text('Afficher plus'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _card(WebsiteBooking event) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElmaRadii.card),
        side: BorderSide(
          color: event.state == WebsiteState.review
              ? ElmaColors.blue
              : ElmaColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(event),
        child: Column(
          children: [
            if (event.state == WebsiteState.review)
              Container(height: 2, color: ElmaColors.blue),
            Padding(
              padding: const EdgeInsets.all(16),
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
                          color: ElmaColors.blueLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(initials(event.clientName)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.clientName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              event.phone ?? 'Téléphone non fourni',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ElmaColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${event.serviceReferences.length} prestation(s) demandée(s)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy · HH:mm',
                    ).format(ClinicTime.local(event.start)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: ElmaColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ElmaColors.blueLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Site web',
                          style: TextStyle(
                            fontSize: 11,
                            color: ElmaColors.statusNew,
                          ),
                        ),
                      ),
                      Text(
                        event.state == WebsiteState.review
                            ? 'Action requise →'
                            : event.state == WebsiteState.dismissed
                            ? 'Voir le motif →'
                            : 'Voir le rendez-vous →',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ElmaColors.statusNew,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DismissDialog extends StatefulWidget {
  const _DismissDialog({required this.event, required this.repository});
  final WebsiteBooking event;
  final WebsiteBookingsRepository repository;
  @override
  State<_DismissDialog> createState() => _DismissDialogState();
}

class _DismissDialogState extends State<_DismissDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Indiquez un motif (3 caractères minimum).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.dismiss(widget.event, reason);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Écarter la demande'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'La demande restera dans l’historique. Cette action ne modifie pas le site web.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Motif obligatoire'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: ElmaColors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Enregistrement…' : 'Écarter'),
        ),
      ],
    ),
  );
}
