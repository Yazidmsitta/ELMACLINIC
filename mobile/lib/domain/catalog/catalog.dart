import 'dart:typed_data';

enum CatalogKind {
  clients('clients', 'Clients'),
  services('services', 'Prestations'),
  practitioners('practitioners', 'Praticiennes'),
  categories('categories', 'Catégories');

  const CatalogKind(this.path, this.label);
  final String path, label;
}

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.birthDate,
    this.specialty,
    this.jobTitle,
    this.description,
    this.categoryId,
    this.durationMinutes,
    this.priceCentimes,
    this.active = true,
    this.imageUrl,
    this.parentId,
    this.sortOrder = 0,
  });
  final String id, name;
  final String? phone,
      email,
      birthDate,
      specialty,
      jobTitle,
      description,
      categoryId;
  final int? durationMinutes, priceCentimes;
  final bool active;
  final String? imageUrl, parentId;
  final int sortOrder;
}

class CatalogPage {
  const CatalogPage(this.entries, this.total, this.hasMore);
  final List<CatalogEntry> entries;
  final int total;
  final bool hasMore;
}


class ClientPackSummary {
  const ClientPackSummary({
    required this.packId,
    required this.name,
    required this.totalSessions,
    required this.completedSessions,
    required this.remainingSessions,
  });
  final String packId, name;
  final int totalSessions, completedSessions, remainingSessions;
  bool get completed => remainingSessions <= 0;
}

class ClientProfile {
  const ClientProfile({
    required this.client,
    required this.today,
    required this.history,
    required this.packs,
  });
  final CatalogEntry client;
  final List<Map<String, dynamic>> today, history;
  final List<ClientPackSummary> packs;
}

abstract interface class CatalogRepository {
  Future<ClientProfile> clientProfile(String id);
  Future<ClientPackSummary> adjustClientPackSessions(
    String clientId,
    String packId,
    int delta,
  );
  Future<PractitionerAvailability> availability(String id);
  Future<void> saveAvailability(
    String id,
    PractitionerAvailability availability,
  );
  Future<void> uploadImage(String id, Uint8List bytes, String mimeType);
  Future<CatalogPage> list(
    CatalogKind kind, {
    int page = 1,
    String search = '',
    String? categoryId,
  });
  Future<String> save(
    CatalogKind kind,
    CatalogEntry entry, {
    required bool creating,
  });
  Future<void> setActive(CatalogKind kind, String id, bool active);
  Future<void> archive(CatalogKind kind, String id);
}

class WeeklyShift {
  const WeeklyShift(this.weekday, this.start, this.end);
  final int weekday;
  final String start, end;
}

class TimeOff {
  const TimeOff(this.start, this.end);
  final DateTime start, end;
}

class PractitionerAvailability {
  const PractitionerAvailability(this.shifts, this.absences);
  final List<WeeklyShift> shifts;
  final List<TimeOff> absences;
}
