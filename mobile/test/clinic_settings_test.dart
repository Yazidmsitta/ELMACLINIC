import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/settings/clinic_settings.dart';
import 'package:elmaclinic/presentation/settings/clinic_settings_screen.dart';
import 'catalog_test.dart' show catalogApp;

class FakeSettings implements ClinicSettingsRepository {
  bool fail = true;
  final versions = <int>[];
  @override
  Future<ClinicSettings> load() async =>
      const ClinicSettings('ElmaClinic', '', '', 2);
  @override
  Future<int> save(ClinicSettings draft) async {
    versions.add(draft.version);
    if (fail) {
      throw const AppFailure('Informations modifiées. Rechargez la fiche.');
    }
    return draft.version + 1;
  }
}

void main() {
  testWidgets(
    'settings preserve draft on conflict and use returned version after save',
    (tester) async {
      final repo = FakeSettings();
      await tester.pumpWidget(
        catalogApp(ClinicSettingsScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Ma clinique');
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Ma clinique'), findsOneWidget);
      expect(
        find.text('Informations modifiées. Rechargez la fiche.'),
        findsOneWidget,
      );
      repo.fail = false;
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repo.versions, [2, 2, 3]);
    },
  );
}
