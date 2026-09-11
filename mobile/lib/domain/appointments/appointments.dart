import 'dart:math';

enum AppointmentStatus {
  fresh('NEW', 'Nouveau'),
  pending('PENDING', 'En attente'),
  confirmed('CONFIRMED', 'Confirmé'),
  inProgress('IN_PROGRESS', 'En cours'),
  completed('COMPLETED', 'Terminé'),
  cancelled('CANCELLED', 'Annulé'),
  noShow('NO_SHOW', 'Absent');

  const AppointmentStatus(this.code, this.label);
  final String code, label;
  List<AppointmentStatus> get next => switch (this) {
    fresh => [pending, confirmed, cancelled],
    pending => [confirmed, cancelled],
    confirmed => [inProgress, cancelled, noShow],
    inProgress => [completed, cancelled],
    _ => [],
  };
}

enum AppointmentSource {
  manual('MANUAL', 'Manuel'),
  website('WEBSITE', 'Site web');

  const AppointmentSource(this.code, this.label);
  final String code, label;
}

class BookingItem {
  const BookingItem(
    this.id,
    this.name,
    this.duration,
    this.priceCentimes,
    this.quantity,
  );
  final String id, name;
  final int duration, priceCentimes, quantity;
}

class BookingQuote {
  const BookingQuote(
    this.start,
    this.end,
    this.duration,
    this.totalCentimes,
    this.services,
  );
  final DateTime start, end;
  final int duration, totalCentimes;
  final List<BookingItem> services;
}

class ClinicAppointment {
  const ClinicAppointment({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhone,
    this.practitionerId,
    this.practitionerName,
    required this.start,
    required this.end,
    required this.status,
    required this.source,
    this.notes,
    required this.version,
    required this.services,
    required this.totalCentimes,
  });
  final String id, clientId, clientName;
  final String? clientPhone, practitionerId, practitionerName, notes;
  final DateTime start, end;
  final AppointmentStatus status;
  final AppointmentSource source;
  final int version, totalCentimes;
  final List<BookingItem> services;
  bool get canReschedule => [
    AppointmentStatus.fresh,
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
  ].contains(status);
}

class AppointmentPage {
  const AppointmentPage(this.entries, this.total, this.hasMore);
  final List<ClinicAppointment> entries;
  final int total;
  final bool hasMore;
}

class BookingSelection {
  const BookingSelection(
    this.clientId,
    this.practitionerId,
    this.serviceIds,
    this.start,
  );
  final String clientId, practitionerId;
  final List<String> serviceIds;
  final DateTime start;
}

abstract interface class AppointmentsRepository {
  Future<AppointmentPage> list(
    DateTime day, {
    int page = 1,
    AppointmentStatus? status,
    AppointmentSource? source,
    String? practitionerId,
  });
  Future<ClinicAppointment> details(String id);
  Future<BookingQuote> quote(BookingSelection selection);
  Future<String> create(
    BookingSelection selection,
    BookingQuote quote,
    String? notes,
    String requestId,
  );
  Future<void> reschedule(
    ClinicAppointment appointment,
    String practitionerId,
    DateTime start,
    String? notes,
  );
  Future<void> changeStatus(
    ClinicAppointment appointment,
    AppointmentStatus status,
  );
  Future<void> archive(ClinicAppointment appointment);
}

String bookingRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
