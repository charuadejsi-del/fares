import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'ouvrier_detail_screen.dart';
import 'paie_forms.dart';
import 'refs_screens.dart' show FormDialog;
import '../i18n.dart';

/// Ouvriers dont on saisit le travail ici : tous sauf les brodeurs payés aux points
/// (limités aux [departements] d'un atelier si précisé).
List<Ouvrier> _ouvriersTravail([List<String>? departements]) => data.ouvriers
    .where((o) => o.actif && !o.brodeur)
    .where((o) => departements == null || departements.any((d) => d.toLowerCase() == o.departement.toLowerCase()))
    .toList()
  ..sort((a, b) {
    final d = a.departement.compareTo(b.departement);
    return d != 0 ? d : a.nom.compareTo(b.nom);
  });

String _q(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ====================================================================== saisie du travail

class _LigneTravailLot {
  String? lotId;
  final pieces = TextEditingController();
}

class TravauxSaisieScreen extends StatefulWidget {
  /// Départements des ouvriers proposés (null : tous).
  final List<String>? departements;

  /// Étapes dont on peut choisir les paquets (null : tous les paquets hors stock).
  final List<String>? etapes;
  const TravauxSaisieScreen({super.key, this.departements, this.etapes});

  @override
  State<TravauxSaisieScreen> createState() => _TravauxSaisieScreenState();
}

class _TravauxSaisieScreenState extends State<TravauxSaisieScreen> {
  String? _ouvrierId;
  Tache? _tache;
  bool _extra = false;
  DateTime _date = dayOnly(DateTime.now());
  final _libelle = TextEditingController();
  final _qte = TextEditingController();
  final _prix = TextEditingController();
  bool _busy = false;
  List<Piece> _jour = [];
  int _seen = -1;
  final List<_LigneTravailLot> _lignes = [];

  Ouvrier? get _o => data.ouvrier(_ouvrierId);
  bool get _auMois => _o?.modePaie == ModePaie.mois;
  List<_LigneTravailLot> get _lignesValides => _lignes.where((l) => l.lotId != null && (parseInt(l.pieces.text) ?? 0) > 0).toList();
  bool get _parPaquet => _lignes.any((l) => l.lotId != null);
  double get _qteN => _parPaquet ? _lignesValides.fold<double>(0, (s, l) => s + parseInt(l.pieces.text)!) : (parseNum(_qte.text) ?? 0);
  List<Lot> get _lotsPossibles => data.lots.where((l) => widget.etapes == null ? l.etape != 'stock' : widget.etapes!.contains(l.etape)).toList();
  double get _prixN => _auMois && !_extra ? 0 : (parseNum(_prix.text) ?? 0);

  @override
  void initState() {
    super.initState();
    data.addListener(_onData);
    _qte.addListener(() => setState(() {}));
    _prix.addListener(() => setState(() {}));
    final l = _ouvriersTravail(widget.departements);
    if (l.isNotEmpty) _choisirOuvrier(l.first);
    _chargerJour();
  }

  @override
  void dispose() {
    data.removeListener(_onData);
    _libelle.dispose();
    _qte.dispose();
    _prix.dispose();
    for (final l in _lignes) {
      l.pieces.dispose();
    }
    super.dispose();
  }

  void _onData() {
    if (data.productionVersion != _seen) {
      _chargerJour();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _chargerJour() async {
    _seen = data.productionVersion;
    try {
      final p = await data.fetchPieces(_date, _date);
      if (mounted) setState(() => _jour = p);
    } catch (_) {}
  }

  static String _fmt(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  void _choisirOuvrier(Ouvrier o) {
    _ouvrierId = o.id;
    _extra = false;
    final t = data.tachesPour(o.departement);
    _choisirTache(t.isEmpty ? null : t.first, rebuild: false);
    if (mounted) setState(() {});
  }

  void _choisirTache(Tache? t, {bool rebuild = true}) {
    _tache = t;
    if (t != null) _libelle.text = t.nom;
    if (_libelle.text.trim().isEmpty) _libelle.text = 'Robe'.tr;
    final o = _o;
    if (o != null) _prix.text = _fmt(data.prixTravail(o, t, extra: _extra));
    if (rebuild) setState(() {});
  }

  void _ajouter(int n) {
    _qte.text = _q(_qteN + n);
    HapticFeedback.selectionClick();
  }

  Future<void> _enregistrer() async {
    final o = _o;
    if (o == null) return;
    if (_qteN <= 0) {
      showSnack(context, 'Indiquez la quantité'.tr, error: true);
      return;
    }
    if (_libelle.text.trim().isEmpty) {
      showSnack(context, 'Indiquez le travail'.tr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      Map<String, dynamic> row(double qte, String? lotId) => Piece.toRow(
            ouvrierId: o.id,
            dateKey: dateKey(_date),
            libelle: _libelle.text,
            quantite: qte,
            prixUnitaire: _prixN,
            tacheId: _tache != null && _tache!.nom.trim() == _libelle.text.trim() ? _tache!.id : null,
            note: _auMois && _extra ? 'Extra'.tr : null,
            lotId: lotId,
          );
      final total = _qteN;
      if (_parPaquet) {
        await data.savePieces([for (final l in _lignesValides) row(parseInt(l.pieces.text)!.toDouble(), l.lotId)]);
      } else {
        await data.savePiece(row(total, null));
      }
      if (!mounted) return;
      showSnack(context, '✓ {0} · {1} × {2}{3}'.trf([o.nom, _libelle.text.trim(), _q(total), _prixN > 0 ? ' = ${fmtDA(total * _prixN)}' : ' (sans montant)'.tr]));
      _qte.clear();
      setState(() {
        for (final l in _lignes) {
          l.pieces.dispose();
        }
        _lignes.clear();
      });
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ouvriers = _ouvriersTravail(widget.departements);
    if (ouvriers.isEmpty) {
      return EmptyState(
        'Aucun ouvrier hors broderie.\nAjoutez un ouvrier payé à la pièce ou au mois (Couture, Coupe, Repassage…) dans l\'onglet Équipe.'.tr,
        icon: Icons.groups_outlined,
      );
    }
    final o = _o;
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final choixOuvrier = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('1 · Ouvrier'.tr, subtitle: 'Payés à la pièce, au mois ou en extra'.tr),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final x in ouvriers)
            ChoiceChip(
              avatar: NameAvatar(x.nom, size: 24),
              label: Text('${x.nom} · ${x.departement}'),
              selected: x.id == _ouvrierId,
              onSelected: (_) => _choisirOuvrier(x),
            ),
        ]),
      ]),
    );

    final taches = o == null ? <Tache>[] : data.tachesPour(o.departement);
    final formulaire = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('2 · Travail réalisé'.tr),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in taches)
            ChoiceChip(
              label: Text(t.prix > 0 ? '${t.nom} · ${fmtDA(t.prix)}' : t.nom),
              selected: _tache?.id == t.id && _libelle.text.trim() == t.nom,
              onSelected: (_) => _choisirTache(t),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _libelle,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: 'Travail (modifiable)'.tr, prefixIcon: Icon(Icons.checkroom_rounded)),
        ),
        if (_auMois) ...[
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _extra,
            onChanged: (v) {
              setState(() => _extra = v);
              _prix.text = _fmt(data.prixTravail(o!, _tache, extra: v));
            },
            title: Text('Payé en extra'.tr, style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_extra
                ? 'Montant ajouté en plus de son salaire'.tr
                : '{0} est payé au mois : travail compté sans montant'.trf([o!.nom])),
          ),
        ],
        const SizedBox(height: 12),
        SectionTitle('Paquet(s)'.tr, subtitle: 'Facultatif : relie le travail aux paquets'.tr),
        for (var i = 0; i < _lignes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _lignes[i].lotId,
                  isExpanded: true,
                  decoration: InputDecoration(isDense: true, labelText: 'Paquet'.tr),
                  items: [
                    for (final l in _lotsPossibles.where((l) => l.id == _lignes[i].lotId || !_lignes.any((x) => x.lotId == l.id)))
                      DropdownMenuItem(value: l.id, child: Text('#${l.numero} · ${l.nbPieces} ${'pièces'.tr}${l.modele == null ? '' : ' · ${l.modele}'}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() {
                    _lignes[i].lotId = v;
                    if (_lignes[i].pieces.text.isEmpty) _lignes[i].pieces.text = '${data.lot(v)?.nbPieces ?? ''}';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _lignes[i].pieces,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, labelText: 'pièces'.tr),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _lignes.removeAt(i).pieces.dispose()),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _lotsPossibles.length > _lignes.length ? () => setState(() => _lignes.add(_LigneTravailLot())) : null,
            icon: const Icon(Icons.add_rounded),
            label: Text(_lignes.isEmpty ? 'Ajouter un paquet'.tr : 'Ajouter un autre paquet'.tr),
          ),
        ),
        const SizedBox(height: 12),
        SectionTitle('3 · Quantité'.tr),
        if (_parPaquet)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Total des paquets : {0} pièces'.trf([_q(_qteN)]), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          )
        else
        Row(children: [
          IconButton.filledTonal(
            onPressed: _qteN >= 1 ? () => _ajouter(-1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _qte,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              decoration: InputDecoration(hintText: '0', suffixText: 'pièces'.tr),
              onSubmitted: (_) => _enregistrer(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: () => _ajouter(1), icon: const Icon(Icons.add_rounded)),
        ]),
        const SizedBox(height: 8),
        if (!_parPaquet)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in const [5, 10, 20, 50, 100]) ActionChip(label: Text('+$n'), onPressed: () => _ajouter(n)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (!_auMois || _extra) ...[
            Expanded(
              child: TextField(
                controller: _prix,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Prix / pièce'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.sell_outlined)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) {
                  setState(() => _date = d);
                  _chargerJour();
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: 'Date'.tr, prefixIcon: Icon(Icons.event)),
                child: Text(fmtDate(_date)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(_prixN > 0 ? '{0} × {1}'.trf([_q(_qteN), fmtDA(_prixN)]) : '{0} pièce(s)'.trf([_q(_qteN)]), style: const TextStyle(color: Colors.white70)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_prixN > 0 ? fmtDA(_qteN * _prixN) : 'Sans montant'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            ),
            Text(_prixN > 0 ? 'ajouté à la paie de {0}'.trf([o?.nom ?? '']) : 'travail suivi, payé par le salaire mensuel'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _busy || o == null ? null : _enregistrer,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded),
          label: Text('Enregistrer le travail'.tr),
        ),
      ]),
    );

    final totalJour = _jour.fold<double>(0, (s, p) => s + p.montant);
    final duJour = AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SectionTitle(
            dayOnly(DateTime.now()) == _date ? 'Travail d\'aujourd\'hui'.tr : 'Travail du {0}'.trf([fmtDate(_date)]),
            subtitle: '{0} saisie(s) · {1}'.trf([_jour.length, fmtDA(totalJour)]),
          ),
        ),
        if (_jour.isEmpty)
          EmptyState('Rien de saisi pour ce jour.'.tr, icon: Icons.inventory_2_outlined)
        else
          for (final p in _jour) _LignePiece(p),
      ]),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32),
      children: [
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: Column(children: [choixOuvrier, const SizedBox(height: 16), formulaire])),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: duJour),
          ])
        else ...[
          choixOuvrier,
          const SizedBox(height: 14),
          formulaire,
          const SizedBox(height: 14),
          duJour,
        ],
      ],
    );
  }
}

class _LignePiece extends StatelessWidget {
  final Piece p;
  final bool avecDate;
  const _LignePiece(this.p, {this.avecDate = false});

  @override
  Widget build(BuildContext context) {
    final o = data.ouvrier(p.ouvrierId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: NameAvatar(data.ouvrierNom(p.ouvrierId), size: 38),
      title: Text('${data.ouvrierNom(p.ouvrierId)} · ${p.libelle}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        if (avecDate) fmtDate(p.date),
        '{0} pièce(s)'.trf([_q(p.quantite)]),
        if (p.prixUnitaire > 0) '× {0}'.trf([fmtDA(p.prixUnitaire)]),
        if (p.note?.isNotEmpty ?? false) p.note!,
      ].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(p.montant > 0 ? fmtDA(p.montant) : '—',
            style: TextStyle(fontWeight: FontWeight.w800, color: p.montant > 0 ? AppColors.green : context.pal.muted)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: context.pal.muted),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Modifier'.tr)),
            PopupMenuItem(value: 'fiche', child: Text('Fiche de l\'ouvrier'.tr)),
            PopupMenuItem(value: 'del', child: Text('Supprimer'.tr)),
          ],
          onSelected: (v) async {
            if (v == 'edit' && o != null) {
              openPieceForm(context, o, existing: p);
            } else if (v == 'fiche') {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: p.ouvrierId)));
            } else if (v == 'del') {
              final ok = await confirmDialog(context, 'Supprimer ce travail ?'.tr, '{0} × {1} du {2}'.trf([p.libelle, _q(p.quantite), fmtDate(p.date)]),
                  action: 'Supprimer'.tr);
              if (!ok) return;
              try {
                await data.deletePiece(p.id);
              } catch (e) {
                if (context.mounted) showSnack(context, errorMessage(e), error: true);
              }
            }
          },
        ),
      ]),
    );
  }
}

// ====================================================================== historique & totaux

class TravauxHistoriqueScreen extends StatefulWidget {
  const TravauxHistoriqueScreen({super.key});

  @override
  State<TravauxHistoriqueScreen> createState() => _TravauxHistoriqueScreenState();
}

class _TravauxHistoriqueScreenState extends State<TravauxHistoriqueScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  String? _ouvrierId;
  List<Piece> _pieces = [];
  bool _loading = true;
  String? _err;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    data.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    data.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (data.productionVersion != _seen) _load();
  }

  Future<void> _load() async {
    _seen = data.productionVersion;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = _periode == Periode.tout ? DateTimeRange(start: DateTime(2000), end: dayOnly(DateTime.now())) : rangeFor(_periode, _custom);
      _pieces = await data.fetchPieces(r.start, r.end, ouvrierId: _ouvrierId);
    } catch (e) {
      _err = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final qte = _pieces.fold<double>(0, (s, p) => s + p.quantite);
    final montant = _pieces.fold<double>(0, (s, p) => s + p.montant);
    final parOuvrier = <String, (double, double)>{};
    final parTache = <String, (double, double)>{};
    for (final p in _pieces) {
      final a = parOuvrier[p.ouvrierId] ?? (0, 0);
      parOuvrier[p.ouvrierId] = (a.$1 + p.quantite, a.$2 + p.montant);
      final t = p.libelle.trim();
      final b = parTache[t] ?? (0, 0);
      parTache[t] = (b.$1 + p.quantite, b.$2 + p.montant);
    }
    final ouvTri = parOuvrier.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final tacheTri = parTache.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    Widget resume(String titre, List<MapEntry<String, (double, double)>> l, String Function(String) nom) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(titre),
            if (l.isEmpty) Text('—', style: TextStyle(color: context.pal.muted)),
            for (final e in l)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(nom(e.key), style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('${_q(e.value.$1)} pcs', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: Text(e.value.$2 > 0 ? fmtDA(e.value.$2) : '—',
                          textAlign: TextAlign.right, style: TextStyle(color: e.value.$2 > 0 ? AppColors.green : context.pal.muted)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(minHeight: 5, value: qte == 0 ? 0 : e.value.$1 / l.first.value.$1),
                  ),
                ]),
              ),
          ]),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 32),
      children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PeriodChips(
            periode: _periode,
            custom: _custom,
            choices: const [Periode.aujourdhui, Periode.semaine, Periode.mois, Periode.moisDernier, Periode.tout, Periode.personnalisee],
            onChanged: (p, c) {
              setState(() {
                _periode = p;
                _custom = c;
              });
              _load();
            },
          ),
          DropdownButton<String?>(
            value: _ouvrierId,
            underline: const SizedBox.shrink(),
            hint: Text('Tous les ouvriers'.tr),
            items: [
              DropdownMenuItem(value: null, child: Text('Tous les ouvriers'.tr)),
              for (final o in data.ouvriers.where((o) => !o.brodeur)) DropdownMenuItem(value: o.id, child: Text(o.nom)),
            ],
            onChanged: (v) {
              setState(() => _ouvrierId = v);
              _load();
            },
          ),
        ]),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_err != null) ErrorBanner(_err!, onRetry: _load),
        AutoGrid(minItemWidth: 180, children: [
          StatTile(label: 'Pièces réalisées'.tr, value: _q(qte), icon: Icons.checkroom_rounded, color: AppColors.violet),
          StatTile(label: 'À payer (pièces & extra)'.tr, value: fmtDA(montant), icon: Icons.payments_rounded, color: AppColors.green),
          StatTile(label: 'Ouvriers actifs'.tr, value: '${parOuvrier.length}', icon: Icons.groups_rounded, color: AppColors.gold),
          StatTile(label: 'Saisies'.tr, value: '${_pieces.length}', icon: Icons.receipt_long_rounded, color: AppColors.sky),
        ]),
        const SizedBox(height: 16),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: resume('Par ouvrier'.tr, ouvTri, data.ouvrierNom)),
            const SizedBox(width: 16),
            Expanded(child: resume('Par travail'.tr, tacheTri, (s) => s)),
          ])
        else ...[
          resume('Par ouvrier'.tr, ouvTri, data.ouvrierNom),
          const SizedBox(height: 14),
          resume('Par travail'.tr, tacheTri, (s) => s),
        ],
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: EdgeInsets.only(right: 8), child: SectionTitle('Détail des saisies'.tr)),
            if (_pieces.isEmpty && !_loading)
              EmptyState('Aucun travail sur cette période.'.tr, icon: Icons.inventory_2_outlined)
            else
              for (final p in _pieces.take(300)) _LignePiece(p, avecDate: true),
          ]),
        ),
      ],
    );
  }
}

// ====================================================================== tâches & tarifs

class TachesScreen extends StatelessWidget {
  const TachesScreen({super.key});

  Future<void> _form(BuildContext context, [Tache? t]) =>
      showDialog<void>(context: context, builder: (_) => _TacheForm(existing: t));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final parDep = <String, List<Tache>>{};
          for (final t in data.taches) {
            parDep.putIfAbsent(t.departement, () => []).add(t);
          }
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _form(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvelle tâche'.tr),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: context.cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chaque tâche a son tarif à la pièce. Il est proposé automatiquement lors de la saisie. Tarif 0 : on utilise le prix à la pièce de l\'ouvrier. Les ouvriers payés au mois ne sont payés que pour le travail « en extra ».'.tr,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (data.taches.isEmpty) EmptyState('Aucune tâche. Ajoutez-en une.'.tr, icon: Icons.content_cut_rounded),
                for (final e in parDep.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(e.key.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold, letterSpacing: 1.2)),
                  ),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final t in e.value)
                        ListTile(
                          onTap: () => _form(context, t),
                          leading: Icon(Icons.content_cut_rounded, color: t.actif ? AppColors.gold : context.pal.muted),
                          title: Text(t.nom,
                              style: TextStyle(fontWeight: FontWeight.w700, decoration: t.actif ? null : TextDecoration.lineThrough)),
                          subtitle: Text(t.prix > 0 ? '{0} / pièce'.trf([fmtDA(t.prix)]) : 'Prix de l\'ouvrier'.tr),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _TacheForm extends StatefulWidget {
  final Tache? existing;
  const _TacheForm({this.existing});

  @override
  State<_TacheForm> createState() => _TacheFormState();
}

class _TacheFormState extends State<_TacheForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.existing?.nom ?? '');
  late final _prix = TextEditingController(text: (widget.existing?.prix ?? 0) == 0 ? '' : _q(widget.existing!.prix));
  late String _dep = widget.existing?.departement ?? 'Couture';
  late bool _actif = widget.existing?.actif ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _nom.dispose();
    _prix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveTache(
        Tache.toRow(nom: _nom.text, departement: _dep, prix: parseNum(_prix.text) ?? 0, ordre: widget.existing?.ordre ?? data.taches.length, actif: _actif),
        id: widget.existing?.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e).contains('travail_taches') ? 'Mise à jour de la base en attente (v10).'.tr : errorMessage(e), error: true);
      }
    }
  }

  Future<void> _supprimer() async {
    final t = widget.existing!;
    final ok = await confirmDialog(context, 'Supprimer « {0} » ?'.trf([t.nom]), 'Les travaux déjà saisis sont conservés.'.tr, action: 'Supprimer'.tr);
    if (!ok) return;
    try {
      await data.deleteTache(t.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = {...data.departements.where((d) => d.toLowerCase() != 'broderie'), _dep}.toList();
    return FormDialog(
      title: widget.existing == null ? 'Nouvelle tâche'.tr : 'Modifier la tâche'.tr,
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        TextFormField(
          controller: _nom,
          autofocus: widget.existing == null,
          decoration: InputDecoration(labelText: 'Nom (ex. Robe cousue, Ourlet, Repassage)'.tr, prefixIcon: Icon(Icons.content_cut_rounded)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _dep,
          decoration: InputDecoration(labelText: 'Département'.tr, prefixIcon: Icon(Icons.apartment_rounded)),
          items: [for (final d in deps) DropdownMenuItem(value: d, child: Text(d.tr))],
          onChanged: (v) => setState(() => _dep = v ?? _dep),
        ),
        TextFormField(
          controller: _prix,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Tarif par pièce'.tr, suffixText: 'DA'.tr, helperText: 'Vide ou 0 : prix à la pièce de l\'ouvrier'.tr, prefixIcon: Icon(Icons.sell_outlined)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _actif,
          onChanged: (v) => setState(() => _actif = v),
          title: Text('Active'.tr),
        ),
        if (widget.existing != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _supprimer,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
              label: Text('Supprimer'.tr, style: TextStyle(color: AppColors.rose)),
            ),
          ),
      ],
    );
  }
}
