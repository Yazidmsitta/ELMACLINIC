import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elmaclinic/domain/app_failure.dart';
import 'package:elmaclinic/domain/expenses/expenses.dart';
import 'package:elmaclinic/presentation/expenses/expenses_screen.dart';
import 'catalog_test.dart' show catalogApp;

class FakeExpenses implements ExpensesRepository {
  bool failSummary = false;
  @override
  Future<ExpenseSummary> summary() async {
    if (failSummary) throw const AppFailure('Connexion interrompue.');
    return const ExpenseSummary(1255000, 51, '2026-09-11');
  }

  static const entry = Expense(
    id: 'expense',
    description: 'Achat produits soins',
    category: 'Produits',
    amount: 240000,
    spentOn: '2026-09-05',
    version: 3,
  );
  final keys = <String>[];
  final states = <bool>[];
  bool fail = true;
  int? version;
  String? reason;
  @override
  Future<ExpensePage> list({bool voided = false, int page = 1}) async {
    states.add(voided);
    return const ExpensePage([entry], 1, false);
  }

  @override
  Future<String> create(ExpenseDraft draft, String requestId) async {
    keys.add(requestId);
    if (fail) throw const AppFailure('Connexion interrompue.');
    return 'expense';
  }

  @override
  Future<void> update(Expense expense, ExpenseDraft draft) async {
    version = expense.version;
  }

  @override
  Future<void> voidExpense(Expense expense, String reason) async {
    version = expense.version;
    this.reason = reason;
  }
}

void main() {
  testWidgets(
    'summary failure keeps records visible and retry restores server totals',
    (tester) async {
      final repo = FakeExpenses()..failSummary = true;
      await tester.pumpWidget(catalogApp(ExpensesScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Produits'), findsOneWidget);
      expect(find.text('Achat produits soins · 5 sept. 2026'), findsOneWidget);
      expect(find.text('Ce mois'), findsNothing);
      repo.failSummary = false;
      await tester.tap(find.text('Réessayer le résumé'));
      await tester.pumpAndSettle();
      expect(find.text('51'), findsOneWidget);
      expect(find.text(expenseMoney(1255000)), findsOneWidget);
    },
  );
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets('creation preserves draft and request ID after failure', (
    tester,
  ) async {
    final repo = FakeExpenses();
    await tester.pumpWidget(
      catalogApp(Scaffold(body: ExpenseSheet(repository: repo))),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Produits');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Achat produits soins',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '12,34');
    await tester.ensureVisible(find.text('Enregistrer la dépense'));
    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion interrompue.'), findsOneWidget);
    expect(find.text('12,34'), findsOneWidget);
    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pumpAndSettle();
    expect(repo.keys.length, 2);
    expect(repo.keys.toSet().length, 1);
  });
  testWidgets('void requires reason and forwards reviewed version', (
    tester,
  ) async {
    final repo = FakeExpenses();
    await tester.pumpWidget(
      catalogApp(
        Scaffold(
          body: ExpenseSheet(
            repository: repo,
            expense: FakeExpenses.entry,
            voiding: true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirmer l’annulation'));
    await tester.pumpAndSettle();
    expect(repo.reason, isNull);
    await tester.enterText(find.byType(TextFormField), 'Double saisie');
    await tester.tap(find.text('Confirmer l’annulation'));
    await tester.pumpAndSettle();
    expect(repo.version, 3);
    expect(repo.reason, 'Double saisie');
  });
  testWidgets('expense history filter requests voided records', (tester) async {
    final repo = FakeExpenses();
    await tester.pumpWidget(catalogApp(ExpensesScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulées'));
    await tester.pumpAndSettle();
    expect(repo.states, [false, true]);
    expect(tester.takeException(), isNull);
  });
}
