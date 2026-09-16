import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/app_failure.dart';
import '../../domain/catalog/catalog.dart';
import '../appointments/appointment_detail.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({
    super.key,
    required this.entry,
    required this.repository,
    this.appointments,
    required this.isAdmin,
  });
  final CatalogEntry entry;
  final CatalogRepository repository;
  final AppointmentsRepository? appointments;
  final bool isAdmin;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  ClientProfile? _profile;
  String? _error;
  String? _adjustingPack;
  bool _loading = true;
  int _generation = 0;

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
      final profile = await widget.repository.clientProfile(widget.entry.id);
      if (!mounted || generation != _generation) return;
      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _adjustPackSessions(ClientPackSummary pack, int delta) async {
    if (_adjustingPack != null) return;
    if (delta < 0 && pack.completedSessions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune séance à supprimer.')),
      );
      return;
    }
    setState(() {
      _adjustingPack = pack.packId;
      _error = null;
    });
    try {
      await widget.repository.adjustClientPackSessions(
        widget.entry.id,
        pack.packId,
        delta,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(delta > 0 ? 'Séance marquée faite.' : 'Séance supprimée.'),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _adjustingPack = null);
    }
  }

  Future<void> _openAppointment(String id) async {
    if (widget.appointments == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppointmentDetail(
          id: id,
          repository: widget.appointments!,
          catalog: widget.repository,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
    if (mounted) await _load();
  }

  String _statusLabel(String? code) => switch (code) {
    'NEW' => 'Nouveau',
    'PENDING' => 'En attente',
    'CONFIRMED' => 'Confirmé',
    'IN_PROGRESS' => 'En cours',
    'COMPLETED' => 'Terminé',
    'CANCELLED' => 'Annulé',
    'NO_SHOW' => 'Absent',
    _ => code ?? '—',
  };

  Color _statusColor(String? code) => switch (code) {
    'COMPLETED' => ElmaColors.green,
    'CONFIRMED' || 'IN_PROGRESS' => ElmaColors.brand,
    'CANCELLED' || 'NO_SHOW' => ElmaColors.red,
    _ => ElmaColors.muted,
  };

  Widget _section(String title, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ElmaColors.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: ElmaType.label),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _empty(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, color: ElmaColors.muted),
  );

  Widget _appointmentTile(Map<String, dynamic> row) {
    final startsAt = ClinicTime.local(DateTime.parse(row['starts_at'] as String));
    final practitioner = row['practitioner_name'] as String?;
    final services = ((row['services'] as List?) ?? const [])
        .map((dynamic item) => (item as Map<String, dynamic>)['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .join(' · ');
    final status = row['status'] as String?;
    final source = row['source'] as String?;
    final appointmentId = row['id'] as String?;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: appointmentId == null || widget.appointments == null
          ? null
          : () => _openAppointment(appointmentId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ElmaColors.light,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE d MMM yyyy · HH:mm', 'fr').format(startsAt),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (practitioner != null && practitioner.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(practitioner, style: const TextStyle(fontSize: 13)),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(services, style: const TextStyle(fontSize: 12, color: ElmaColors.muted)),
            ],
            if (source != null) ...[
              const SizedBox(height: 4),
              Text(source == 'WEBSITE' ? 'Réservation site web' : 'Créé dans ElmaClinic', style: const TextStyle(fontSize: 11, color: ElmaColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _packTile(ClientPackSummary pack) {
    final done = pack.completed;
    final progress = pack.totalSessions <= 0 ? 0.0 : pack.completedSessions / pack.totalSessions;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ElmaColors.light,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: done ? ElmaColors.greenLight : ElmaColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  done ? 'Complet' : 'En attente',
                  style: TextStyle(
                    fontSize: 11,
                    color: done ? ElmaColors.green : ElmaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white,
            color: done ? ElmaColors.green : ElmaColors.brand,
          ),
          const SizedBox(height: 8),
          Text(
            '${pack.completedSessions}/${pack.totalSessions} séance(s) terminée(s) · ${pack.remainingSessions} restante(s)',
            style: const TextStyle(fontSize: 12, color: ElmaColors.muted),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoutez une séance faite sans rendez-vous, ou supprimez une séance ajoutée par erreur.',
            style: TextStyle(fontSize: 11, color: ElmaColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _adjustingPack == null &&
<<<<<<< HEAD
                          pack.totalSessions > pack.completedSessions
=======
                          pack.completedSessions > 0
>>>>>>> 6379105 (Allow manual client pack session adjustments)
                      ? () => _adjustPackSessions(pack, -1)
                      : null,
                  icon: _adjustingPack == pack.packId
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.remove, size: 16),
<<<<<<< HEAD
                  label: const Text('Retirer'),
=======
                  label: const Text('Supprimer'),
>>>>>>> 6379105 (Allow manual client pack session adjustments)
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _adjustingPack == null
                      ? () => _adjustPackSessions(pack, 1)
                      : null,
                  icon: const Icon(Icons.add, size: 16),
<<<<<<< HEAD
                  label: const Text('Ajouter'),
=======
                  label: const Text('Ajouter faite'),
>>>>>>> 6379105 (Allow manual client pack session adjustments)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final client = profile?.client ?? widget.entry;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ElmaHeader(
              client.name,
              subtitle: 'Fiche client',
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.maybePop(context),
                icon: const ElmaIcon('ChevronLeft', size: 18),
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
                        onRetry: _load,
                      ),
                    _section(
                      'Informations',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          if (client.phone != null && client.phone!.isNotEmpty) SelectableText(client.phone!),
                          if (client.email != null && client.email!.isNotEmpty) SelectableText(client.email!),
                          if (client.birthDate != null && client.birthDate!.isNotEmpty) Text('Naissance : ${client.birthDate}'),
                        ],
                      ),
                    ),
                    if (profile != null) ...[
                      _section(
                        'Rendez-vous aujourd’hui',
                        profile.today.isEmpty
                            ? _empty('Aucun rendez-vous prévu aujourd’hui.')
                            : Column(children: profile.today.map(_appointmentTile).toList()),
                      ),
                      _section(
                        'Packs',
                        profile.packs.isEmpty
                            ? _empty('Aucun pack consommé pour ce client.')
                            : Column(children: profile.packs.map(_packTile).toList()),
                      ),
                      _section(
                        'Historique',
                        profile.history.isEmpty
                            ? _empty('Aucun historique pour ce client.')
                            : Column(children: profile.history.map(_appointmentTile).toList()),
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
