import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/app_failure.dart';
import '../../domain/catalog/catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.kind,
    required this.repository,
    required this.categories,
    this.entry,
  });
  final CatalogKind kind;
  final CatalogRepository repository;
  final List<CatalogEntry> categories;
  final CatalogEntry? entry;
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool _saving = false, _active = true;
  String? _error, _category, _parent;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    for (final field in <String, String?>{
      'order': (e?.sortOrder ?? 0).toString(),
      'name': e?.name,
      'phone': e?.phone,
      'email': e?.email,
      'birth': e?.birthDate == null
          ? null
          : DateFormat('dd/MM/yyyy').format(DateTime.parse(e!.birthDate!)),
      'specialty': e?.specialty,
      'job': e?.jobTitle,
      'description': e?.description,
      'duration': e?.durationMinutes?.toString(),
      'price': e?.priceCentimes == null
          ? null
          : (e!.priceCentimes! / 100).toStringAsFixed(2),
    }.entries) {
      _fields[field.key] = TextEditingController(text: field.value ?? '');
    }
    _active = e?.active ?? true;
    _category = e?.categoryId;
    _parent = e?.parentId;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? _value(String key) {
    final text = _fields[key]!.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _price() {
    final text = _value('price')?.replaceAll(',', '.');
    if (text == null || !RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) {
      return null;
    }
    final parts = text.split('.');
    return int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final birth = _value('birth');
      await widget.repository.save(
        widget.kind,
        CatalogEntry(
          id: widget.entry?.id ?? '',
          name: _value('name')!,
          phone: _value('phone'),
          email: _value('email'),
          birthDate: birth == null
              ? null
              : DateFormat(
                  'yyyy-MM-dd',
                ).format(DateFormat('dd/MM/yyyy').parseStrict(birth)),
          specialty: _value('specialty'),
          jobTitle: _value('job'),
          description: _value('description'),
          durationMinutes: int.tryParse(_value('duration') ?? ''),
          priceCentimes: _price(),
          categoryId: _category,
          active: _active,
          parentId: _parent,
          sortOrder: int.tryParse(_value('order') ?? '') ?? 0,
        ),
        creating: widget.entry == null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    TextInputType? keyboard,
    int max = 200,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_saving,
      keyboardType: keyboard,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: validate,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: ElmaColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.entry == null ? 'Ajouter' : 'Modifier'} · ${widget.kind.label}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field(
                    'name',
                    widget.kind == CatalogKind.clients ||
                            widget.kind == CatalogKind.practitioners
                        ? 'Nom complet *'
                        : 'Nom *',
                    validate: (value) => value == null || value.trim().isEmpty
                        ? 'Saisissez un nom.'
                        : null,
                  ),
                  if (widget.kind == CatalogKind.clients ||
                      widget.kind == CatalogKind.practitioners) ...[
                    _field(
                      'phone',
                      'Téléphone',
                      keyboard: TextInputType.phone,
                      max: 40,
                    ),
                    _field(
                      'email',
                      'Email',
                      keyboard: TextInputType.emailAddress,
                      max: 254,
                      validate: (value) =>
                          value != null &&
                              value.trim().isNotEmpty &&
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? 'Adresse email invalide.'
                          : null,
                    ),
                  ],
                  if (widget.kind == CatalogKind.clients)
                    _field(
                      'birth',
                      'Date de naissance (JJ/MM/AAAA)',
                      keyboard: TextInputType.datetime,
                      max: 10,
                      validate: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        try {
                          final date = DateFormat(
                            'dd/MM/yyyy',
                          ).parseStrict(value.trim());
                          return date.isAfter(DateTime.now())
                              ? 'La date doit être passée.'
                              : null;
                        } catch (_) {
                          return 'Utilisez le format JJ/MM/AAAA.';
                        }
                      },
                    ),
                  if (widget.kind == CatalogKind.practitioners) ...[
                    _field('job', 'Fonction'),
                    _field('specialty', 'Spécialité', max: 2000),
                  ],
                  if (widget.kind == CatalogKind.categories) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _parent,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie principale',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Aucune (catégorie principale)'),
                        ),
                        ...widget.categories
                            .where(
                              (c) =>
                                  c.parentId == null &&
                                  c.id != widget.entry?.id,
                            )
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _parent = value == '' ? null : value,
                            ),
                    ),
                    const SizedBox(height: 14),
                    _field(
                      'order',
                      'Ordre d’affichage',
                      keyboard: TextInputType.number,
                      max: 5,
                      validate: (value) {
                        final order = int.tryParse(value ?? '');
                        return order == null || order < 0 || order > 10000
                            ? 'Ordre entre 0 et 10000.'
                            : null;
                      },
                    ),
                  ],
                  if (widget.kind == CatalogKind.services) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Sans catégorie'),
                        ),
                        ...widget.categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                        if (_category != null &&
                            !widget.categories.any((c) => c.id == _category))
                          DropdownMenuItem(
                            value: _category,
                            child: const Text('Catégorie archivée'),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _category = value == '' ? null : value,
                            ),
                    ),
                    const SizedBox(height: 14),
                    _field('description', 'Description', max: 2000),
                    _field(
                      'duration',
                      'Durée (minutes) *',
                      keyboard: TextInputType.number,
                      max: 4,
                      validate: (value) {
                        final n = int.tryParse(value ?? '');
                        return n == null || n < 1 || n > 1440
                            ? 'Durée entre 1 et 1440 minutes.'
                            : null;
                      },
                    ),
                    _field(
                      'price',
                      'Prix (MAD) *',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      max: 12,
                      validate: (_) => _price() == null || _price()! > 100000000
                          ? 'Prix valide avec deux décimales maximum.'
                          : null,
                    ),
                  ],
                  if (widget.kind != CatalogKind.clients)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Actif'),
                      subtitle: const Text(
                        'L’historique est conservé si désactivé.',
                      ),
                      value: _active,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _active = value),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: ElmaColors.red),
                      ),
                    ),
                  ElmaButton(
                    label: 'Enregistrer',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
