import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/couture.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'coupe_screen.dart' show PaquetDetailScreen, PuceEtape, couleurEtape, iconeEtape;

/// Tableau de suivi de la production (administrateur) : où sont les paquets, retards,
/// production du mois, entrées au stock par modèle, durée des paquets, meilleurs ouvriers.
class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _Retard {
  final Lot l;
  final int jours, limite;
  const _Retard(this.l, this.jours, this.limite);
}

class _SuiviScreenState extends State<SuiviScreen> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  bool _charge = false;
  Map<String, List<(MouvementLot, String)>> _mvts = {};
  List<Production> _prod = [];
  List<Piece> _pieces = [];

  DateTime get _debut => _mois;
  DateTime get _fin => DateTime(_mois.year, _mois.month + 1, 0);
  bool _dansMois(DateTime? d) => d != null && !dayOnly(d).isBefore(_debut) && !dayOnly(d).isAfter(_fin);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _charge = false);
    try {
      final r = await Future.wait([
        data.fetchTousMouvements(),
        data.fetchProduction(_debut, _fin),
        data.fetchPieces(_debut, _fin),
      ]);
      _mvts = r[0] as Map<String, List<(MouvementLot, String)>>;
      _prod = r[1] as List<Production>;
      _pieces = r[2] as List<Piece>;
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _charge = true);
  }

  /// Date d'arrivée du paquet à son étape actuelle.
  DateTime _arrivee(Lot l) {
    final m = _mvts[l.id];
    if (m != null) {
      for (final x in m.reversed) {
        if (x.$1.vers == l.etape) return x.$1.date;
      }
    }
    return l.dateCoupe ?? l.createdAt;
  }

  void _changerMois(int d) {
    setState(() => _mois = DateTime(_mois.year, _mois.month + d));
    _charger();
  }

  Future<void> _reglerDelais() async {
    final a = session.atelier;
    if (a == null) return;
    final etapes = ['coupe', 'broderie', 'applique', 'akkach', 'couture', 'finition'];
    final ctrls = {for (final e in etapes) e: TextEditingController(text: '${a.delais[e] ?? 5}')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Délais normaux par atelier (jours)'.tr),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in etapes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrls[e],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, labelText: etapeNom(e), prefixIcon: Icon(iconeEtape(e), color: couleurEtape(e)), suffixText: 'j'.tr),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await session.saveAtelier({
        'delais': {for (final e in etapes) e: (parseInt(ctrls[e]!.text) ?? a.delais[e] ?? 5).clamp(1, 365)},
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data, couture, session]),
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          final delais = session.atelier?.delais ?? Atelier.delaisParDefaut;
          final actifs = data.lots.where((l) => l.etape != 'stock').toList();

          // retards
          final retards = <_Retard>[];
          if (_charge) {
            for (final l in actifs) {
              final lim = delais[l.etape] ?? 7;
              final j = dayOnly(DateTime.now()).difference(dayOnly(_arrivee(l))).inDays;
              if (j > lim) retards.add(_Retard(l, j, lim));
            }
            retards.sort((a, b) => (b.jours - b.limite).compareTo(a.jours - a.limite));
          }

          // production du mois
          final coupees = data.lots.where((l) => _dansMois(l.dateCoupe)).fold<int>(0, (s, l) => s + l.nbPieces);
          final brodees = _prod.fold<int>(0, (s, p) => s + (p.nbRobes ?? 0));
          var cousues = 0;
          for (final e in couture.envois) {
            for (final r in e.retours) {
              if (_dansMois(r.date)) cousues += r.bonnes;
            }
          }
          final auStock = data.lots.where((l) => l.etape == 'stock' && _dansMois(l.dateStock)).toList();
          final pStock = auStock.fold<int>(0, (s, l) => s + (l.piecesStock ?? l.nbPieces));
          final parModele = <String, int>{};
          for (final l in auStock) {
            parModele.update(l.modele ?? 'Sans modèle'.tr, (v) => v + (l.piecesStock ?? l.nbPieces), ifAbsent: () => l.piecesStock ?? l.nbPieces);
          }

          // durée totale coupe → stock
          final finis = data.lots.where((l) => l.etape == 'stock' && l.dateStock != null && l.dateCoupe != null).toList()
            ..sort((a, b) => b.dateStock!.compareTo(a.dateStock!));
          int duree(Lot l) => dayOnly(l.dateStock!).difference(dayOnly(l.dateCoupe!)).inDays;
          final moyenne = finis.isEmpty ? 0.0 : finis.fold<int>(0, (s, l) => s + duree(l)) / finis.length;

          // meilleurs ouvriers du mois
          final parDep = <String, Map<String, double>>{};
          for (final p in _pieces) {
            final dep = data.ouvrier(p.ouvrierId)?.departement ?? '—';
            parDep.putIfAbsent(dep, () => {}).update(p.ouvrierId, (v) => v + p.quantite, ifAbsent: () => p.quantite);
          }
          final points = <String, double>{};
          for (final p in _prod) {
            points.update(p.ouvrierId, (v) => v + p.totalPoints, ifAbsent: () => p.totalPoints.toDouble());
          }

          Widget top(String titre, Map<String, double> m, String unite) {
            final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            return AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                for (var i = 0; i < l.length && i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text(['🥇', '🥈', '🥉'][i]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(data.ouvrierNom(l[i].key), overflow: TextOverflow.ellipsis)),
                      Text('${fmtInt(l[i].value)} $unite', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
            );
          }

          return RefreshIndicator(
            onRefresh: () => Future.wait([_charger(), data.loadLots(), couture.load()]),
            child: ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 40), children: [
              // ------------------------------------------------ où sont les paquets
              SectionTitle('Où sont les paquets'.tr, subtitle: '{0} paquets · {1} pièces dans l\'atelier'.trf([actifs.length, fmtInt(actifs.fold<int>(0, (s, l) => s + l.nbPieces))])),
              const SizedBox(height: 8),
              AutoGrid(minItemWidth: 150, children: [
                for (final e in etapesAtelier.where((e) => e != 'stock'))
                  StatTile(
                    label: etapeNom(e),
                    value: '${actifs.where((l) => l.etape == e).length}',
                    icon: iconeEtape(e),
                    color: couleurEtape(e),
                    sub: '{0} pièces'.trf([fmtInt(actifs.where((l) => l.etape == e).fold<int>(0, (s, l) => s + l.nbPieces))]),
                  ),
              ]),

              // ------------------------------------------------ retards
              const SizedBox(height: 20),
              SectionTitle(
                'Paquets en retard'.tr,
                subtitle: _charge ? '{0} paquet(s) au-delà du délai normal'.trf([retards.length]) : null,
                trailing: TextButton.icon(onPressed: _reglerDelais, icon: const Icon(Icons.tune_rounded), label: Text('Délais'.tr)),
              ),
              const SizedBox(height: 8),
              if (!_charge)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else if (retards.isEmpty)
                EmptyState('Aucun retard. 👍'.tr, icon: Icons.check_circle_outline_rounded)
              else
                AutoGrid(minItemWidth: 300, children: [
                  for (final r in retards)
                    AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: r.l.id))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('#${r.l.numero}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('{0} jours (normal : {1})'.trf([r.jours, r.limite]), style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
                            if (r.l.modele != null) Text(r.l.modele!, style: TextStyle(color: muted)),
                          ]),
                        ),
                        PuceEtape(r.l.etape),
                      ]),
                    ),
                ]),

              // ------------------------------------------------ production du mois
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: SectionTitle('Production du mois'.tr)),
                IconButton(onPressed: () => _changerMois(-1), icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_right : Icons.chevron_left)),
                Text(fmtMonthYear(_mois), style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: _mois.isBefore(DateTime(DateTime.now().year, DateTime.now().month)) ? () => _changerMois(1) : null,
                  icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right),
                ),
              ]),
              const SizedBox(height: 8),
              AutoGrid(minItemWidth: 170, children: [
                StatTile(label: 'Pièces coupées'.tr, value: fmtInt(coupees), icon: iconeEtape('coupe'), color: couleurEtape('coupe')),
                StatTile(label: 'Pièces brodées'.tr, value: fmtInt(brodees), icon: iconeEtape('broderie'), color: couleurEtape('broderie')),
                StatTile(label: 'Rendues par la couture'.tr, value: fmtInt(cousues), icon: iconeEtape('couture'), color: couleurEtape('couture')),
                StatTile(label: 'Entrées au stock'.tr, value: fmtInt(pStock), icon: iconeEtape('stock'), color: couleurEtape('stock')),
              ]),
              if (parModele.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Entrées au stock par modèle'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in (parModele.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                    Chip(avatar: const Icon(Icons.checkroom_rounded, size: 16), label: Text('${e.key} : ${fmtInt(e.value)}')),
                ]),
              ],

              // ------------------------------------------------ meilleurs ouvriers
              if (_charge && (parDep.isNotEmpty || points.isNotEmpty)) ...[
                const SizedBox(height: 20),
                SectionTitle('Meilleurs ouvriers du mois'.tr),
                const SizedBox(height: 8),
                AutoGrid(minItemWidth: 260, children: [
                  if (points.isNotEmpty) top('Broderie'.tr, points, 'pts'.tr),
                  for (final e in parDep.entries) top(e.key, e.value, 'pcs'.tr),
                ]),
              ],

              // ------------------------------------------------ durée des paquets
              const SizedBox(height: 20),
              SectionTitle('Durée de la coupe au stock'.tr,
                  subtitle: finis.isEmpty ? null : 'Moyenne : {0} jours sur {1} paquets'.trf([moyenne.toStringAsFixed(1), finis.length])),
              const SizedBox(height: 8),
              if (finis.isEmpty)
                EmptyState('Aucun paquet terminé pour l\'instant.'.tr, icon: Icons.timer_outlined)
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    for (final l in finis.take(15))
                      ListTile(
                        dense: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: l.id))),
                        title: Text('#${l.numero}${l.modele == null ? '' : ' · ${l.modele}'}'),
                        subtitle: Text('{0} → {1}'.trf([fmtDate(l.dateCoupe!), fmtDate(l.dateStock!)])),
                        trailing: Text('{0} j'.trf([duree(l)]),
                            style: TextStyle(fontWeight: FontWeight.w800, color: duree(l) > moyenne ? AppColors.rose : AppColors.green)),
                      ),
                  ]),
                ),
            ]),
          );
        },
      );
}
