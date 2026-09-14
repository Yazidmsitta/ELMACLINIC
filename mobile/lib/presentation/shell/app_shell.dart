import '../packs/packs_screen.dart';
import '../../domain/packs/packs.dart';
import '../activity/activity_screen.dart';
import '../../domain/activity/activity.dart';
import '../../domain/reports/financial_report.dart';
import '../reports/reports_screen.dart';
import '../../domain/settings/clinic_settings.dart';
import '../settings/clinic_settings_screen.dart';
import '../../domain/notifications/notifications.dart';
import '../notifications/notifications_screen.dart';
import '../../domain/staff/staff.dart';
import '../staff/staff_screen.dart';
import '../../domain/inventory/inventory.dart';
import '../inventory/inventory_screen.dart';
import '../../domain/expenses/expenses.dart';
import '../expenses/expenses_screen.dart';
import '../payments/payment_sheet.dart';
import '../payments/payment_ledger_screen.dart';
import '../../domain/website/website_bookings.dart';
import '../website/website_bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/dashboard/dashboard.dart';
import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import '../../domain/catalog/catalog.dart';
import '../catalog/catalog_screen.dart';
import '../../domain/appointments/appointments.dart';
import '../appointments/appointments_screen.dart';
import '../appointments/appointment_detail.dart';
import '../appointments/booking_wizard.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.auth,
    this.dashboard,
    this.catalog,
    this.appointments,
    this.website,
    this.expenses,
    this.inventory,
    this.staff,
    this.settings,
    this.reports,
    this.activity,
    this.packs,
    this.notifications,
  });
  final AuthController auth;
  final DashboardRepository? dashboard;
  final CatalogRepository? catalog;
  final AppointmentsRepository? appointments;
  final WebsiteBookingsRepository? website;
  final ExpensesRepository? expenses;
  final InventoryRepository? inventory;
  final StaffRepository? staff;
  final ClinicSettingsRepository? settings;
  final ReportsRepository? reports;
  final ActivityRepository? activity;
  final PacksRepository? packs;
  final NotificationsRepository? notifications;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0,
      _appointmentRevision = 0,
      _homeRevision = 0,
      _paymentRevision = 0;
  Future<void> _openAppointment(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AppointmentDetail(
          id: id,
          repository: widget.appointments!,
          catalog: widget.catalog!,
          isAdmin: widget.auth.user!.isAdmin,
        ),
      ),
    );
    if (mounted) setState(() => _appointmentRevision++);
  }

  Future<void> _createAppointment() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BookingWizard(
          repository: widget.appointments!,
          catalog: widget.catalog!,
        ),
      ),
    );
    if (id != null && mounted) await _openAppointment(id);
  }

  late String _identity;
  void _onIdentityChanged() {
    final user = widget.auth.user;
    final identity = '${user?.id}:${user?.role}';
    if (identity != _identity && mounted) {
      _identity = identity;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static const tabs = [
    ('Accueil', 'Home'),
    ('Rendez-vous', 'Calendar'),
    ('Clients', 'Users'),
    ('Paiements', 'Wallet'),
    ('Plus', 'Grid'),
  ];
  @override
  void initState() {
    super.initState();
    _identity = '${widget.auth.user?.id}:${widget.auth.user?.role}';
    widget.auth.addListener(_onIdentityChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onIdentityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.auth.restore();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _index = 0);
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  key: ValueKey('${user.id}:${user.role}'),
                  user: user,
                  repository: widget.dashboard,
                  refreshToken: _homeRevision,
                  onCreateAppointment:
                      widget.appointments != null && widget.catalog != null
                      ? _createAppointment
                      : null,
                  onAppointment:
                      widget.appointments != null && widget.catalog != null
                      ? _openAppointment
                      : null,
                  onTab: (index) => setState(() => _index = index),
                ),
                if (widget.appointments != null && widget.catalog != null)
                  AppointmentsScreen(
                    key: ValueKey(
                      'appointments:${user.id}:${user.role}:$_appointmentRevision',
                    ),
                    repository: widget.appointments!,
                    catalog: widget.catalog!,
                    isAdmin: user.isAdmin,
                  )
                else
                  const ModuleScreen(
                    title: 'Rendez-vous',
                    subtitle: 'Votre agenda au quotidien',
                    icon: 'Calendar',
                  ),
                if (widget.catalog != null)
                  CatalogScreen(
                    key: ValueKey('clients:${user.id}:${user.role}'),
                    kind: CatalogKind.clients,
                    repository: widget.catalog!,
                    isAdmin: user.isAdmin,
                  )
                else
                  const ModuleScreen(
                    title: 'Clients',
                    subtitle: 'Prenez soin de chaque relation',
                    icon: 'Users',
                  ),
                if (user.isAdmin && PaymentScope.of(context) != null)
                  PaymentLedgerScreen(
                    key: ValueKey('payments:${user.id}:${user.role}'),
                    repository: PaymentScope.of(context)!,
                    refreshToken: _paymentRevision,
                    onCollect: () => setState(() => _index = 1),
                  )
                else
                  ListView(
                    children: [
                      const ElmaHeader(
                        'Paiements',
                        subtitle: 'Encaissements en MAD',
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sélectionnez un rendez-vous confirmé, en cours ou terminé, puis « Encaisser un paiement ». Le solde est vérifié avant enregistrement.',
                            ),
                            const SizedBox(height: 20),
                            ElmaButton(
                              label: 'Choisir un rendez-vous',
                              onPressed: () => setState(() => _index = 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                MoreScreen(
                  user: user,
                  onLogout: widget.auth.logout,
                  onPacks: widget.packs != null && widget.catalog != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => PacksScreen(
                              repository: widget.packs!,
                              catalog: widget.catalog!,
                              isAdmin: user.isAdmin,
                            ),
                          ),
                        )
                      : null,
                  onActivity: user.isAdmin && widget.activity != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                ActivityScreen(repository: widget.activity!),
                          ),
                        )
                      : null,
                  onReports: user.isAdmin && widget.reports != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReportsScreen(repository: widget.reports!),
                          ),
                        )
                      : null,
                  onSettings: user.isAdmin && widget.settings != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ClinicSettingsScreen(
                              repository: widget.settings!,
                            ),
                          ),
                        )
                      : null,
                  onNotifications: widget.notifications != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => NotificationsScreen(
                              repository: widget.notifications!,
                            ),
                          ),
                        )
                      : null,
                  onStaff: user.isAdmin && widget.staff != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                StaffScreen(repository: widget.staff!),
                          ),
                        )
                      : null,
                  onInventory: user.isAdmin && widget.inventory != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                InventoryScreen(repository: widget.inventory!),
                          ),
                        )
                      : null,
                  onExpenses: user.isAdmin && widget.expenses != null
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                ExpensesScreen(repository: widget.expenses!),
                          ),
                        )
                      : null,
                  onWebsite:
                      widget.website != null &&
                          widget.appointments != null &&
                          widget.catalog != null
                      ? () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => WebsiteBookingsScreen(
                                repository: widget.website!,
                                appointments: widget.appointments!,
                                catalog: widget.catalog!,
                                isAdmin: user.isAdmin,
                              ),
                            ),
                          );
                        }
                      : null,
                  catalog: widget.catalog,
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ElmaColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: List.generate(
                    tabs.length,
                    (i) => Expanded(
                      child: Semantics(
                        selected: _index == i,
                        button: true,
                        label: tabs[i].$1,
                        child: InkWell(
                          onTap: () => setState(() {
                            _index = i;
                            if (i == 0) _homeRevision++;
                            if (i == 3) _paymentRevision++;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElmaIcon(
                                  i == 0 && _index == 0
                                      ? 'HomeActive'
                                      : tabs[i].$2,
                                  color: _index == i
                                      ? ElmaColors.brand
                                      : ElmaColors.muted,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tabs[i].$1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: _index == i
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _index == i
                                        ? ElmaColors.brand
                                        : ElmaColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title, subtitle, icon;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ElmaHeader(title, subtitle: subtitle),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ElmaStatePanel(
            title: 'Bientôt disponible',
            message: 'Cet espace sera disponible prochainement.',
            icon: icon,
          ),
        ),
      ),
    ],
  );
}
