import 'package:flutter/material.dart';
import '../../domain/app_failure.dart';
import '../../domain/settings/clinic_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';

class ClinicSettingsScreen extends StatefulWidget {
  const ClinicSettingsScreen({super.key, required this.repository});
  final ClinicSettingsRepository repository;
  @override
  State<ClinicSettingsScreen> createState() => _ClinicSettingsScreenState();
}

class _ClinicSettingsScreenState extends State<ClinicSettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController();
  bool _loading = true, _saving = false, _loaded = false;
  int _version = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _name.text = result.name;
        _phone.text = result.phone;
        _address.text = result.address;
        _version = result.version;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recharger les informations ?'),
        content: const Text(
          'Les modifications non enregistrées seront remplacées par les informations du serveur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver mes modifications'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recharger'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) await _load();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final version = await widget.repository.save(
        ClinicSettings(
          _name.text.trim(),
          _phone.text.trim(),
          _address.text.trim(),
          _version,
        ),
      );
      if (!mounted) return;
      setState(() => _version = version);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations enregistrées.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ElmaHeader(
              'Paramètres',
              subtitle: 'Informations de la clinique',
              leading: IconButton(
                tooltip: 'Retour',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const ElmaIcon('ChevronLeft'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (!_loading && _loaded)
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              enabled: !_saving,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                labelText: 'Nom de la clinique',
                              ),
                              validator: (value) =>
                                  (value?.trim().isEmpty ?? true)
                                  ? 'Nom obligatoire.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phone,
                              enabled: !_saving,
                              maxLength: 40,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _address,
                              enabled: !_saving,
                              maxLength: 1000,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Adresse',
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElmaButton(
                              label: 'Enregistrer',
                              loading: _saving,
                              onPressed: _saving ? null : _save,
                            ),
                            TextButton(
                              onPressed: _saving ? null : _reload,
                              child: const Text('Recharger depuis le serveur'),
                            ),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: ElmaColors.red),
                        ),
                      ),
                    if (!_loading && !_loaded)
                      TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
