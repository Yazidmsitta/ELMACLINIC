import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/app_failure.dart';

abstract final class ClinicTime {
  static final tz.Location location = _initialize();
  static tz.Location _initialize() {
    data.initializeTimeZones();
    return tz.getLocation('Africa/Casablanca');
  }

  static tz.TZDateTime now() => tz.TZDateTime.now(location);
  static tz.TZDateTime local(DateTime instant) =>
      tz.TZDateTime.from(instant, location);
  static DateTime at(DateTime day, TimeOfDay time) {
    final result = tz.TZDateTime(
      location,
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (result.hour != time.hour || result.minute != time.minute) {
      throw const AppFailure('Cette heure n’existe pas à Casablanca.');
    }
    for (final delta in [-1, 1]) {
      final alternative = local(result.add(Duration(hours: delta)));
      if (alternative.year == day.year &&
          alternative.month == day.month &&
          alternative.day == day.day &&
          alternative.hour == time.hour &&
          alternative.minute == time.minute) {
        throw const AppFailure(
          'Cette heure est ambiguë lors du changement d’heure. Choisissez un autre créneau.',
        );
      }
    }
    return result;
  }
}
