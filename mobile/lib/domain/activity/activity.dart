class ActivityEntry {
  const ActivityEntry(
    this.id,
    this.actorId,
    this.action,
    this.entityType,
    this.entityId,
    this.createdAt, {
    this.actorName,
  });
  final String id, action, entityType;
  final String? actorId, entityId, actorName;
  final DateTime createdAt;
}

class ActivityPage {
  const ActivityPage(this.items, this.hasMore);
  final List<ActivityEntry> items;
  final bool hasMore;
}

abstract interface class ActivityRepository {
  Future<ActivityPage> list({
    int page = 1,
    String? actorId,
    String? entityType,
  });
}
