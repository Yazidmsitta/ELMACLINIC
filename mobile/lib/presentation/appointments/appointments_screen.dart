import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../widgets/appointment_card.dart';
import 'appointment_detail.dart';
import 'booking_wizard.dart';
import 'catalog_picker.dart';
import 'clinic_time.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({
    super.key,
    required this.repository,
    required this.catalog,
    required this.isAdmin,
    this.initialDay,
  });
  final AppointmentsRepository repository;
  final CatalogRepository catalog;
  final bool isAdmin;
  final DateTime? initialDay;
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with WidgetsBindingObserver {
  late DateTime _day;
  AppointmentStatus? _status;
  AppointmentSource? _source;
  String? _practitioner, _practitionerName, _error;
  List<ClinicAppointment> _entries = [];
  bool _loading = true, _more = false, _filters = false, _failedMore = false;
  int _page = 1, _total = 0, _generation = 0;
  @override
  void initState() {
    super.initState();
    final now = widget.initialDay ?? ClinicTime.now();
    _day = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _failedMore = more;
      if (!more) {
        _entries = [];
        _more = false;
      }
    });
    try {
      final page = more ? _page + 1 : 1;
      final result = await widget.repository.list(
        _day,
        page: page,
        status: _status,
        source: _source,
        practitionerId: _practitioner,
      );
      if (mounted && generation == _generation) {
        setState(() {
          _entries = [if (more) ..._entries, ...result.entries];
          _page = page;
          _more = result.hasMore;
          _total = result.total;
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

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppointmentDetail(
          id: id,
          repository: widget.repository,
          catalog: widget.catalog,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BookingWizard(
          repository: widget.repository,
          catalog: widget.catalog,
        ),
      ),
    );
    if (id != null && mounted) {
      await _open(id);
    } else if (mounted) {
      await _load();
    }
  }

  void _selectDay(DateTime day) {
    setState(() => _day = day);
    _load();
  }

  Future<void> _calendar() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null && mounted) _selectDay(result);
  }

  Future<void> _filterPractitioner() async {
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
        _practitionerName = result.name;
      });
      await _load();
    }
  }

  Widget _chips(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: children
          .map(
            (child) =>
                Padding(padding: const EdgeInsets.only(right: 8), child: child),
          )
          .toList(),
    ),
  );
  Widget _card(ClinicAppointment a) {
    final color = switch (a.status) {
      AppointmentStatus.confirmed => ElmaColors.green,
      AppointmentStatus.pending => ElmaColors.amber,
      AppointmentStatus.inProgress => ElmaColors.purple,
      AppointmentStatus.cancelled => ElmaColors.red,
      _ => ElmaColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ElmaColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(a.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.clientName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    a.services.map((s) => s.name).join(' · '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ElmaColors.secondary,
                                    ),
                                  ),
                                  Text(
                                    a.practitionerName ?? 'Non affectée',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ElmaColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                Text(
                                  DateFormat(
                                    'HH:mm',
                                  ).format(ClinicTime.local(a.start)),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${a.end.difference(a.start).inMinutes}min',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ElmaColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  AppointmentStatusBadge(a.status.code),
                                  AppointmentSourceBadge(a.source.code),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              NumberFormat.currency(
                                locale: 'fr',
                                symbol: 'MAD',
                              ).format(a.totalCentimes / 100),
                              style: const TextStyle(
                                color: ElmaColors.brand,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(_day.year, _day.month, _day.day - _day.weekday + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElmaHeader(
          'Rendez-vous',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Filtres',
                onPressed: () => setState(() => _filters = !_filters),
                icon: const ElmaIcon('Filter', size: 16),
              ),
              ElmaCompactButton(label: 'Nouveau', onPressed: _create),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              TextButton(
                onPressed: _calendar,
                child: Text(DateFormat('MMMM yyyy', 'fr').format(_day)),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Semaine précédente',
                    onPressed: () => _selectDay(
                      DateTime(_day.year, _day.month, _day.day - 7),
                    ),
                    icon: const ElmaIcon('ChevronLeft', size: 16),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(7, (i) {
                          final date = DateTime(
                            monday.year,
                            monday.month,
                            monday.day + i,
                          );
                          final selected = date == _day;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 6,
                              bottom: 12,
                            ),
                            child: InkWell(
                              onTap: () => _selectDay(date),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: selected ? ElmaDecor.brand : null,
                                  color: selected ? null : ElmaColors.canvas,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('EEE', 'fr').format(date),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: selected
                                            ? Colors.white
                                            : ElmaColors.secondary,
                                      ),
                                    ),
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? Colors.white
                                            : ElmaColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Semaine suivante',
                    onPressed: () => _selectDay(
                      DateTime(_day.year, _day.month, _day.day + 7),
                    ),
                    icon: const ElmaIcon('ChevronRight', size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_filters)
          Container(
            color: ElmaColors.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _chips([
                  ElmaFilterChip(
                    label: const Text('Tous'),
                    selected: _status == null,
                    onSelected: (_) {
                      setState(() => _status = null);
                      _load();
                    },
                  ),
                  for (final status in AppointmentStatus.values)
                    ElmaFilterChip(
                      label: Text(status.label),
                      selected: _status == status,
                      onSelected: (_) {
                        setState(() => _status = status);
                        _load();
                      },
                    ),
                ]),
                _chips([
                  ElmaFilterChip(
                    label: const Text('Toutes les sources'),
                    selected: _source == null,
                    onSelected: (_) {
                      setState(() => _source = null);
                      _load();
                    },
                  ),
                  for (final source in AppointmentSource.values)
                    ElmaFilterChip(
                      label: Text(source.label),
                      selected: _source == source,
                      onSelected: (_) {
                        setState(() => _source = source);
                        _load();
                      },
                    ),
                ]),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _filterPractitioner,
                      child: Text(
                        _practitionerName ?? 'Toutes les praticiennes',
                      ),
                    ),
                    if (_practitioner != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _practitioner = null;
                            _practitionerName = null;
                          });
                          _load();
                        },
                        child: const Text('Réinitialiser'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  ElmaStatePanel(
                    title: 'Chargement impossible',
                    message: _error!,
                    onRetry: () => _load(more: _failedMore),
                  ),
                if (!_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$_total rendez-vous',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ElmaColors.muted,
                      ),
                    ),
                  ),
                if (!_loading && _error == null && _entries.isEmpty)
                  const ElmaStatePanel(
                    title: 'Aucun rendez-vous',
                    message: 'Pour cette journée et ces filtres.',
                    icon: 'Calendar',
                  ),
                ..._entries.map(_card),
                if (_more)
                  TextButton(
                    onPressed: _loading ? null : () => _load(more: true),
                    child: const Text('Afficher plus'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
