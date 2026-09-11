import 'domain/notifications/notifications.dart';
import 'data/notifications/api_notifications_repository.dart';
import 'domain/staff/staff.dart';
import 'data/staff/api_staff_repository.dart';
import 'domain/inventory/inventory.dart';
import 'data/inventory/api_inventory_repository.dart';
import 'domain/expenses/expenses.dart';
import 'data/expenses/api_expenses_repository.dart';
import 'domain/payments/payments.dart';
import 'data/payments/api_payments_repository.dart';
import 'presentation/payments/payment_sheet.dart';
import 'domain/website/website_bookings.dart';
import 'data/website/api_website_bookings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/api/api_client.dart';
import 'data/api/token_store.dart';
import 'data/auth/api_auth_repository.dart';
import 'data/dashboard/api_dashboard_repository.dart';
import 'domain/dashboard/dashboard.dart';
import 'domain/catalog/catalog.dart';
import 'domain/appointments/appointments.dart';
import 'data/appointments/api_appointments_repository.dart';
import 'data/catalog/api_catalog_repository.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final api = ApiClient(SessionTokenStore(const SecureTokenStore()));
  final auth = AuthController(ApiAuthRepository(api));
  api.onUnauthorized = auth.expire;
  runApp(
    ElmaClinicApp(
      auth: auth,
      dashboard: ApiDashboardRepository(api),
      catalog: ApiCatalogRepository(api),
      appointments: ApiAppointmentsRepository(api),
      website: ApiWebsiteBookingsRepository(api),
      payments: ApiPaymentsRepository(api),
      expenses: ApiExpensesRepository(api),
      inventory: ApiInventoryRepository(api),
      staff: ApiStaffRepository(api),
      notifications: ApiNotificationsRepository(api),
    ),
  );
  await auth.restore();
}

class ElmaClinicApp extends StatelessWidget {
  const ElmaClinicApp({
    super.key,
    required this.auth,
    this.dashboard,
    this.catalog,
    this.appointments,
    this.website,
    this.payments,
    this.expenses,
    this.inventory,
    this.staff,
    this.notifications,
  });
  final AuthController auth;
  final DashboardRepository? dashboard;
  final CatalogRepository? catalog;
  final AppointmentsRepository? appointments;
  final WebsiteBookingsRepository? website;
  final PaymentsRepository? payments;
  final ExpensesRepository? expenses;
  final InventoryRepository? inventory;
  final StaffRepository? staff;
  final NotificationsRepository? notifications;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ElmaClinic',
    builder: (context, child) =>
        PaymentScope(repository: payments, child: child!),
    debugShowCheckedModeBanner: false,
    theme: AppTokens.theme,
    locale: const Locale('fr'),
    supportedLocales: const [Locale('fr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.user == null
            ? LoginScreen(auth: auth)
            : AppShell(
                auth: auth,
                dashboard: dashboard,
                catalog: catalog,
                appointments: appointments,
                website: website,
                expenses: expenses,
                inventory: inventory,
                staff: staff,
                notifications: notifications,
              );
      },
    ),
  );
}
