import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/activity/activity.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.repository});
  final ActivityRepository repository;
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _items = <ActivityEntry>[];
  bool _busy = false, _more = false;
  String? _error;
  int _page = 0, _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (next && _busy) return;
    final generation = ++_generation, page = next ? _page + 1 : 1;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) _items.clear();
    });
    try {
      final result = await widget.repository.list(page: page);
      if (mounted && generation == _generation) {
        setState(() {
          _items.addAll(result.items);
          _page = page;
          _more = result.hasMore;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Journal d’activité',
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
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                                const ElmaIcon('Clock', size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    activityActionLabel(item.action),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat(
                                'd MMM yyyy · HH:mm',
                                'fr',
                              ).format(ClinicTime.local(item.createdAt)),
                              style: const TextStyle(
                                fontSize: 12,
                                color: ElmaColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activityEntityLabel(item.entityType),
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Auteur : ${item.actorName ?? (item.actorId == null ? 'Système' : 'Utilisateur indisponible')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ElmaColors.muted,
                              ),
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
                    const ElmaStatePanel(
                      title: 'Aucune activité',
                      message: 'Les actions enregistrées apparaîtront ici.',
                      icon: 'Clock',
                    ),
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

String activityActionLabel(String action) => switch (action) {
  'CREATE' => 'Création',
  'UPDATE' => 'Modification',
  'ARCHIVE' => 'Archivage',
  'AVAILABILITY_UPDATE' => 'Disponibilités modifiées',
  'RECORD_PAYMENT' => 'Paiement enregistré',
  'VOID' => 'Annulation',
  'RECEIVE' => 'Réservation du site reçue',
  'IMPORT' => 'Réservation du site importée',
  'DISMISS' => 'Réservation du site écartée',
  'RESCHEDULE' => 'Rendez-vous déplacé',
  'STATUS' => 'Statut du rendez-vous modifié',
  _ => 'Action enregistrée',
};
String activityEntityLabel(String entity) => switch (entity) {
  'clients' => 'Client',
  'practitioners' => 'Praticienne',
  'services' => 'Prestation',
  'service_categories' => 'Catégorie de prestations',
  'appointments' => 'Rendez-vous',
  'payments' => 'Paiement',
  'expenses' => 'Dépense',
  'inventory_transactions' => 'Mouvement de stock',
  'products' => 'Produit',
  'profiles' => 'Utilisateur',
  'settings' => 'Paramètres',
  'website_booking_events' => 'Réservation en ligne',
  _ => 'Activité de la clinique',
};
