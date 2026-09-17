import 'package:flutter/material.dart';
import '../../domain/packs/packs.dart';
import '../../domain/catalog/catalog.dart';
import '../../domain/payments/payments.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'pack_photo_sheet.dart';

class PacksScreen extends StatefulWidget {
  const PacksScreen({
    super.key,
    required this.repository,
    required this.catalog,
    required this.isAdmin,
  });
  final PacksRepository repository;
  final CatalogRepository catalog;
  final bool isAdmin;
  @override
  State<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends State<PacksScreen> {
  final _packs = <ClinicPack>[];
  final _services = <CatalogEntry>[];
  bool _busy = true, _more = false;
  int _page = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!next) {
        final services = <CatalogEntry>[];
        var page = 1;
        while (true) {
          final r = await widget.catalog.list(
            CatalogKind.services,
            page: page++,
          );
          services.addAll(r.entries);
          if (!r.hasMore) break;
        }
        _services
          ..clear()
          ..addAll(services);
      }
      final page = next ? _page + 1 : 1;
      final r = await widget.repository.list(page: page);
      if (mounted) {
        setState(() {
          if (!next) _packs.clear();
          _packs.addAll(r.items);
          _page = page;
          _more = r.hasMore;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([ClinicPack? pack]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PackEditor(
          repository: widget.repository,
          services: _services,
          pack: pack,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ElmaHeader(
            'Packs',
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const ElmaIcon('ChevronLeft'),
            ),
            trailing: widget.isAdmin
                ? IconButton(
                    tooltip: 'Créer un pack',
                    onPressed: _busy ? null : () => _edit(),
                    icon: const ElmaIcon('Plus'),
                  )
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_busy) const Center(child: CircularProgressIndicator()),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Réessayer'),
                  ),
                ],
                for (final pack in _packs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ElmaColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pack.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              pack.imageUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) =>
                                  const Text('Image indisponible'),
                            ),
                          ),
                        Text(
                          pack.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(pack.price / 100).toStringAsFixed(2)} MAD · ${pack.totalSessions} séance(s) · ${pack.active ? 'Actif' : 'Inactif'}',
                        ),
                        if (pack.description.isNotEmpty) Text(pack.description),
                        for (final item in pack.items.entries)
                          Text(
                            '${_services.where((s) => s.id == item.key).firstOrNull?.name ?? 'Prestation archivée'} · ${item.value} séance(s)',
                          ),
                        if (widget.isAdmin)
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: _busy ? null : () => _edit(pack),
                                child: const Text('Modifier'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        await showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => PackPhotoSheet(
                                            entry: pack,
                                            repository: widget.repository,
                                          ),
                                        );
                                        if (mounted) await _load();
                                      },
                                child: const Text('Photo'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (!_busy && _error == null && _packs.isEmpty)
                  const Text('Aucun pack pour le moment.'),
                if (!_busy && _more)
                  TextButton(
                    onPressed: () => _load(next: true),
                    child: const Text('Charger la suite'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PackEditor extends StatefulWidget {
  const PackEditor({
    super.key,
    required this.repository,
    required this.services,
    this.pack,
  });
  final PacksRepository repository;
  final List<CatalogEntry> services;
  final ClinicPack? pack;
  @override
  State<PackEditor> createState() => _PackEditorState();
}

class _PackEditorState extends State<PackEditor> {
  String? _savedId;
  final _name = TextEditingController(),
      _description = TextEditingController(),
      _price = TextEditingController(),
      _sessionCount = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.pack;
    _name.text = p?.name ?? '';
    _description.text = p?.description ?? '';
    _price.text = p == null ? '' : (p.price / 100).toStringAsFixed(2);
    _sessionCount.text = '${p?.totalSessions ?? 1}';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _sessionCount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseMadCentimes(_price.text);
    final sessions = int.tryParse(_sessionCount.text.trim());
    if (_name.text.trim().isEmpty ||
        price == null ||
        price < 0 ||
        price > 100000000 ||
        sessions == null ||
        sessions < 1 ||
        sessions > 100) {
      setState(
        () => _error =
            'Renseignez le nom, le prix et un nombre de séances entre 1 et 100.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _savedId ??= await widget.repository.save(
        ClinicPack(
          id: widget.pack?.id,
          name: _name.text.trim(),
          description: _description.text,
          price: price,
          totalSessions: sessions,
          active: widget.pack?.active ?? true,
          version: widget.pack?.version ?? 0,
          items: const {},
        ),
      );
      if (mounted) Navigator.pop(context);
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
              widget.pack == null ? 'Nouveau pack' : 'Modifier le pack',
              leading: IconButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const ElmaIcon('ChevronLeft'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _name,
                    enabled: !_busy && _savedId == null,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Nom du pack'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    enabled: !_busy && _savedId == null,
                    maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sessionCount,
                    enabled: !_busy && _savedId == null,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de séances',
                      suffixText: 'séances',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _price,
                    enabled: !_busy && _savedId == null,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix du pack (MAD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: ElmaColors.red),
                    ),
                  ElmaButton(
                    label: 'Enregistrer',
                    loading: _busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
