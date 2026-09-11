import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// The Make SVG is a raster image in a pattern: viewBox 125×184,
/// source offset -345px. Flutter SVG does not support this pattern fill.
/// Preserve its exact crop using the original PNG, without redrawing the logo.
class ElmaBrandMark extends StatelessWidget {
  const ElmaBrandMark({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: ClipRect(
      child: SizedBox(
        width: 125,
        height: 184,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxWidth: 816,
          maxHeight: 306,
          child: Transform.translate(
            offset: const Offset(-345, 0),
            child: Image.asset(
              'assets/branding/logo.png',
              width: 816,
              height: 306,
              semanticLabel: 'ELMA Clinic',
            ),
          ),
        ),
      ),
    ),
  );
}

class ElmaIcon extends StatelessWidget {
  const ElmaIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color = ElmaColors.secondary,
  });
  final String name;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/${name.endsWith('Active') ? '${name.substring(0, name.length - 6)}IconActive' : '${name}Icon'}.svg',
    width: size,
    height: size,
    theme: SvgTheme(currentColor: color),
  );
}

class ElmaButton extends StatelessWidget {
  const ElmaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? icon;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: ElmaDecor.brand,
      borderRadius: BorderRadius.circular(ElmaRadii.control),
      boxShadow: ElmaDecor.buttonShadow,
    ),
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: ElmaColors.muted,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ElmaRadii.control),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                semanticsLabel: 'Chargement',
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  ElmaIcon(icon!, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class ElmaFilterChip extends StatelessWidget {
  const ElmaFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: label,
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    selectedColor: ElmaColors.brand,
    backgroundColor: ElmaColors.surface,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: selected ? Colors.white : ElmaColors.secondary,
    ),
  );
}

class ElmaCompactButton extends StatelessWidget {
  const ElmaCompactButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: ElmaDecor.brand,
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ElmaIcon('Plus', size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class ElmaHeader extends StatelessWidget {
  const ElmaHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.leading,
    this.titleStyle,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final TextStyle? titleStyle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: ElmaColors.border)),
    ),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: titleStyle ?? ElmaType.display.copyWith(fontSize: 22),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 13, color: ElmaColors.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class ElmaStatePanel extends StatelessWidget {
  const ElmaStatePanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = 'Calendar',
    this.onRetry,
    this.loading = false,
  });
  final String title, message, icon;
  final VoidCallback? onRetry;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ElmaColors.border),
      borderRadius: BorderRadius.circular(ElmaRadii.card),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          ElmaIcon(icon, size: 28, color: ElmaColors.brand),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: ElmaColors.muted),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}

Future<void> showElmaNotice(
  BuildContext context,
  String title,
  String message,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ElmaColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: ElmaType.display.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ElmaColors.secondary),
          ),
          const SizedBox(height: 24),
          ElmaButton(label: 'Fermer', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  ),
);
