import '../../domain/website/website_bookings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/packs/packs.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'catalog_picker.dart';
import 'clinic_time.dart';

class BookingWizard extends StatefulWidget {
  const BookingWizard({
    super.key,
    required this.repository,
    required this.catalog,
    this.packs,
    this.websiteBooking,
    this.websiteRepository,
  });
  final AppointmentsRepository repository;
  final CatalogRepository catalog;
  final PacksRepository? packs;
  final WebsiteBooking? websiteBooking;
  final WebsiteBookingsRepository? websiteRepository;
  @override
  State<BookingWizard> createState() => _BookingWizardState();
}

enum _BookingMode { prestations, packs }

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
  final List<CatalogEntry> _serviceEntries = [];
  final List<CatalogEntry> _categoryEntries = [];
  final List<ClinicPack> _packs = [];
  final List<ClinicPack> _selectedPacks = [];
  final List<CatalogEntry> _practitioners = [];
  PractitionerAvailability? _availability;
  final List<DateTime> _availabilityDates = [];
  DateTime? _selectedAvailabilityDate;
  bool _loadingPractitioners = false, _loadingAvailability = false;
  String? _selectedCategoryId;
  final _selectionSearch = TextEditingController();
  String _selectionSearchQuery = '';
  bool _loadingServices = false;
  _BookingMode _mode = _BookingMode.prestations;
  DateTime? _day;
  TimeOfDay? _time;
  final _notes = TextEditingController();
  BookingQuote? _quote;
  String? _error, _requestId;
  bool _busy = false, _loadingPacks = false;

  List<CatalogEntry> get _visibleServiceEntries {
    final query = _selectionSearchQuery.trim().toLowerCase();
    return _serviceEntries.where((entry) {
      final categoryMatches =
          _selectedCategoryId == null ||
          entry.categoryId == _selectedCategoryId;
      final text = [
        entry.name,
        entry.specialty,
        entry.categoryId,
        if (entry.categoryId != null) _categoryName(entry.categoryId!),
      ].whereType<String>().join(' ').toLowerCase();
      return categoryMatches && (query.isEmpty || text.contains(query));
    }).toList();
  }

  List<ClinicPack> get _visiblePacks {
    final query = _selectionSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _packs;
    return _packs.where((pack) {
      final text = '${pack.name} ${pack.description}'.toLowerCase();
      return text.contains(query);
    }).toList();
  }

  String? _categoryName(String id) {
    for (final category in _categoryEntries) {
      if (category.id == id) return category.name;
    }
    return null;
  }

  int get _bookingDurationMinutes {
    final prestationMinutes = _services.fold<int>(
      0,
      (total, service) => total + (service.durationMinutes ?? 30),
    );
    return prestationMinutes + (_selectedPacks.isNotEmpty ? 30 : 0);
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadCategories();
    _loadPractitioners();
    if (widget.packs != null) _loadPacks();
    final event = widget.websiteBooking;
    if (event != null) {
      final local = ClinicTime.local(event.start);
      _day = local;
      _time = TimeOfDay.fromDateTime(local);
      _notes.text = event.notes ?? '';
    }
  }

  Future<void> _loadPractitioners() async {
    setState(() => _loadingPractitioners = true);
    try {
      final page = await widget.catalog.list(
        CatalogKind.practitioners,
        page: 1,
      );
      if (!mounted) return;
      setState(
        () => _practitioners
          ..clear()
          ..addAll(page.entries.where((entry) => entry.active)),
      );
      if (_practitioner == null && _practitioners.isNotEmpty) {
        setState(() => _practitioner = _practitioners.first);
        _loadAvailabilityForPractitioner(_practitioners.first);
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingPractitioners = false);
    }
  }

  Future<void> _loadAvailabilityForPractitioner(
    CatalogEntry practitioner,
  ) async {
    setState(() {
      _loadingAvailability = true;
      _error = null;
    });
    try {
      final availability = await widget.catalog.availability(practitioner.id);
      if (!mounted) return;
      final dates = <DateTime>[];
      final now = DateTime.now();
      for (var offset = 0; offset < 90; offset++) {
        final date = DateTime(now.year, now.month, now.day + offset);
        if (_slotsForDay(
          date,
          availability,
          durationMinutes: _bookingDurationMinutes,
        ).isNotEmpty) {
          dates.add(date);
        }
      }
      setState(() {
        _availability = availability;
        _availabilityDates
          ..clear()
          ..addAll(dates);
        _selectedAvailabilityDate = dates.isNotEmpty ? dates.first : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingAvailability = false);
    }
  }

  List<TimeOfDay> _slotsForDay(
    DateTime date,
    PractitionerAvailability availability, {
    int durationMinutes = 30,
  }) {
    final utcDay = date;
    final shifts = availability.shifts.where(
      (shift) => shift.weekday == utcDay.weekday,
    );
    final slots = <TimeOfDay>[];
    for (final shift in shifts) {
      final startMinutes = _timeToMinutes(shift.start);
      final endMinutes = _timeToMinutes(shift.end);
      for (
        var minute = startMinutes;
        minute + durationMinutes <= endMinutes;
        minute += 30
      ) {
        final slotDate = DateTime(
          utcDay.year,
          utcDay.month,
          utcDay.day,
          minute ~/ 60,
          minute % 60,
        );
        final endDate = slotDate.add(Duration(minutes: durationMinutes));
        final blocked =
            availability.absences.any(
              (absence) =>
                  slotDate.isBefore(absence.end) &&
                  endDate.isAfter(absence.start),
            ) ||
            availability.busy.any(
              (booking) =>
                  slotDate.isBefore(booking.end) &&
                  endDate.isAfter(booking.start),
            );
        if (!blocked && !slotDate.isBefore(DateTime.now())) {
          slots.add(TimeOfDay(hour: slotDate.hour, minute: slotDate.minute));
        }
      }
    }
    final unique = <TimeOfDay>[];
    for (final slot in slots) {
      if (!unique.any(
        (item) => item.hour == slot.hour && item.minute == slot.minute,
      )) {
        unique.add(slot);
      }
    }
    unique.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return unique;
  }

  List<TimeOfDay> _allSlotsForDay(
    DateTime date,
    PractitionerAvailability availability, {
    int durationMinutes = 30,
  }) {
    final slots = <TimeOfDay>[];
    for (final shift in availability.shifts.where(
      (shift) => shift.weekday == date.weekday,
    )) {
      final startMinutes = _timeToMinutes(shift.start);
      final endMinutes = _timeToMinutes(shift.end);
      for (
        var minute = startMinutes;
        minute + durationMinutes <= endMinutes;
        minute += 30
      ) {
        slots.add(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));
      }
    }
    return slots;
  }

  int _timeToMinutes(String value) {
    final pieces = value.split(':');
    return int.parse(pieces[0]) * 60 + int.parse(pieces[1]);
  }

  DateTime? _firstSelectableDate() {
    final availability = _availability;
    if (availability == null) return null;
    final today = DateTime.now();
    for (var offset = 0; offset < 90; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      if (_slotsForDay(
        date,
        availability,
        durationMinutes: _bookingDurationMinutes,
      ).isNotEmpty) {
        return date;
      }
    }
    return null;
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final services = <CatalogEntry>[];
      var pageNumber = 1;
      while (true) {
        final page = await widget.catalog.list(
          CatalogKind.services,
          page: pageNumber++,
        );
        services.addAll(page.entries.where((entry) => entry.active));
        if (!page.hasMore) break;
      }
      if (!mounted) return;
      setState(
        () => _serviceEntries
          ..clear()
          ..addAll(services),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = <CatalogEntry>[];
      var pageNumber = 1;
      while (true) {
        final page = await widget.catalog.list(
          CatalogKind.categories,
          page: pageNumber++,
        );
        categories.addAll(page.entries.where((entry) => entry.active));
        if (!page.hasMore) break;
      }
      if (!mounted) return;
      setState(() {
        _categoryEntries
          ..clear()
          ..addAll(categories)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Widget _catalogImage(String? url, String fallback, {double size = 48}) {
    final image = url == null || url.isEmpty ? null : NetworkImage(url);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E8DE),
        borderRadius: BorderRadius.circular(size > 30 ? 12 : 10),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: image == null
          ? Text(
              fallback.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5E5D4B),
              ),
            )
          : null,
    );
  }

  Widget _packImage(ClinicPack pack) {
    final name = pack.name.toLowerCase();
    final icon = name.contains('laser')
        ? Icons.auto_awesome
        : name.contains('visage') || name.contains('facial')
        ? Icons.face_retouching_natural
        : name.contains('corps') || name.contains('massage')
        ? Icons.spa_outlined
        : Icons.card_giftcard_outlined;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E8DE),
        borderRadius: BorderRadius.circular(12),
        image: pack.imageUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(pack.imageUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: pack.imageUrl == null
          ? Icon(icon, color: const Color(0xFF828D19), size: 22)
          : null,
    );
  }

  Future<void> _loadPacks() async {
    if (widget.packs == null) return;
    setState(() => _loadingPacks = true);
    try {
      final page = await widget.packs!.list(page: 1);
      if (!mounted) return;
      setState(() {
        _packs
          ..clear()
          ..addAll(page.items.where((pack) => pack.active));
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingPacks = false);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _selectionSearch.dispose();
    super.dispose();
  }

  bool get _ready => switch (_step) {
    0 => _client != null,
    1 => _services.isNotEmpty || _selectedPacks.isNotEmpty,
    2 => _practitioner != null,
    3 => _day != null && _time != null,
    _ => _quote != null,
  };
  BookingSelection get _selection {
    final serviceIds = _services.map((service) => service.id).toList();
    return BookingSelection(
      _client!.id,
      _practitioner!.id,
      serviceIds.toSet().toList(),
      widget.websiteBooking?.start ?? ClinicTime.at(_day!, _time!),
      packIds: _selectedPacks
          .map((pack) => pack.id)
          .whereType<String>()
          .toList(),
    );
  }

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
              child: Container(
                color: const Color(0xFFFBFAF7),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: switch (_step) {
                    0 => CatalogPicker(
                      key: const ValueKey('client'),
                      kind: CatalogKind.clients,
                      repository: widget.catalog,
                      showHeading: true,
                      selected: {if (_client != null) _client!.id},
                      onSelect: (e) => setState(() => _client = e),
                    ),
                    1 => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _mode = _BookingMode.prestations;
                                  _selectedPacks.clear();
                                }),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _mode == _BookingMode.prestations
                                        ? const Color(0xFFE8E8DC)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _mode == _BookingMode.prestations
                                          ? const Color(0xFF828D19)
                                          : const Color(0xFFE2E0D9),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Prestations',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3B3A2F),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _mode = _BookingMode.packs;
                                  _services.clear();
                                }),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _mode == _BookingMode.packs
                                        ? const Color(0xFFE8E8DC)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _mode == _BookingMode.packs
                                          ? const Color(0xFF828D19)
                                          : const Color(0xFFE2E0D9),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Packs',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF3B3A2F),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _selectionSearch,
                          onChanged: (value) =>
                              setState(() => _selectionSearchQuery = value),
                          decoration: InputDecoration(
                            hintText: _mode == _BookingMode.prestations
                                ? 'Rechercher une prestation'
                                : 'Rechercher un pack',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _selectionSearchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Effacer la recherche',
                                    onPressed: () {
                                      _selectionSearch.clear();
                                      setState(
                                        () => _selectionSearchQuery = '',
                                      );
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE1DFD8),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE1DFD8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF828D19),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_mode == _BookingMode.prestations) ...[
                          const Text(
                            'Choisir la prestation',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sélectionnez le soin ou service',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7B766D),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 42,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categoryEntries.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final category = index == 0
                                    ? null
                                    : _categoryEntries[index - 1];
                                final selected =
                                    _selectedCategoryId == category?.id;
                                return GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedCategoryId = category?.id,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF828D19)
                                          : const Color(0xFFF5F2EA),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFE4E1D6),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (category != null) ...[
                                          _catalogImage(
                                            category.imageUrl,
                                            category.name,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 7),
                                        ],
                                        Text(
                                          category?.name ?? 'Toutes',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFF3A372F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_loadingServices)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView(
                                children: [
                                  if (_visibleServiceEntries.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Text(
                                        'Aucune prestation dans cette catégorie.',
                                        style: TextStyle(
                                          color: ElmaColors.muted,
                                        ),
                                      ),
                                    ),
                                  for (final entry in _visibleServiceEntries)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          if (_services.any(
                                            (service) => service.id == entry.id,
                                          )) {
                                            _services.removeWhere(
                                              (service) =>
                                                  service.id == entry.id,
                                            );
                                          } else {
                                            _selectedPacks.clear();
                                            _services.add(entry);
                                          }
                                        }),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            color:
                                                _services.any(
                                                  (service) =>
                                                      service.id == entry.id,
                                                )
                                                ? const Color(0xFFF5F2EA)
                                                : Colors.white,
                                            border: Border.all(
                                              color:
                                                  _services.any(
                                                    (service) =>
                                                        service.id == entry.id,
                                                  )
                                                  ? const Color(0xFFD3C9B8)
                                                  : const Color(0xFFE7E4DA),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      14,
                                                      12,
                                                      14,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      alignment:
                                                          Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE9E8DE,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: _catalogImage(
                                                        entry.imageUrl,
                                                        entry.name,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            entry.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                    0xFF1B1B1B,
                                                                  ),
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            _categoryName(
                                                                  entry.categoryId ??
                                                                      '',
                                                                ) ??
                                                                'Catégorie',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF7B766D,
                                                                  ),
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 5,
                                                          ),
                                                          Text(
                                                            '${entry.durationMinutes ?? 15} min · ${((entry.priceCentimes ?? 0) / 100).toStringAsFixed(0)} MAD',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                    0xFF777665,
                                                                  ),
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (_services.any(
                                                      (service) =>
                                                          service.id ==
                                                          entry.id,
                                                    ))
                                                      const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        child: Icon(
                                                          Icons.check_circle,
                                                          color: Color(
                                                            0xFF828D19,
                                                          ),
                                                          size: 22,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ] else ...[
                          const Text(
                            'Choisir le pack',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sélectionnez un ou plusieurs packs',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7B766D),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_loadingPacks)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (widget.packs == null || _packs.isEmpty)
                            const Text(
                              'Aucun pack disponible pour le moment.',
                              style: TextStyle(
                                fontSize: 13,
                                color: ElmaColors.muted,
                              ),
                            )
                          else
                            Expanded(
                              child: _visiblePacks.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Text(
                                        'Aucun pack ne correspond à votre recherche.',
                                        style: TextStyle(
                                          color: ElmaColors.muted,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _visiblePacks.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final pack = _visiblePacks[index];
                                        final selected = _selectedPacks.any(
                                          (item) => item.id == pack.id,
                                        );
                                        return GestureDetector(
                                          onTap: () => setState(() {
                                            if (selected) {
                                              _selectedPacks.removeWhere(
                                                (item) => item.id == pack.id,
                                              );
                                            } else {
                                              _services.clear();
                                              _selectedPacks.add(pack);
                                            }
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.fromLTRB(
                                              14,
                                              13,
                                              14,
                                              13,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? const Color(0xFFE8E8DC)
                                                  : Colors.white,
                                              border: Border.all(
                                                color: selected
                                                    ? const Color(0xFF828D19)
                                                    : const Color(0xFFE1DFD8),
                                                width: 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              children: [
                                                _packImage(pack),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        pack.name,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${(pack.price / 100).toStringAsFixed(2)} MAD',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(
                                                            0xFF7B766D,
                                                          ),
                                                        ),
                                                      ),
                                                      if (pack
                                                          .description
                                                          .isNotEmpty)
                                                        Text(
                                                          pack.description,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                  0xFF929184,
                                                                ),
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: selected
                                                          ? const Color(
                                                              0xFF828D19,
                                                            )
                                                          : const Color(
                                                              0xFFCAC5B6,
                                                            ),
                                                      width: 1.5,
                                                    ),
                                                    color: selected
                                                        ? const Color(
                                                            0xFF828D19,
                                                          )
                                                        : Colors.white,
                                                  ),
                                                  child: selected
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 16,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ],
                    ),
                    2 => ListView(
                      children: [
                        const Text(
                          'Choisir la praticienne',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Recherchez parmi les fiches existantes.',
                          style: TextStyle(
                            fontSize: 13,
                            color: ElmaColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_loadingPractitioners)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _practitioners.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final practitioner = _practitioners[index];
                              final selected =
                                  _practitioner?.id == practitioner.id;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _practitioner = practitioner);
                                  _loadAvailabilityForPractitioner(
                                    practitioner,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? ElmaColors.light
                                        : Colors.white,
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF828D19)
                                          : ElmaColors.border,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      _catalogImage(
                                        practitioner.imageUrl,
                                        practitioner.name,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          practitioner.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: const Color(0xFF828D19),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        if (_selectedCategoryId == '__legacy_availability__' &&
                            _practitioner != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Disponibilités de ${_practitioner!.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_loadingAvailability)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_availabilityDates.isEmpty)
                            const Text(
                              'Aucune disponibilité trouvée pour cette praticienne.',
                              style: TextStyle(color: ElmaColors.muted),
                            )
                          else ...[
                            SizedBox(
                              height: 42,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _availabilityDates.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final date = _availabilityDates[index];
                                  final selected =
                                      _selectedAvailabilityDate != null &&
                                      _selectedAvailabilityDate!.year ==
                                          date.year &&
                                      _selectedAvailabilityDate!.month ==
                                          date.month &&
                                      _selectedAvailabilityDate!.day ==
                                          date.day;
                                  return GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedAvailabilityDate = date,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF828D19)
                                            : const Color(0xFFF5F2EA),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFE4E1D6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        DateFormat('EEE d', 'fr').format(date),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFF3A372F),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedAvailabilityDate != null)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _slotsForDay(
                                      _selectedAvailabilityDate!,
                                      _availability!,
                                      durationMinutes: _bookingDurationMinutes,
                                    ).map((slot) {
                                      final selected =
                                          _day != null &&
                                          _time != null &&
                                          _day!.year ==
                                              _selectedAvailabilityDate!.year &&
                                          _day!.month ==
                                              _selectedAvailabilityDate!
                                                  .month &&
                                          _day!.day ==
                                              _selectedAvailabilityDate!.day &&
                                          _time!.hour == slot.hour &&
                                          _time!.minute == slot.minute;
                                      return ChoiceChip(
                                        selected: selected,
                                        label: Text(slot.format(context)),
                                        onSelected: (_) {
                                          setState(() {
                                            _day = _selectedAvailabilityDate!;
                                            _time = slot;
                                          });
                                        },
                                      );
                                    }).toList(),
                              )
                            else
                              const Text('Sélectionnez une date disponible.'),
                          ],
                        ],
                      ],
                    ),
                    3 => ListView(
                      children: [
                        Text('Date & heure', style: ElmaType.display),
                        const SizedBox(height: 16),
                        if (_practitioner == null || _availability == null)
                          const Text(
                            'Sélectionnez d’abord une praticienne.',
                            style: TextStyle(color: ElmaColors.muted),
                          )
                        else if (_firstSelectableDate() == null)
                          const Text(
                            'Aucune disponibilité n’est proposée pour cette praticienne.',
                            style: TextStyle(color: ElmaColors.muted),
                          )
                        else ...[
                          Builder(
                            builder: (context) {
                              final firstSelectable = _firstSelectableDate();
                              final selectedDate =
                                  _selectedAvailabilityDate != null &&
                                      _slotsForDay(
                                        _selectedAvailabilityDate!,
                                        _availability!,
                                        durationMinutes:
                                            _bookingDurationMinutes,
                                      ).isNotEmpty
                                  ? _selectedAvailabilityDate!
                                  : firstSelectable!;
                              return CalendarDatePicker(
                                initialDate: selectedDate,
                                firstDate: DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                ),
                                lastDate: DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day + 89,
                                ),
                                selectableDayPredicate: (date) => _slotsForDay(
                                  date,
                                  _availability!,
                                  durationMinutes: _bookingDurationMinutes,
                                ).isNotEmpty,
                                onDateChanged: (date) => setState(() {
                                  _day = date;
                                  _selectedAvailabilityDate = date;
                                  _time = null;
                                }),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_day != null)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children:
                                  _allSlotsForDay(
                                    _day!,
                                    _availability!,
                                    durationMinutes: _bookingDurationMinutes,
                                  ).map((slot) {
                                    final available =
                                        _slotsForDay(
                                          _day!,
                                          _availability!,
                                          durationMinutes:
                                              _bookingDurationMinutes,
                                        ).any(
                                          (item) =>
                                              item.hour == slot.hour &&
                                              item.minute == slot.minute,
                                        );
                                    final selected =
                                        _time != null &&
                                        _time!.hour == slot.hour &&
                                        _time!.minute == slot.minute;
                                    return ChoiceChip(
                                      selected: selected,
                                      disabledColor: const Color(0xFFE4E1E6),
                                      labelStyle: TextStyle(
                                        color: available
                                            ? null
                                            : const Color(0xFF9B969F),
                                      ),
                                      label: Text(slot.format(context)),
                                      onSelected: available
                                          ? (_) => setState(() => _time = slot)
                                          : null,
                                    );
                                  }).toList(),
                            )
                          else
                            const Text(
                              'Sélectionnez une date.',
                              style: TextStyle(color: ElmaColors.muted),
                            ),
                        ],
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
                        Text(
                          'Vérifiez le rendez-vous',
                          style: ElmaType.display,
                        ),
                        const SizedBox(height: 16),
                        if (widget.websiteBooking != null)
                          _summary('Source', 'Site web · Nouveau'),
                        _summary('Client', _client!.name),
                        _summary('Praticienne', _practitioner!.name),
                        if (_services.isNotEmpty)
                          _summary(
                            'Prestations',
                            _services
                                .map((service) => service.name)
                                .join(' · '),
                          ),
                        if (_selectedPacks.isNotEmpty)
                          _summary(
                            'Packs',
                            _selectedPacks.map((pack) => pack.name).join(' · '),
                          ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: ElmaColors.muted,
                          ),
                        ),
                      ],
                    ),
                  },
                ),
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
