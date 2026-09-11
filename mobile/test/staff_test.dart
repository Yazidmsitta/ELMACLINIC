import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/staff/staff.dart';
import 'package:elmaclinic/presentation/staff/staff_screen.dart';
import 'catalog_test.dart' show catalogApp;

class FakeStaff implements StaffRepository {
  static const member = StaffMember('id', 'Administrateur', 'ADMIN', true, 3);
  int? version;
  @override
  Future<StaffPage> list({int page = 1}) async =>
      const StaffPage([member], false);
  @override
  Future<void> update(
    StaffMember original,
    String name,
    String role,
    bool active,
  ) async {
    version = original.version;
    throw const AppFailure('Un administrateur actif est requis.');
  }
}

void main() {
  testWidgets(
    'staff save uses reviewed version and preserves server rejection',
    (tester) async {
      final repo = FakeStaff();
      await tester.pumpWidget(
        catalogApp(
          Scaffold(
            body: StaffSheet(repository: repo, member: FakeStaff.member),
          ),
        ),
      );
      await tester.tap(find.text('Utilisateur'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repo.version, 3);
      expect(find.text('Un administrateur actif est requis.'), findsOneWidget);
    },
  );
}
