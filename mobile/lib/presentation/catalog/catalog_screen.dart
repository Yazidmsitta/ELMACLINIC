import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/catalog/catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'entry_sheet.dart';
import 'availability_sheet.dart';
import 'photo_sheet.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.kind,
    required this.repository,
    required this.isAdmin,
    this.standalone = false,
  });
  final CatalogKind kind;
  final CatalogRepository repository;
  final bool isAdmin, standalone;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<CatalogEntry> _entries = [], _categories = [];
  String? _error, _categoryId, _rootCategoryId;
  bool _loading = true, _more = false, _mutating = false, _failedMore = false;
  int _page = 1, _total = 0, _generation = 0;
  bool get _canEdit => widget.isAdmin || widget.kind == CatalogKind.clients;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
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
        widget.kind,
        page: page,
        search: _search.text,
        categoryId: _categoryId,
      );
      List<CatalogEntry>? categories;
      if ((widget.kind == CatalogKind.services ||
              widget.kind == CatalogKind.categories) &&
          !more) {
        categories = [];
        var categoryPage = 1;
        while (true) {
          final part = await widget.repository.list(
            CatalogKind.categories,
            page: categoryPage++,
          );
          categories.addAll(part.entries);
          if (!part.hasMore) break;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = more ? [..._entries, ...result.entries] : result.entries;
        _total = result.total;
        _page = page;
        _more = result.hasMore;
        if (categories != null) {
          _categories = categories
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit([CatalogEntry? entry]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EntrySheet(
        kind: widget.kind,
        repository: widget.repository,
        entry: entry,
        categories: _categories,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() => _mutating = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _archive(CatalogEntry entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver cette fiche ?'),
        content: Text(
          '${entry.name}\nL’historique des rendez-vous sera conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _mutate(() => widget.repository.archive(widget.kind, entry.id));
    }
  }

  Future<void> _photo(CatalogEntry entry) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PhotoSheet(entry: entry, repository: widget.repository),
    );
    if (saved == true && mounted) await _load();
  }

  void _availability(CatalogEntry entry) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => AvailabilitySheet(
        entry: entry,
        repository: widget.repository,
        isAdmin: widget.isAdmin,
      ),
    );
  }

  Widget _card(CatalogEntry entry) {
    final service = widget.kind == CatalogKind.services;
    final subtitle = widget.kind == CatalogKind.clients
        ? entry.phone
        : widget.kind == CatalogKind.practitioners
        ? entry.specialty
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ElmaColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (service && entry.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                entry.imageUrl!,
                width: double.infinity,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 96,
                  child: Center(child: Text('Photo indisponible')),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (!service) ...[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ElmaColors.light,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      entry.name
                          .trim()
                          .split(RegExp(r'\s+'))
                          .take(2)
                          .map((s) => s.characters.first)
                          .join()
                          .toUpperCase(),
                      style: const TextStyle(
                        color: ElmaColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ElmaColors.muted,
                          ),
                        ),
                      if (service) ...[
                        if (_categories.any((c) => c.id == entry.categoryId))
                          Text(
                            _categories
                                .firstWhere((c) => c.id == entry.categoryId)
                                .name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ElmaColors.muted,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.isAdmin ? '${NumberFormat.currency(locale: 'fr', symbol: 'MAD').format(entry.priceCentimes! / 100)} · ' : ''}${entry.durationMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ElmaColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (widget.kind != CatalogKind.clients)
                        Text(
                          entry.active ? 'Actif' : 'Inactif',
                          style: TextStyle(
                            fontSize: 11,
                            color: entry.active
                                ? ElmaColors.green
                                : ElmaColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_canEdit)
                  IconButton(
                    tooltip: 'Modifier ${entry.name}',
                    onPressed: _mutating ? null : () => _edit(entry),
                    icon: const ElmaIcon('Edit', size: 16),
                  ),
              ],
            ),
          ),
          if (widget.kind == CatalogKind.practitioners)
            TextButton(
              onPressed: () => _availability(entry),
              child: const Text('Voir les disponibilités'),
            ),
          if (service && widget.isAdmin)
            TextButton(
              onPressed: _mutating ? null : () => _photo(entry),
              child: const Text('Photo de la prestation'),
            ),
          if (widget.isAdmin) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (widget.kind != CatalogKind.clients) ...[
                    Switch(
                      value: entry.active,
                      onChanged: _mutating
                          ? null
                          : (value) => _mutate(
                              () => widget.repository.setActive(
                                widget.kind,
                                entry.id,
                                value,
                              ),
                            ),
                    ),
                    const Text('Actif', style: TextStyle(fontSize: 12)),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: _mutating ? null : () => _archive(entry),
                    child: const Text(
                      'Archiver',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElmaHeader(
          widget.kind.label,
          leading: widget.standalone
              ? IconButton(
                  tooltip: 'Retour',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const ElmaIcon('ChevronLeft', size: 18),
                )
              : null,
          trailing: _canEdit
              ? ElmaCompactButton(
                  label: 'Ajouter',
                  onPressed: _loading || _mutating ? null : () => _edit(),
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Rechercher',
              prefixIcon: Padding(
                padding: EdgeInsets.all(14),
                child: ElmaIcon('Search', size: 18),
              ),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              ++_generation;
              _debounce = Timer(
                const Duration(milliseconds: 350),
                () => _load(),
              );
            },
          ),
        ),
        if (widget.kind == CatalogKind.services)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElmaFilterChip(
                    label: const Text('Toutes'),
                    selected: _categoryId == null,
                    onSelected: (_) {
                      setState(() {
                        _categoryId = null;
                        _rootCategoryId = null;
                      });
                      _load();
                    },
                  ),
                ),
                ..._categories
                    .where((c) => c.parentId == null)
                    .map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElmaFilterChip(
                          label: Text(category.name),
                          selected: _rootCategoryId == category.id,
                          onSelected: (_) {
                            setState(() {
                              _categoryId = category.id;
                              _rootCategoryId = category.id;
                            });
                            _load();
                          },
                        ),
                      ),
                    ),
                if (widget.isAdmin)
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => CatalogScreen(
                            kind: CatalogKind.categories,
                            repository: widget.repository,
                            isAdmin: true,
                            standalone: true,
                          ),
                        ),
                      );
                      if (mounted) _load();
                    },
                    child: const Text('Gérer'),
                  ),
              ],
            ),
          ),
        if (widget.kind == CatalogKind.services &&
            _rootCategoryId != null &&
            _categories.any((c) => c.parentId == _rootCategoryId))
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ElmaFilterChip(
                  label: const Text('Toutes'),
                  selected: _categoryId == _rootCategoryId,
                  onSelected: (_) {
                    setState(() => _categoryId = _rootCategoryId);
                    _load();
                  },
                ),
                ..._categories
                    .where((c) => c.parentId == _rootCategoryId)
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ElmaFilterChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) {
                            setState(() => _categoryId = c.id);
                            _load();
                          },
                        ),
                      ),
                    ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!_canEdit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Consultation uniquement',
                      style: TextStyle(fontSize: 12, color: ElmaColors.muted),
                    ),
                  ),
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
                      '$_total résultat${_total > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ElmaColors.muted,
                      ),
                    ),
                  ),
                if (_entries.isEmpty && !_loading && _error == null)
                  const ElmaStatePanel(
                    title: 'Aucun résultat',
                    message: 'Les fiches enregistrées apparaîtront ici.',
                    icon: 'Users',
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
    return widget.standalone ? Scaffold(body: SafeArea(child: body)) : body;
  }
}
