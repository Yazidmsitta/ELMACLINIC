import 'dart:typed_data';

class ClinicPack {
  const ClinicPack({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.totalSessions = 1,
    this.active = true,
    this.version = 0,
    required this.items,
    this.imageUrl,
  });
  final String? id, imageUrl;
  final String name, description;
  final int price, totalSessions, version;
  final bool active;
  final Map<String, int> items;
}

class PackPage {
  const PackPage(this.items, this.hasMore);
  final List<ClinicPack> items;
  final bool hasMore;
}

abstract interface class PacksRepository {
  Future<PackPage> list({int page = 1});
  Future<String> save(ClinicPack pack);
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType);
}
