import 'package:flutter/material.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import '../../domain/catalog/catalog.dart';
import '../catalog/catalog_screen.dart';

String initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part.characters.first)
    .join()
    .toUpperCase();

class MoreScreen extends StatefulWidget {
  const MoreScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.catalog,
    this.onWebsite,
    this.onExpenses,
    this.onInventory,
    this.onStaff,
    this.onSettings,
    this.onReports,
    this.onActivity,
    this.onPacks,
    this.onNotifications,
  });
  final AppUser user;
  final CatalogRepository? catalog;
  final VoidCallback? onWebsite;
  final VoidCallback? onExpenses;
  final VoidCallback? onInventory;
  final VoidCallback? onStaff;
  final VoidCallback? onSettings;
  final VoidCallback? onReports;
  final VoidCallback? onActivity;
  final VoidCallback? onPacks;
  final VoidCallback? onNotifications;
  final Future<void> Function() onLogout;
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _loggingOut = false;
  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await widget.onLogout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _entry(
    String label,
    String subtitle,
    String icon,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ElmaColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (label == 'Packs' && widget.onPacks != null) {
            widget.onPacks!();
            return;
          }
          if (label == 'Journal d’activité' &&
              widget.user.isAdmin &&
              widget.onActivity != null) {
            widget.onActivity!();
            return;
          }
          if (label == 'Rapports' &&
              widget.user.isAdmin &&
              widget.onReports != null) {
            widget.onReports!();
            return;
          }
          if (label == 'Paramètres' &&
              widget.user.isAdmin &&
              widget.onSettings != null) {
            widget.onSettings!();
            return;
          }
          if (label == 'Notifications' && widget.onNotifications != null) {
            widget.onNotifications!();
            return;
          }
          if (label == 'Utilisateurs' &&
              widget.user.isAdmin &&
              widget.onStaff != null) {
            widget.onStaff!();
            return;
          }
          if (label == 'Inventaire' &&
              widget.user.isAdmin &&
              widget.onInventory != null) {
            widget.onInventory!();
            return;
          }
          if (label == 'Dépenses' &&
              widget.user.isAdmin &&
              widget.onExpenses != null) {
            widget.onExpenses!();
            return;
          }
          if (label == 'Réservations en ligne' && widget.onWebsite != null) {
            widget.onWebsite!();
            return;
          }
          final kind = label == 'Prestations'
              ? CatalogKind.services
              : label == 'Praticiennes'
              ? CatalogKind.practitioners
              : null;
          if (kind != null && widget.catalog != null) {
            Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => CatalogScreen(
                  kind: kind,
                  repository: widget.catalog!,
                  isAdmin: widget.user.isAdmin,
                  standalone: true,
                ),
              ),
            );
          } else {
            showElmaNotice(
              context,
              label,
              'Cet espace sera disponible prochainement.',
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: ElmaIcon(icon)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ElmaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ElmaIcon('ChevronRight', size: 16, color: ElmaColors.faint),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 10),
    child: Text(text.toUpperCase(), style: ElmaType.label),
  );
  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListView(
      children: [
        ElmaHeader(
          'Plus',
          subtitle: 'ELMA Clinic — Gestion complète',
          trailing: user.isAdmin
              ? const Chip(
                  label: Text(
                    'Admin',
                    style: TextStyle(fontSize: 11, color: ElmaColors.brand),
                  ),
                  backgroundColor: ElmaColors.light,
                  side: BorderSide.none,
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEEEE4), Color(0xFFE4E4D4)],
                  ),
                  border: Border.all(color: ElmaColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const ElmaBrandMark(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ELMA Clinic',
                            style: ElmaType.display.copyWith(fontSize: 16),
                          ),
                          const Text(
                            'Laser · Skincare · Aesthetics',
                            style: TextStyle(
                              fontSize: 12,
                              color: ElmaColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Kenitra, Maroc · MAD',
                            style: TextStyle(
                              fontSize: 11,
                              color: ElmaColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _label('Gestion'),
              _entry(
                'Packs',
                'Prestations et séances',
                'Grid',
                ElmaColors.light,
              ),
              _entry(
                'Réservations en ligne',
                'Demandes du site web',
                'Calendar',
                ElmaColors.blueLight,
              ),
              _entry(
                'Prestations',
                user.isAdmin
                    ? 'Catalogue et tarifs'
                    : 'Consultation uniquement',
                'Tag',
                ElmaColors.light,
              ),
              _entry(
                'Praticiennes',
                user.isAdmin
                    ? 'Équipe et disponibilités'
                    : 'Consultation uniquement',
                'Users',
                ElmaColors.light,
              ),
              if (user.isAdmin) ...[
                _entry(
                  'Dépenses',
                  'Gérer les charges',
                  'AlertTriangle',
                  const Color(0xFFE8E4DC),
                ),
                _entry(
                  'Inventaire',
                  'Produits et mouvements de stock',
                  'Package',
                  const Color(0xFFE8DCE4),
                ),
                _entry(
                  'Rapports',
                  'Recettes et activité',
                  'BarChart',
                  ElmaColors.greenLight,
                ),
                _label('Administration'),
                _entry(
                  'Utilisateurs',
                  'Comptes et autorisations',
                  'User',
                  ElmaColors.blueLight,
                ),
                _entry(
                  'Journal d’activité',
                  'Historique des opérations',
                  'Clock',
                  ElmaColors.light,
                ),
                _entry(
                  'Paramètres',
                  'Clinique, horaires et intégrations',
                  'Settings',
                  ElmaColors.border,
                ),
              ] else
                _entry(
                  'Notifications',
                  'Les informations de votre journée',
                  'Bell',
                  ElmaColors.light,
                ),
              _label('Compte'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ElmaColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: ElmaDecor.brand,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              initials(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: ElmaColors.muted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user.isAdmin
                                      ? 'Administrateur'
                                      : 'Utilisateur',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ElmaColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    TextButton(
                      onPressed: _loggingOut ? null : _logout,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const ElmaIcon(
                              'LogOut',
                              color: ElmaColors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _loggingOut ? 'Déconnexion…' : 'Se déconnecter',
                              style: const TextStyle(color: ElmaColors.red),
                            ),
                          ],
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
    );
  }
}
