import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/presentation/activity/activity_screen.dart';

void main() {
  test('Activity labels replace technical codes including unknown codes', () {
    expect(
      activityActionLabel('AVAILABILITY_UPDATE'),
      'Disponibilités modifiées',
    );
    expect(activityActionLabel('RESCHEDULE'), 'Rendez-vous déplacé');
    expect(activityActionLabel('NEW_INTERNAL_CODE'), 'Action enregistrée');
    expect(activityEntityLabel('profiles'), 'Utilisateur');
    expect(activityEntityLabel('unknown_table'), 'Activité de la clinique');
  });
}
