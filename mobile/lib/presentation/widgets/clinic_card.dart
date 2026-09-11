import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ClinicCard extends StatelessWidget {
  const ClinicCard({super.key, required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(ElmaSpace.lg),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      border: Border.all(color: ElmaColors.border),
    ),
    child: child,
  );
}

class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.spa_outlined,
  });
  final String title;
  final String description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ClinicCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTokens.mint,
              child: Icon(icon, size: 30, color: AppTokens.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTokens.muted, height: 1.6),
            ),
            const SizedBox(height: 18),
            const Chip(label: Text('Bientôt disponible')),
          ],
        ),
      ),
    ),
  );
}
