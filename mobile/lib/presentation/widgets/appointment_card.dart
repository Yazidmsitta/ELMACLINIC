import 'package:flutter/material.dart';
import '../../domain/dashboard/dashboard.dart';
import '../theme/app_theme.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.entry, required this.onTap});
  final ScheduleEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: ElmaColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(
                    entry.time,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${entry.duration}min',
                    style: const TextStyle(
                      fontSize: 10,
                      color: ElmaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: ElmaColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.client,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    entry.service,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ElmaColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppointmentStatusBadge(entry.status),
                      AppointmentSourceBadge(entry.source),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppointmentSourceBadge extends StatelessWidget {
  const AppointmentSourceBadge(this.source, {super.key});
  final String source;
  @override
  Widget build(BuildContext context) => _Badge(
    source == 'WEBSITE' ? 'Site web' : 'Manuel',
    source == 'WEBSITE' ? ElmaColors.blue : ElmaColors.brand,
    source == 'WEBSITE' ? ElmaColors.blueLight : ElmaColors.light,
  );
}

class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      'NEW' => ('Nouveau', ElmaColors.statusNew, ElmaColors.blueLight),
      'PENDING' => (
        'En attente',
        ElmaColors.statusPending,
        ElmaColors.amberLight,
      ),
      'CONFIRMED' => ('Confirmé', ElmaColors.green, ElmaColors.greenLight),
      'IN_PROGRESS' => ('En cours', ElmaColors.purple, ElmaColors.purpleLight),
      'CANCELLED' => ('Annulé', ElmaColors.red, ElmaColors.redLight),
      'NO_SHOW' => ('Absent', ElmaColors.absent, ElmaColors.absentLight),
      _ => ('Terminé', ElmaColors.completed, ElmaColors.completedLight),
    };
    return _Badge(style.$1, style.$2, style.$3);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, this.background);
  final String label;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}
