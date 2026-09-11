import '../../domain/website/website_bookings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'catalog_picker.dart';
import 'clinic_time.dart';

class BookingWizard extends StatefulWidget {
  const BookingWizard({
    super.key,
    required this.repository,
    required this.catalog,
    this.websiteBooking,
    this.websiteRepository,
  });
  final AppointmentsRepository repository;
  final CatalogRepository catalog;
  final WebsiteBooking? websiteBooking;
  final WebsiteBookingsRepository? websiteRepository;
  @override
  State<BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends State<BookingWizard> {
  static const _steps = [
    'Client',
    'Prestation',
    'Praticienne',
    'Date & heure',
    'Confirmation',
  ];
  int _step = 0;
  CatalogEntry? _client, _practitioner;
  final List<CatalogEntry> _services = [];
  DateTime? _day;
  TimeOfDay? _time;
  final _notes = TextEditingController();
  BookingQuote? _quote;
  String? _error, _requestId;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final event = widget.websiteBooking;
    if (event != null) {
      final local = ClinicTime.local(event.start);
      _day = local;
      _time = TimeOfDay.fromDateTime(local);
      _notes.text = event.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _ready => switch (_step) {
    0 => _client != null,
    1 => _services.isNotEmpty,
    2 => _practitioner != null,
    3 => _day != null && _time != null,
    _ => _quote != null,
  };
  BookingSelection get _selection => BookingSelection(
    _client!.id,
    _practitioner!.id,
    _services.map((s) => s.id).toList(),
    widget.websiteBooking?.start ?? ClinicTime.at(_day!, _time!),
  );
  Future<void> _next() async {
    if (!_ready || _busy) return;
    if (_step < 3) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_step == 3) {
        final quote = await widget.repository.quote(_selection);
        if (mounted) {
          setState(() {
            _quote = quote;
            _step = 4;
          });
        }
      } else {
        _requestId ??= bookingRequestId();
        final id = widget.websiteBooking != null
            ? await widget.websiteRepository!.importBooking(
                widget.websiteBooking!,
                _selection,
                _quote!,
              )
            : await widget.repository.create(
                _selection,
                _quote!,
                _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                _requestId!,
              );
        if (mounted) Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _date() async {
    final now = ClinicTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _day ?? first,
      firstDate: first,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (date != null && mounted) setState(() => _day = date);
  }

  Future<void> _hour() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Heure de Casablanca',
    );
    if (time != null && mounted) setState(() => _time = time);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ElmaHeader(
              widget.websiteBooking == null
                  ? 'Nouveau rendez-vous'
                  : 'Importer la réservation',
              titleStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              subtitle: 'Étape ${_step + 1} / 5 — ${_steps[_step]}',
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: _busy ? null : () => Navigator.maybePop(context),
                icon: const ElmaIcon('ChevronLeft', size: 18),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                      decoration: BoxDecoration(
                        gradient: i <= _step ? ElmaDecor.brand : null,
                        color: i <= _step ? null : ElmaColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: switch (_step) {
                  0 => CatalogPicker(
                    key: const ValueKey('client'),
                    kind: CatalogKind.clients,
                    repository: widget.catalog,
                    showHeading: true,
                    selected: {if (_client != null) _client!.id},
                    onSelect: (e) => setState(() => _client = e),
                  ),
                  1 => CatalogPicker(
                    key: const ValueKey('services'),
                    kind: CatalogKind.services,
                    repository: widget.catalog,
                    showHeading: true,
                    selected: _services.map((e) => e.id).toSet(),
                    onSelect: (e) => setState(() {
                      if (_services.any((s) => s.id == e.id)) {
                        _services.removeWhere((s) => s.id == e.id);
                      } else if (_services.length < 10) {
                        _services.add(e);
                      }
                    }),
                  ),
                  2 => CatalogPicker(
                    key: const ValueKey('practitioner'),
                    kind: CatalogKind.practitioners,
                    repository: widget.catalog,
                    showHeading: true,
                    selected: {if (_practitioner != null) _practitioner!.id},
                    onSelect: (e) => setState(() => _practitioner = e),
                  ),
                  3 => ListView(
                    children: [
                      Text('Date & heure', style: ElmaType.display),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy || widget.websiteBooking != null
                            ? null
                            : _date,
                        child: Text(
                          _day == null
                              ? 'Choisir une date'
                              : DateFormat(
                                  'EEEE d MMMM yyyy',
                                  'fr',
                                ).format(_day!),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _busy || widget.websiteBooking != null
                            ? null
                            : _hour,
                        child: Text(
                          _time == null
                              ? 'Choisir une heure'
                              : _time!.format(context),
                        ),
                      ),
                      const Text(
                        'Heure de Casablanca. La disponibilité est vérifiée avant confirmation.',
                        style: TextStyle(fontSize: 12, color: ElmaColors.muted),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _notes,
                        maxLines: 3,
                        maxLength: 2000,
                        enabled: !_busy && widget.websiteBooking == null,
                        decoration: const InputDecoration(
                          labelText: 'Notes (facultatif)',
                        ),
                      ),
                    ],
                  ),
                  _ => ListView(
                    children: [
                      Text('Vérifiez le rendez-vous', style: ElmaType.display),
                      const SizedBox(height: 16),
                      if (widget.websiteBooking != null)
                        _summary('Source', 'Site web · Nouveau'),
                      _summary('Client', _client!.name),
                      _summary('Praticienne', _practitioner!.name),
                      _summary(
                        'Date & heure',
                        DateFormat(
                          'dd/MM/yyyy · HH:mm',
                        ).format(ClinicTime.local(_quote!.start)),
                      ),
                      for (final item in _quote!.services)
                        _summary(
                          item.name,
                          '${item.duration} min · ${_money(item.priceCentimes)}',
                        ),
                      _summary('Total', _money(_quote!.totalCentimes)),
                      const Text(
                        'La disponibilité et le tarif sont revérifiés à l’enregistrement.',
                        style: TextStyle(fontSize: 12, color: ElmaColors.muted),
                      ),
                    ],
                  ),
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: ElmaColors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElmaButton(
                    label: _step == 4
                        ? (widget.websiteBooking == null
                              ? 'Confirmer le rendez-vous'
                              : 'Importer · Nouveau')
                        : 'Continuer',
                    loading: _busy,
                    onPressed: _ready ? _next : null,
                  ),
                  if (_step > 0)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _step--;
                              _error = null;
                              _quote = null;
                              _requestId = null;
                            }),
                      child: const Text('Précédent'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  String _money(int cents) =>
      NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(cents / 100);
  Widget _summary(String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ElmaColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ElmaType.label),
        const SizedBox(height: 6),
        Text(value),
      ],
    ),
  );
}
