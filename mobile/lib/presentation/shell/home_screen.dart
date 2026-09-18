import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/dashboard/dashboard.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../widgets/appointment_card.dart';
import '../widgets/elma_equal_rows.dart';
import 'more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onTab,
    this.repository,
    this.refreshToken = 0,
    this.onCreateAppointment,
    this.onAppointment,
    this.onReports,
  });
  final AppUser user;
  final int refreshToken;
  final ValueChanged<int> onTab;
  final DashboardRepository? repository;
  final Future<void> Function()? onCreateAppointment;
  final Future<void> Function(String)? onAppointment;
  final VoidCallback? onReports;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Dashboard? _data;
  Object? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.repository == null) {
        throw const AppFailure(
          'Les données de la clinique sont indisponibles.',
        );
      }
      final data = await widget.repository!.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) {
        setState(() {
          _data = null;
          _error = error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAppointment() async {
    if (widget.onCreateAppointment == null) {
      _notice('Nouveau rendez-vous');
      return;
    }
    await widget.onCreateAppointment!();
    if (mounted) await _load();
  }

  Future<void> _openAppointment(String id) async {
    if (widget.onAppointment == null) {
      _notice('Détail du rendez-vous');
      return;
    }
    await widget.onAppointment!(id);
    if (mounted) await _load();
  }

  void _notice(String title) => showElmaNotice(
    context,
    title,
    'Cet espace sera disponible prochainement.',
  );
  void _notifications() {
    final rows = _data?.notifications;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ElmaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Notifications',
                style: ElmaType.display.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              if (rows == null)
                const ElmaStatePanel(
                  title: 'Notifications indisponibles',
                  message: 'Actualisez votre tableau de bord.',
                  icon: 'Bell',
                )
              else if (rows.isEmpty)
                const ElmaStatePanel(
                  title: 'Vous êtes à jour',
                  message: 'Aucune notification pour le moment.',
                  icon: 'Bell',
                )
              else
                ...rows.map(
                  (row) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const ElmaIcon('Bell'),
                    title: Text(
                      row.type == 'WEBSITE_BOOKING'
                          ? 'Nouvelle réservation en ligne'
                          : 'Information de la clinique',
                    ),
                    trailing: row.unread
                        ? const CircleAvatar(
                            radius: 4,
                            backgroundColor: ElmaColors.brand,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    String emoji,
    Color background,
    Color accent,
    VoidCallback onTap,
  ) => Material(
    color: background,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'Noto Color Emoji',
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ElmaColors.secondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = _data;
    final money = NumberFormat.currency(
      locale: 'fr_MA',
      symbol: 'MAD',
      decimalDigits: 2,
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ElmaColors.canvas, Color(0xFFF0F0E8)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data == null
                            ? 'Votre espace clinique'
                            : DateFormat(
                                'EEEE d MMMM yyyy',
                                'fr',
                              ).format(data.date),
                        style: const TextStyle(
                          fontSize: 13,
                          color: ElmaColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bonjour, ${widget.user.name.trim().split(' ').first}',
                        style: ElmaType.display,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: _notifications,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: ElmaColors.border),
                  ),
                  icon: const ElmaIcon('Bell', size: 18),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Mon compte',
                  onPressed: () => widget.onTab(4),
                  style: IconButton.styleFrom(
                    backgroundColor: ElmaColors.brand,
                  ),
                  icon: Text(
                    initials(widget.user.name),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const ElmaStatePanel(
                    title: 'Chargement de votre journée',
                    message: 'Un instant…',
                    loading: true,
                  )
                else if (_error != null)
                  ElmaStatePanel(
                    title: 'Connexion indisponible',
                    message: friendlyError(_error!),
                    icon: 'Refresh',
                    onRetry: _load,
                  )
                else if (data != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) => ElmaEqualRows(
                      children: [
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _metric(
                            'Rendez-vous aujourd’hui',
                            '${data.appointments}',
                            '📅',
                            ElmaColors.light,
                            ElmaColors.brand,
                            () => widget.onTab(1),
                          ),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _metric(
                            'Chiffre du jour',
                            data.revenueCentimes == null
                                ? '—'
                                : money.format(data.revenueCentimes! / 100),
                            '💰',
                            ElmaColors.greenLight,
                            ElmaColors.green,
                            () => widget.onTab(3),
                          ),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _metric(
                            'Clients total',
                            '${data.clients}',
                            '👤',
                            ElmaColors.blueLight,
                            ElmaColors.blue,
                            () => widget.onTab(2),
                          ),
                        ),
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _metric(
                            'En attente',
                            '${data.pending}',
                            '⏳',
                            ElmaColors.amberLight,
                            ElmaColors.amber,
                            () => widget.onTab(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.websiteNew > 0) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ElmaColors.blueLight,
                        border: Border.all(
                          color: ElmaColors.blue.withValues(alpha: .35),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                '🌐',
                                style: TextStyle(
                                  fontFamily: 'Noto Color Emoji',
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Réservations en ligne',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ElmaColors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'elmaclinic.ma · ${data.websiteNew} nouvelle(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ElmaColors.blue,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _notice('Réservations en ligne'),
                            child: const Text('Voir les réservations'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                ElmaButton(
                  label: 'Nouveau rendez-vous',
                  icon: 'Plus',
                  onPressed: _createAppointment,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Programme du jour',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onTab(1),
                      child: const Row(
                        children: [
                          Text('Tout voir', style: TextStyle(fontSize: 13)),
                          ElmaIcon('ChevronRight', size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_loading && _error == null && data != null) ...[
                  if (data.schedule.isEmpty)
                    const ElmaStatePanel(
                      title: 'Votre agenda est libre',
                      message: 'Aucun rendez-vous prévu aujourd’hui.',
                    )
                  else
                    ...data.schedule.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppointmentCard(
                          entry: entry,
                          onTap: () => _openAppointment(entry.id),
                        ),
                      ),
                    ),
                  if (data.week.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: ElmaColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recettes — Cette semaine',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total : ${money.format(data.week.fold<int>(0, (sum, day) => sum + day.centimes) / 100)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ElmaColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (data.week.every((day) => day.centimes == 0))
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Aucun encaissement cette semaine.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ElmaColors.muted,
                                  ),
                                ),
                              ),
                            )
                          else
                            RevenueChart(days: data.week),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                const Text(
                  'Actions rapides',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final action in [
                        ('Rendez-vous', 'Calendar', 1),
                        ('Client', 'User', 2),
                        ('En ligne', 'Bell', 4),
                        if (widget.user.isAdmin) ('Rapports', 'BarChart', 4),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 24) / 4,
                          child: Material(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: ElmaColors.border),
                            ),
                            child: InkWell(
                                onTap: () => action.$1 == 'Rapports'
                                  ? widget.onReports?.call()
                                  : action.$1 == 'En ligne'
                                  ? _notice(action.$1)
                                  : widget.onTab(action.$3),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 12,
                                ),
                                child: Column(
                                  children: [
                                    ElmaIcon(action.$2, size: 24),
                                    const SizedBox(height: 8),
                                    Text(
                                      action.$1,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: ElmaColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key, required this.days});
  final List<RevenueDay> days;
  @override
  Widget build(BuildContext context) {
    final max = days.fold<int>(
      1,
      (value, day) => day.centimes > value ? day.centimes : value,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days
          .map(
            (day) => Expanded(
              child: Semantics(
                label:
                    '${DateFormat('EEEE', 'fr').format(day.date)} : ${day.centimes / 100} MAD',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        height: 90 * day.centimes / max,
                        decoration: const BoxDecoration(
                          color: ElmaColors.light,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEEE', 'fr').format(day.date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: ElmaColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
