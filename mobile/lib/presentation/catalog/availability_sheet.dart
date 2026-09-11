import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../../domain/app_failure.dart';
import '../../domain/catalog/catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class AvailabilitySheet extends StatefulWidget {
  const AvailabilitySheet({
    super.key,
    required this.entry,
    required this.repository,
    required this.isAdmin,
  });
  final CatalogEntry entry;
  final CatalogRepository repository;
  final bool isAdmin;
  @override
  State<AvailabilitySheet> createState() => _AvailabilitySheetState();
}

class _AvailabilitySheetState extends State<AvailabilitySheet> {
  List<WeeklyShift> _shifts = [];
  List<TimeOff> _absences = [];
  bool _loading = true, _saving = false, _loaded = false;
  String? _error;
  late final tz.Location _clinic;
  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];
  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _clinic = tz.getLocation('Africa/Casablanca');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final availability = await widget.repository.availability(
        widget.entry.id,
      );
      if (mounted) {
        setState(() {
          _loaded = true;
          _shifts = [...availability.shifts];
          _absences = [...availability.absences];
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _time(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  Future<void> _addShift() async {
    final day = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Jour de la semaine'),
        children: [
          for (var i = 0; i < 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i + 1),
              child: Text(_days[i]),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    final start = await showTimePicker(
      context: context,
      helpText: 'Début du créneau',
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'Fin du créneau',
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (end == null || !mounted) return;
    if (_time(end).compareTo(_time(start)) <= 0) {
      setState(() => _error = 'La fin doit suivre le début.');
      return;
    }
    setState(() {
      _error = null;
      _shifts.add(WeeklyShift(day, _time(start), _time(end)));
    });
  }

  Future<DateTime?> _dateTime(String label) async {
    final now = tz.TZDateTime.now(_clinic);
    final date = await showDatePicker(
      context: context,
      helpText: label,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      helpText: '$label · heure de Casablanca',
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return null;
    final result = tz.TZDateTime(
      _clinic,
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (result.hour != time.hour || result.minute != time.minute) {
      throw const AppFailure('Cette heure n’existe pas à Casablanca.');
    }
    return result;
  }

  Future<void> _addAbsence() async {
    try {
      final start = await _dateTime('Début de l’absence');
      if (start == null || !mounted) return;
      final end = await _dateTime('Fin de l’absence');
      if (end == null || !mounted) return;
      if (!end.isAfter(start)) {
        throw const AppFailure('La fin doit suivre le début.');
      }
      setState(() {
        _error = null;
        _absences.add(TimeOff(start, end));
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveAvailability(
        widget.entry.id,
        PractitionerAvailability(_shifts, _absences),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.entry.name,
              style: ElmaType.display.copyWith(fontSize: 20),
            ),
            const Text(
              'Disponibilités · heure de Casablanca',
              style: TextStyle(fontSize: 12, color: ElmaColors.muted),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (!_loaded)
              ElmaStatePanel(
                title: 'Chargement impossible',
                message: _error ?? 'Réessayez.',
                onRetry: _load,
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ElmaColors.red),
                  ),
                ),
              if (_error != null && _shifts.isEmpty && _absences.isEmpty)
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              const Text(
                'Horaires hebdomadaires',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_shifts.isEmpty) const Text('Aucun créneau configuré.'),
              for (var i = 0; i < _shifts.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_days[_shifts[i].weekday - 1]),
                  subtitle: Text('${_shifts[i].start} – ${_shifts[i].end}'),
                  trailing: widget.isAdmin
                      ? IconButton(
                          tooltip: 'Supprimer le créneau',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _shifts.removeAt(i)),
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              if (widget.isAdmin)
                TextButton(
                  onPressed: _saving || _shifts.length >= 28 ? null : _addShift,
                  child: const Text('Ajouter un créneau'),
                ),
              const SizedBox(height: 16),
              const Text(
                'Absences',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_absences.isEmpty) const Text('Aucune absence configurée.'),
              for (var i = 0; i < _absences.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(tz.TZDateTime.from(_absences[i].start, _clinic)),
                  ),
                  subtitle: Text(
                    'au ${DateFormat('dd/MM/yyyy HH:mm').format(tz.TZDateTime.from(_absences[i].end, _clinic))}',
                  ),
                  trailing: widget.isAdmin
                      ? IconButton(
                          tooltip: 'Supprimer l’absence',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _absences.removeAt(i)),
                          icon: const Icon(Icons.close),
                        )
                      : null,
                ),
              if (widget.isAdmin) ...[
                TextButton(
                  onPressed: _saving || _absences.length >= 100
                      ? null
                      : _addAbsence,
                  child: const Text('Ajouter une absence'),
                ),
                ElmaButton(
                  label: 'Enregistrer',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
