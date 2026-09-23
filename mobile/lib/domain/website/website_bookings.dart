import '../appointments/appointments.dart';

enum WebsiteState {
  review('REVIEW', 'À vérifier'),
  imported('IMPORTED', 'Importées'),
  dismissed('DISMISSED', 'Écartées');

  const WebsiteState(this.code, this.label);
  final String code, label;
}

class WebsiteBooking {
  const WebsiteBooking({
    required this.id,
    required this.version,
    required this.state,
    required this.clientName,
    required this.start,
    required this.serviceReferences,
    this.phone,
    this.email,
    this.notes,
    this.appointmentId,
    this.dismissalReason,
  });
  final String id, clientName;
  final int version;
  final WebsiteState state;
  final DateTime start;
  final List<String> serviceReferences;
  final String? phone, email, notes, appointmentId, dismissalReason;
}

class WebsitePage {
  const WebsitePage(this.items, this.total, this.hasMore);
  final List<WebsiteBooking> items;
  final int total;
  final bool hasMore;
}

abstract interface class WebsiteBookingsRepository {
  Future<void> dismiss(WebsiteBooking event, String reason);
  Future<void> archiveImported(WebsiteBooking event);
  Future<WebsitePage> list(WebsiteState state, {int page = 1});
  Future<String> importBooking(
    WebsiteBooking event,
    BookingSelection selection,
    BookingQuote quote,
    String? notes,
  );
}
