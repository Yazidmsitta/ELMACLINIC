class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.time,
    required this.duration,
    required this.client,
    required this.service,
    required this.status,
    required this.source,
  });
  final String id, time, client, service, status, source;
  final int duration;
}

class RevenueDay {
  const RevenueDay(this.date, this.centimes);
  final DateTime date;
  final int centimes;
}

class ClinicNotification {
  const ClinicNotification(this.id, this.type, this.unread);
  final String id, type;
  final bool unread;
}

class Dashboard {
  const Dashboard({
    required this.date,
    required this.appointments,
    required this.clients,
    required this.pending,
    required this.websiteNew,
    required this.schedule,
    required this.notifications,
    this.revenueCentimes,
    this.week = const [],
  });
  final DateTime date;
  final int appointments, clients, pending, websiteNew;
  final int? revenueCentimes;
  final List<ScheduleEntry> schedule;
  final List<RevenueDay> week;
  final List<ClinicNotification> notifications;
}

abstract interface class DashboardRepository {
  Future<Dashboard> load();
}
