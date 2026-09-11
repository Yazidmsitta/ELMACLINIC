import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/presentation/appointments/clinic_time.dart';

void main() {
  test('clinic calendar dates are independent of device midnight', () {
    final instant = DateTime.utc(2026, 1, 1, 23, 30);
    final local = ClinicTime.local(instant);
    expect(local.day, 2);
    expect(local.hour, 0);
    expect(
      ClinicTime.at(
        DateTime(2026, 1, 2),
        const TimeOfDay(hour: 0, minute: 30),
      ).toUtc(),
      instant,
    );
  });
  test('clock-change gaps and ambiguous wall times are rejected', () {
    var rejected = 0;
    for (var day = 1; day <= 365; day++) {
      try {
        ClinicTime.at(
          DateTime(2026, 1, day),
          const TimeOfDay(hour: 2, minute: 30),
        );
      } on AppFailure {
        rejected++;
      }
    }
    expect(rejected, greaterThanOrEqualTo(2));
  });
}
