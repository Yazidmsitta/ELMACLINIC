import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../catalog/entry_sheet.dart';

class CatalogPicker extends StatefulWidget {
  const CatalogPicker({
    super.key,
    required this.kind,
    required this.repository,
    required this.selected,
    required this.onSelect,
    this.showHeading = false,
  });
  final CatalogKind kind;
  final CatalogRepository repository;
  final Set<String> selected;
  final ValueChanged<CatalogEntry> onSelect;
  final bool showHeading;
  @override
  State<CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<CatalogPicker> {
  final _search = TextEditingController();
  Timer? _timer;
  List<CatalogEntry> _entries = [], _categories = [];
  bool _loading = true, _more = false;
  int _page = 1, _generation = 0;
  String? _error, _category, _root;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) _entries = [];
    });
    try {
      final page = more ? _page + 1 : 1;
      final result = await widget.repository.list(
        widget.kind,
        page: page,
        search: _search.text,
        categoryId: _category,
      );
      List<CatalogEntry>? categories;
      if (widget.kind == CatalogKind.services && !more) {
        categories = [];
        var number = 1;
        while (true) {
          final part = await widget.repository.list(
            CatalogKind.categories,
            page: number++,
          );
          categories.addAll(part.entries.where((c) => c.active));
          if (!part.hasMore) break;
        }
      }
      if (mounted && generation == _generation) {
        setState(() {
          _entries = [
            if (more) ..._entries,
            ...result.entries.where((e) => e.active),
          ];
          _page = page;
          _more = result.hasMore;
          if (categories != null) {
            _categories = categories
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          }
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

  Future<void> _addClient() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => EntrySheet(
        kind: CatalogKind.clients,
        repository: widget.repository,
        categories: const [],
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      if (widget.showHeading) ...[
        Text(switch (widget.kind) {
          CatalogKind.clients => 'Sélectionner un client',
          CatalogKind.services => 'Choisir les prestations',
          _ => 'Choisir la praticienne',
        }, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          widget.kind == CatalogKind.services
              ? 'Sélectionnez jusqu’à 10 soins ou services.'
              : 'Recherchez parmi les fiches existantes.',
          style: const TextStyle(fontSize: 13, color: ElmaColors.muted),
        ),
        const SizedBox(height: 16),
      ],
      if (widget.kind == CatalogKind.clients)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OutlinedButton.icon(
            onPressed: _addClient,
            icon: const ElmaIcon('Plus'),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Nouveau client'),
            ),
          ),
        ),
      TextField(
        controller: _search,
        decoration: const InputDecoration(
          hintText: 'Rechercher',
          prefixIcon: Padding(
            padding: EdgeInsets.all(14),
            child: ElmaIcon('Search', size: 18),
          ),
        ),
        onChanged: (_) {
          _timer?.cancel();
          ++_generation;
          _timer = Timer(const Duration(milliseconds: 350), _load);
        },
      ),
      if (_categories.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElmaFilterChip(
                label: const Text('Toutes'),
                selected: _root == null,
                onSelected: (_) {
                  setState(() {
                    _root = null;
                    _category = null;
                  });
                  _load();
                },
              ),
              ..._categories
                  .where((c) => c.parentId == null)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ElmaFilterChip(
                        label: Text(c.name),
                        selected: _root == c.id,
                        onSelected: (_) {
                          setState(() {
                            _root = c.id;
                            _category = c.id;
                          });
                          _load();
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
      if (_root != null && _categories.any((c) => c.parentId == _root))
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElmaFilterChip(
                label: const Text('Toutes'),
                selected: _category == _root,
                onSelected: (_) {
                  setState(() => _category = _root);
                  _load();
                },
              ),
              ..._categories
                  .where((c) => c.parentId == _root)
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ElmaFilterChip(
                        label: Text(c.name),
                        selected: _category == c.id,
                        onSelected: (_) {
                          setState(() => _category = c.id);
                          _load();
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      ...[
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          ElmaStatePanel(
            title: 'Chargement impossible',
            message: _error!,
            onRetry: _load,
          ),
        if (!_loading && _error == null && _entries.isEmpty)
          const ElmaStatePanel(
            title: 'Aucun résultat',
            message: 'Aucune fiche active correspondante.',
          ),
        for (final entry in _entries)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: widget.selected.contains(entry.id)
                  ? ElmaColors.light
                  : Colors.white,
              border: Border.all(
                color: widget.selected.contains(entry.id)
                    ? ElmaColors.brand
                    : ElmaColors.border,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ElmaColors.light,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.kind == CatalogKind.services
                      ? const ElmaIcon('Tag')
                      : Text(
                          entry.name
                              .split(RegExp(r'\s+'))
                              .where((s) => s.isNotEmpty)
                              .take(2)
                              .map((s) => s.characters.first)
                              .join()
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ElmaColors.secondary,
                          ),
                        ),
                ),
                title: Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  widget.kind == CatalogKind.services
                      ? '${entry.durationMinutes} min'
                      : (widget.kind == CatalogKind.clients
                                ? entry.phone
                                : entry.specialty) ??
                            '',
                  style: const TextStyle(fontSize: 12, color: ElmaColors.muted),
                ),
                trailing: widget.selected.contains(entry.id)
                    ? const ElmaIcon('Check')
                    : null,
                onTap: () => widget.onSelect(entry),
              ),
            ),
          ),
        if (_more)
          TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Afficher plus'),
          ),
      ],
    ],
  );
}
