import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/app_failure.dart';
import '../../domain/packs/packs.dart';
import '../widgets/elma_widgets.dart';

class PackPhotoSheet extends StatefulWidget {
  const PackPhotoSheet({
    super.key,
    required this.entry,
    required this.repository,
  });
  final ClinicPack entry;
  final PacksRepository repository;
  @override
  State<PackPhotoSheet> createState() => _PackPhotoSheetState();
}

class _PackPhotoSheetState extends State<PackPhotoSheet> {
  Uint8List? _bytes;
  bool _busy = false;
  String? _error;
  final _picker = ImagePicker();
  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A recovered Android picker result is always previewed and explicitly
      // saved to this service, never silently assigned after process restart.
      final lost = await _picker.retrieveLostData();
      if (lost.exception != null) throw lost.exception!;
      final image =
          lost.files?.firstOrNull ??
          await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 85,
          );
      if (image == null) return;
      if (await image.length() > 2 * 1024 * 1024) {
        throw const AppFailure('Image limitée à 2 Mo.');
      }
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _bytes = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = _bytes!;
      final mime = bytes.length >= 3 && bytes[0] == 255 && bytes[1] == 216
          ? 'image/jpeg'
          : bytes.length >= 8 && bytes[0] == 137 && bytes[1] == 80
          ? 'image/png'
          : 'image/webp';
      await widget.repository.uploadImage(widget.entry.id!, bytes, mime);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Photo · ${widget.entry.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _bytes!,
                  height: 144,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Text(
                    'Aperçu indisponible. Choisissez une autre image.',
                  ),
                ),
              )
            else if (widget.entry.imageUrl != null)
              Image.network(
                widget.entry.imageUrl!,
                height: 144,
                errorBuilder: (_, _, _) => const Text('Aperçu indisponible.'),
              ),
            TextButton(
              onPressed: _busy ? null : _choose,
              child: const Text('Choisir une photo'),
            ),
            if (_error != null) Text(_error!),
            ElmaButton(
              label: 'Enregistrer la photo',
              loading: _busy,
              onPressed: _bytes == null ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
