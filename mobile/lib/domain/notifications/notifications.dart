class ClinicNotification {
  const ClinicNotification(this.id, this.type, this.createdAt, this.readAt);
  final String id, type;
  final DateTime createdAt;
  final DateTime? readAt;
}

class NotificationPage {
  const NotificationPage(this.items, this.hasMore);
  final List<ClinicNotification> items;
  final bool hasMore;
}

abstract interface class NotificationsRepository {
  Future<NotificationPage> list({int page = 1});
  Future<void> markRead(String id);
}
