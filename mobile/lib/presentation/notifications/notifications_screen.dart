import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/notifications/notifications.dart';
import '../appointments/clinic_time.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});
  final NotificationsRepository repository;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _items = <ClinicNotification>[];
  bool _busy = false, _more = false;
  String? _error, _saving;
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

  Future<void> _read(ClinicNotification item) async {
    setState(() => _saving = item.id);
    try {
      await widget.repository.markRead(item.id);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Notifications',
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
                                const ElmaIcon('Bell', size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.type == 'WEBSITE_BOOKING'
                                        ? 'Réservation du site importée'
                                        : 'Information de la clinique',
                                    style: TextStyle(
                                      fontWeight: item.readAt == null
                                          ? FontWeight.w700
                                          : FontWeight.w500,
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
                            if (item.readAt == null)
                              TextButton(
                                onPressed: _saving != null
                                    ? null
                                    : () => _read(item),
                                child: Text(
                                  _saving == item.id
                                      ? 'Enregistrement…'
                                      : 'Marquer comme lue',
                                ),
                              )
                            else
                              const Text(
                                'Lue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ElmaColors.green,
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
                      title: 'Aucune notification',
                      message:
                          'Les informations de votre journée apparaîtront ici.',
                      icon: 'Bell',
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
