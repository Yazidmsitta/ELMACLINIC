import '../widgets/image_field.dart';
import 'package:flutter/material.dart';
import '../../domain/app_failure.dart';
import '../../domain/inventory/inventory.dart';
import '../../domain/appointments/appointments.dart';
import '../../domain/payments/payments.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, required this.repository});
  final InventoryRepository repository;
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _items = <StockProduct>[];
  bool _busy = false, _more = false;
  int _page = 0, _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (_busy && next) return;
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
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _sheet({StockProduct? product, bool adjust = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => InventorySheet(
        repository: widget.repository,
        product: product,
        adjust: adjust,
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
            'Inventaire',
            leading: IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).pop(),
              icon: const ElmaIcon('ChevronLeft'),
            ),
            trailing: FilledButton.icon(
              onPressed: () => _sheet(),
              icon: const ElmaIcon('Plus', color: Colors.white, size: 15),
              label: const Text('Ajouter'),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final product in _items) _card(product),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: () => _load(next: _items.isNotEmpty),
                      child: const Text('Réessayer'),
                    ),
                  ],
                  if (!_busy && _error == null && _items.isEmpty)
                    const Text('Aucun produit.'),
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
  Widget _card(StockProduct product) {
    final quantity = quantityMilli(product.quantity)!,
        threshold = quantityMilli(product.threshold)!;
    final out = quantity <= 0, low = quantity > 0 && quantity < threshold;
    final color = out
        ? ElmaColors.red
        : low
        ? ElmaColors.amber
        : ElmaColors.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ElmaColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: product.active
              ? () => _sheet(product: product, adjust: true)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            product.sku,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ElmaColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      !product.active
                          ? 'Inactif'
                          : out
                          ? 'Rupture'
                          : low
                          ? 'Stock bas'
                          : 'En stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modifier le produit',
                      onPressed: () => _sheet(product: product),
                      icon: const ElmaIcon('Edit', size: 18),
                    ),
                  ],
                ),
                Text(
                  '${product.quantity} ${product.unit} · min. ${product.threshold}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: threshold > 0
                      ? (quantity / (threshold * 2)).clamp(0.0, 1.0)
                      : quantity > 0
                      ? 1
                      : 0,
                  color: color,
                  backgroundColor: ElmaColors.surface,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InventorySheet extends StatefulWidget {
  const InventorySheet({
    super.key,
    required this.repository,
    this.product,
    this.adjust = false,
  });
  final InventoryRepository repository;
  final StockProduct? product;
  final bool adjust;
  @override
  State<InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<InventorySheet> {
  DraftImage? _image;
  String? _savedId;
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _key = bookingRequestId();
  bool _busy = false, _submitted = false, _active = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    for (final entry in {
      'SKU': p?.sku ?? '',
      'Nom du produit': p?.name ?? '',
      'Unité': p?.unit ?? 'unité',
      'Stock minimum': p?.threshold ?? '0',
      'Prix d’achat (MAD)': p == null
          ? '0'
          : '${p.cost ~/ 100}.${(p.cost % 100).toString().padLeft(2, '0')}',
      'Quantité à ajouter ou retirer': '',
      'Motif': '',
    }.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _active = p?.active ?? true;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _submitted = true;
      _error = null;
    });
    String value(String key) => _fields[key]!.text.trim();
    try {
      if (widget.adjust) {
        await widget.repository.adjust(
          widget.product!,
          value('Quantité à ajouter ou retirer').replaceAll(',', '.'),
          value('Motif'),
          _key,
        );
      } else {
        _savedId ??= await widget.repository.save(
          ProductDraft(
            value('SKU'),
            value('Nom du produit'),
            value('Unité'),
            parseMadCentimes(value('Prix d’achat (MAD)')) ?? 0,
            value('Stock minimum').replaceAll(',', '.'),
            _active,
          ),
          product: widget.product,
        );
      }
      if (!widget.adjust && _image != null) await widget.repository.uploadImage(_savedId!, _image!.bytes, _image!.mime);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _savedId != null || (widget.adjust && _submitted);
    final labels = widget.adjust
        ? ['Quantité à ajouter ou retirer', 'Motif']
        : [
            'SKU',
            'Nom du produit',
            'Unité',
            'Stock minimum',
            'Prix d’achat (MAD)',
          ];
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.adjust
                              ? widget.product!.name
                              : widget.product == null
                              ? 'Nouveau produit'
                              : 'Modifier le produit',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const ElmaIcon('X'),
                      ),
                    ],
                  ),
                  if (widget.adjust)
                    Text(
                      'Stock actuel : ${widget.product!.quantity} ${widget.product!.unit}. Une quantité négative retire du stock.',
                    ),
                  if (!widget.adjust) ImageField(enabled: !_busy, onChanged: (image) => _image = image),
                  for (final label in labels)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextFormField(
                        controller: _fields[label],
                        enabled: !locked,
                        decoration: InputDecoration(labelText: label),
                        validator: (raw) {
                          final value = (raw ?? '').trim();
                          if (label == 'Stock minimum' ||
                              label == 'Quantité à ajouter ou retirer') {
                            final number = quantityMilli(
                              value.replaceAll(',', '.'),
                            );
                            if (number == null ||
                                (label == 'Stock minimum'
                                    ? number < 0
                                    : number == 0)) {
                              return 'Quantité invalide (3 décimales maximum).';
                            }
                          } else if (label == 'Prix d’achat (MAD)') {
                            if (!RegExp(r'^0([.,]0{1,2})?$').hasMatch(value) &&
                                parseMadCentimes(value) == null) {
                              return 'Montant invalide.';
                            }
                          } else {
                            final max = label == 'SKU'
                                ? 100
                                : label == 'Unité'
                                ? 40
                                : label == 'Motif'
                                ? 500
                                : 200;
                            if (value.length < (label == 'Motif' ? 3 : 1) ||
                                value.length > max) {
                              return 'Saisissez ${label == 'Motif' ? 3 : 1} à $max caractères.';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  if (!widget.adjust)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Produit actif'),
                      value: _active,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _active = value),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: ElmaColors.red),
                      ),
                    ),
                  if (_submitted && widget.adjust && !_busy)
                    const Text(
                      'Réessayez avec les mêmes informations pour éviter un doublon.',
                    ),
                  if (_submitted &&
                      !widget.adjust &&
                      widget.product == null &&
                      !_busy)
                    const Text(
                      'Si la réponse a été interrompue, fermez et actualisez la liste avant de recréer ce SKU.',
                    ),
                  const SizedBox(height: 20),
                  ElmaButton(
                    label: widget.adjust
                        ? 'Mettre à jour le stock'
                        : 'Enregistrer le produit',
                    loading: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
