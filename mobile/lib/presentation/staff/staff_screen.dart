import 'package:flutter/material.dart';
import '../../domain/app_failure.dart';
import '../../domain/staff/staff.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../shell/more_screen.dart' show initials;

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key, required this.repository});
  final StaffRepository repository;
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _items = <StaffMember>[];
  bool _busy = false, _more = false;
  int _page = 0, _generation = 0;
  String? _error;
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

  Future<void> _edit(StaffMember member) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => StaffSheet(repository: widget.repository, member: member),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Utilisateurs',
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
                  for (final member in _items)
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
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: member.role == 'ADMIN'
                                        ? ElmaColors.brand
                                        : ElmaColors.light,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    initials(member.name),
                                    style: TextStyle(
                                      color: member.role == 'ADMIN'
                                          ? Colors.white
                                          : ElmaColors.secondary,
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
                                        member.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        member.role == 'ADMIN'
                                            ? 'Admin'
                                            : 'Utilisateur',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: ElmaColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    member.active
                                        ? 'Compte actif'
                                        : 'Compte inactif',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ElmaColors.secondary,
                                    ),
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _edit(member),
                                  child: const Text('Modifier'),
                                ),
                              ],
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
                  if (!_busy && _error == null && _more)
                    TextButton(
                      onPressed: () => _load(next: true),
                      child: const Text('Charger la suite'),
                    ),
                  const Text(
                    'Les comptes désactivés ne peuvent plus se connecter. L’historique de leurs actions est conservé.',
                    style: TextStyle(fontSize: 12, color: ElmaColors.muted),
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

class StaffSheet extends StatefulWidget {
  const StaffSheet({super.key, required this.repository, required this.member});
  final StaffRepository repository;
  final StaffMember member;
  @override
  State<StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<StaffSheet> {
  late final TextEditingController _name;
  late String _role;
  late bool _active;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member.name);
    _role = widget.member.role;
    _active = widget.member.active;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.update(
        widget.member,
        _name.text.trim(),
        _role,
        _active,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Modifier le compte',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const ElmaIcon('X'),
                  ),
                ],
              ),
              TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Nom complet'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final role in ['USER', 'ADMIN'])
                    ChoiceChip(
                      label: Text(role == 'ADMIN' ? 'Admin' : 'Utilisateur'),
                      selected: _role == role,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _role = role),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte actif'),
                value: _active,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _active = value),
              ),
              const Text(
                'Un changement d’accès ferme les sessions existantes.',
                style: TextStyle(fontSize: 12, color: ElmaColors.muted),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ElmaColors.red),
                  ),
                ),
              const SizedBox(height: 20),
              ElmaButton(
                label: 'Enregistrer',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
