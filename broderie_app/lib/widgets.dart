import 'package:flutter/material.dart';

import 'data/app_data.dart';
import 'data/models.dart';
import 'theme.dart';
import 'utils.dart';
import 'i18n.dart';

/// Carte de base : surface, bordure fine, coins arrondis.
/// Sur PC, une carte cliquable se soulève et s'illumine d'or au survol.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.gradient});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(18);
    final actif = _hover && widget.onTap != null;
    final dark = context.isDark;
    return MouseRegion(
      onEnter: widget.onTap == null ? null : (_) => setState(() => _hover = true),
      onExit: widget.onTap == null ? null : (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, actif ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            if (actif) BoxShadow(color: AppColors.gold.withValues(alpha: dark ? 0.16 : 0.18), blurRadius: 26, offset: const Offset(0, 10)),
            dark
                ? BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))
                : BoxShadow(color: const Color(0xFF6E5216).withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: widget.gradient == null ? context.cs.surface : null,
              gradient: widget.gradient,
              borderRadius: r,
              border: Border.all(
                color: widget.gradient != null || actif ? AppColors.gold.withValues(alpha: actif ? 0.6 : 0.35) : context.pal.line,
              ),
            ),
            child: InkWell(
              borderRadius: r,
              onTap: widget.onTap,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 4,
            height: subtitle == null ? 20 : 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleMedium),
              if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Sélecteur de période en pastilles + plage personnalisée.
class PeriodChips extends StatelessWidget {
  final Periode periode;
  final DateTimeRange? custom;
  final void Function(Periode p, DateTimeRange? custom) onChanged;
  final List<Periode> choices;
  const PeriodChips({
    super.key,
    required this.periode,
    required this.custom,
    required this.onChanged,
    this.choices = Periode.values,
  });

  @override
  Widget build(BuildContext context) {
    final r = rangeFor(periode, custom);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final p in choices)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p == Periode.personnalisee && periode == p ? '${fmtShort(r.start)} – ${fmtShort(r.end)}' : p.label),
                avatar: p == Periode.personnalisee ? const Icon(Icons.date_range, size: 18) : null,
                selected: p == periode,
                selectedColor: context.cs.primary,
                labelStyle: TextStyle(
                  color: p == periode ? context.cs.onPrimary : context.cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) async {
                  if (p == Periode.personnalisee) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: custom ?? rangeFor(Periode.mois, null),
                    );
                    if (picked != null) onChanged(p, picked);
                  } else {
                    onChanged(p, custom);
                  }
                },
              ),
            ),
        ]),
      ),
      if (periode != Periode.tout && periode != Periode.personnalisee)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            r.start == r.end ? fmtDateLong(r.start) : 'Du {0} au {1}'.trf([fmtDate(r.start), fmtDate(r.end)]),
            style: context.tt.bodySmall?.copyWith(color: context.pal.muted),
          ),
        ),
    ]);
  }
}

/// Liste déroulante « Tous les ouvriers / un ouvrier ».
class OuvrierFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const OuvrierFilter({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 260,
        child: DropdownButtonFormField<String?>(
          value: data.ouvrier(value) == null ? null : value,
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_search_outlined)),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('Tous les ouvriers'.tr)),
            for (final o in data.ouvriers) DropdownMenuItem<String?>(value: o.id, child: Text(o.nom)),
          ],
          onChanged: onChanged,
        ),
      );
}

/// Indicateur chiffré avec icône colorée.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color, this.sub});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.10)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            if (sub != null)
              Flexible(
                child: Text(sub!, overflow: TextOverflow.ellipsis, style: context.tt.labelSmall?.copyWith(color: context.pal.muted)),
              ),
          ]),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.tt.headlineSmall),
          ),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: context.tt.labelSmall?.copyWith(color: context.pal.muted, letterSpacing: 0.8, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(height: 2.5, width: 34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ]),
      );
}

/// Grille responsive : nombre de colonnes selon la largeur disponible.
class AutoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  const AutoGrid({super.key, required this.children, this.minItemWidth = 170, this.spacing = 12});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 6);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      });
}

/// Avatar coloré avec initiales.
class NameAvatar extends StatelessWidget {
  final String name;
  final double size;
  const NameAvatar(this.name, {super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forName(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(initials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

String initials(String nom) {
  final parts = nom.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts[0].characters.first + parts[1].characters.first).toUpperCase();
}

/// Vignette d'un dessin : photo si disponible, sinon motif coloré.
class DessinThumb extends StatelessWidget {
  final Dessin? dessin;
  final double size;
  final double radius;
  const DessinThumb(this.dessin, {super.key, this.size = 48, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    final d = dessin;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.forName(d?.nom ?? '?').withValues(alpha: 0.85), AppColors.violetDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.local_florist_outlined, color: Colors.white, size: size * 0.45),
    );
    if (d?.photoPath == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<String?>(
          future: data.photoUrl(d!.photoPath),
          builder: (context, snap) {
            final url = snap.data;
            if (url == null) {
              return snap.connectionState == ConnectionState.done
                  ? fallback
                  : Container(color: context.pal.surface2);
            }
            return Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (c, child, p) => p == null ? child : Container(color: context.pal.surface2),
            );
          },
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  final Widget? action;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: context.cs.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: context.cs.primary),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorBanner(this.message, {super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: context.cs.errorContainer, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.cloud_off, color: context.cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: context.cs.onErrorContainer))),
          TextButton(onPressed: onRetry, child: Text('Réessayer'.tr)),
        ]),
      );
}

/// Barre de progression arrondie.
class Bar extends StatelessWidget {
  final double value;
  final Color color;
  const Bar(this.value, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 8,
          color: color,
          backgroundColor: context.pal.surface2,
        ),
      );
}

// ====================================================================== navigation « retour »

/// Indique si la page (dans la pile des pages principales) est celle affichée.
class PageActive extends InheritedWidget {
  final bool actif;
  const PageActive({super.key, required this.actif, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PageActive>()?.actif ?? true;

  @override
  bool updateShouldNotify(PageActive old) => old.actif != actif;
}

/// Gestionnaires de retour internes (onglets, vues) : le plus récent passe en premier.
class Retours {
  Retours._();
  static final _gestionnaires = <bool Function()>[];
  static final _peut = <bool Function()>[];

  /// Change à chaque fois qu'un « retour » devient possible ou non (pour afficher le bouton).
  static final version = ValueNotifier<int>(0);

  static void inscrire(bool Function() peutRevenir, bool Function() revenir) {
    _peut.add(peutRevenir);
    _gestionnaires.add(revenir);
    signaler();
  }

  static void desinscrire(bool Function() peutRevenir, bool Function() revenir) {
    _peut.remove(peutRevenir);
    _gestionnaires.remove(revenir);
    signaler();
  }

  static void signaler() => WidgetsBinding.instance.addPostFrameCallback((_) => version.value++);

  static bool get peutRevenir => _peut.any((f) => f());

  /// Essaie de revenir en arrière dans un onglet/une vue ; true si c'est fait.
  static bool revenir() {
    for (var i = _gestionnaires.length - 1; i >= 0; i--) {
      if (_peut[i]() && _gestionnaires[i]()) return true;
    }
    return false;
  }
}
