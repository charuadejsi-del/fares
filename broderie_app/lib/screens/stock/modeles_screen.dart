import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/stock.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import 'produits_screen.dart' show EtiquettesDialog, ProduitDetailScreen, stockColor;

// ======================================================================= couleurs

const couleursPalette = <String, int>{
  'Noir': 0xFF111111,
  'Blanc': 0xFFFFFFFF,
  'Écru': 0xFFF3EBDD,
  'Beige': 0xFFD9C3A0,
  'Camel': 0xFFC19A6B,
  'Marron': 0xFF6B4226,
  'Chocolat': 0xFF3E2316,
  'Gris': 0xFF8E8E93,
  'Argent': 0xFFC0C0C8,
  'Doré': 0xFFD4AF37,
  'Bordeaux': 0xFF6D0F25,
  'Rouge': 0xFFD62828,
  'Corail': 0xFFFF6F61,
  'Saumon': 0xFFF4A28C,
  'Rose': 0xFFF4A6C0,
  'Rose poudré': 0xFFE8C4C4,
  'Fuchsia': 0xFFD6247A,
  'Lilas': 0xFFC8A2C8,
  'Mauve': 0xFF9C6FA6,
  'Violet': 0xFF5B2A86,
  'Bleu marine': 0xFF14213D,
  'Bleu roi': 0xFF1F4FD1,
  'Bleu ciel': 0xFF8EC9F0,
  'Turquoise': 0xFF2EC4B6,
  'Vert émeraude': 0xFF0B7A55,
  'Vert': 0xFF3A9D3A,
  'Vert olive': 0xFF6B7A2E,
  'Kaki': 0xFF8A8650,
  'Jaune': 0xFFF6D33C,
  'Moutarde': 0xFFC99A1E,
  'Orange': 0xFFF28C28,
};

Color couleurDe(String? nom) {
  if (nom == null) return Colors.transparent;
  final v = couleursPalette[nom] ??
      couleursPalette.entries.firstWhere((e) => e.key.toLowerCase() == nom.toLowerCase(), orElse: () => const MapEntry('', 0)).value;
  return v == 0 ? AppColors.forName(nom) : Color(v);
}

class Pastille extends StatelessWidget {
  final String? couleur;
  final double size;
  const Pastille(this.couleur, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) => couleur == null
      ? Icon(Icons.block_rounded, size: size, color: context.pal.muted)
      : Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: couleurDe(couleur),
            shape: BoxShape.circle,
            border: Border.all(color: context.isDark ? Colors.white38 : Colors.black26),
          ),
        );
}

String nomCouleur(String? c) => c ?? 'Sans couleur';
String nomTaille(String? t) => t ?? 'Unique';

// ======================================================================= sélecteur

/// Choix multiple (couleurs ou tailles) avec ajout libre.
class SelecteurValeurs extends StatelessWidget {
  final List<String> proposees;
  final List<String> choisies;
  final Set<String> verrouillees;
  final bool couleurs;
  final ValueChanged<List<String>> onChanged;
  const SelecteurValeurs({
    super.key,
    required this.proposees,
    required this.choisies,
    required this.onChanged,
    this.verrouillees = const {},
    this.couleurs = false,
  });

  Future<void> _autre(BuildContext context) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(couleurs ? 'Autre couleur' : 'Autre taille'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: couleurs ? 'Nom de la couleur' : 'Taille (ex. 56, Enfant 8 ans)'),
          onSubmitted: (x) => Navigator.pop(ctx, x),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Ajouter')),
        ],
      ),
    );
    final t = v?.trim();
    if (t == null || t.isEmpty || choisies.contains(t)) return;
    onChanged([...choisies, t]);
  }

  @override
  Widget build(BuildContext context) {
    final toutes = <String>[...proposees];
    for (final c in choisies) {
      if (!toutes.contains(c)) toutes.add(c);
    }
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final v in toutes)
        FilterChip(
          avatar: couleurs ? Pastille(v, size: 18) : null,
          label: Text(v),
          selected: choisies.contains(v),
          onSelected: verrouillees.contains(v)
              ? null
              : (sel) => onChanged(sel ? [...choisies, v] : choisies.where((x) => x != v).toList()),
        ),
      ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: Text(couleurs ? 'Autre couleur' : 'Autre taille'), onPressed: () => _autre(context)),
    ]);
  }
}

// ======================================================================= grille

/// Grille couleur (lignes) × taille (colonnes) de quantités.
class GrilleQuantites extends StatelessWidget {
  final List<String?> couleurs;
  final List<String?> tailles;
  final Map<String, TextEditingController> ctrls;
  final Map<String, int>? disponible;
  final Set<String>? cellulesActives;
  final VoidCallback? onChanged;
  const GrilleQuantites({
    super.key,
    required this.couleurs,
    required this.tailles,
    required this.ctrls,
    this.disponible,
    this.cellulesActives,
    this.onChanged,
  });

  TextEditingController _c(String k) => ctrls.putIfAbsent(k, () => TextEditingController());

  @override
  Widget build(BuildContext context) {
    final cs = couleurs.isEmpty ? <String?>[null] : couleurs;
    final ts = tailles.isEmpty ? <String?>[null] : tailles;
    final head = TextStyle(fontWeight: FontWeight.w800, color: context.pal.muted, fontSize: 12);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(74),
        columnWidths: const {0: IntrinsicColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text('Couleur \\ Taille', style: head)),
            for (final t in ts) Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(nomTaille(t), style: head))),
          ]),
          for (final c in cs)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Pastille(c),
                  const SizedBox(width: 8),
                  Text(nomCouleur(c), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              for (final t in ts)
                Builder(builder: (context) {
                  final k = cleGrille(c, t);
                  final actif = cellulesActives == null || cellulesActives!.contains(k);
                  if (!actif) return Center(child: Text('—', style: TextStyle(color: context.pal.muted)));
                  final d = disponible?[k];
                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                        controller: _c(k),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        decoration: const InputDecoration(isDense: true, hintText: '0', contentPadding: EdgeInsets.symmetric(vertical: 10)),
                        onChanged: (_) => onChanged?.call(),
                      ),
                      if (d != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('dispo $d',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: d > 0 ? AppColors.green : AppColors.rose)),
                        ),
                    ]),
                  );
                }),
            ]),
        ],
      ),
    );
  }
}

Map<String, int> lireGrille(Map<String, TextEditingController> ctrls) => {
      for (final e in ctrls.entries)
        if ((int.tryParse(e.value.text) ?? 0) > 0) e.key: int.parse(e.value.text),
    };

// ======================================================================= formulaire modèle

Future<String?> ouvrirModeleForm(BuildContext context, {Modele? modele}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ModeleForm(modele: modele)));

class ModeleForm extends StatefulWidget {
  final Modele? modele;
  const ModeleForm({super.key, this.modele});

  @override
  State<ModeleForm> createState() => _ModeleFormState();
}

class _ModeleFormState extends State<ModeleForm> {
  final _form = GlobalKey<FormState>();
  Modele? get m => widget.modele;
  late final _ref = TextEditingController(text: m?.reference);
  late final _nom = TextEditingController(text: m?.designation);
  late final _cat = TextEditingController(text: m?.categorie);
  late final _gros = TextEditingController(text: _n(m?.base.prixGros));
  late final _detail = TextEditingController(text: _n(m?.base.prixDetail));
  late final _cout = TextEditingController(text: _n(m?.base.coutRevient));
  late final _seuil = TextEditingController(text: m == null ? '' : '${m!.base.seuilAlerte}');
  late List<String> _couleurs = [...?m?.couleurs.whereType<String>()];
  late List<String> _tailles = [...?m?.tailles.whereType<String>()];
  final _qte = <String, TextEditingController>{};
  bool _busy = false;

  static String _n(double? v) => v == null || v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    if (m == null) {
      stock.prochaineReference().then((r) {
        if (mounted && _ref.text.isEmpty) setState(() => _ref.text = r);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in _qte.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String?> get _cs => _couleurs.isEmpty ? <String?>[null] : _couleurs;
  List<String?> get _ts => _tailles.isEmpty ? <String?>[null] : _tailles;

  int get _nbVariantes => _cs.length * _ts.length;
  int get _total => lireGrille(_qte).values.fold<int>(0, (s, v) => s + v);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ref = _ref.text.trim().toUpperCase();
    if (m == null && stock.produits.any((p) => p.reference.toUpperCase() == ref || p.modele == ref)) {
      showSnack(context, 'La référence $ref existe déjà', error: true);
      return;
    }
    setState(() => _busy = true);
    final champs = <String, dynamic>{
      'designation': _nom.text.trim(),
      'categorie': _cat.text.trim().isEmpty ? null : _cat.text.trim(),
      'prix_gros': parseNum(_gros.text) ?? 0,
      'prix_detail': parseNum(_detail.text) ?? 0,
      'cout_revient': parseNum(_cout.text) ?? 0,
      'seuil_alerte': parseInt(_seuil.text) ?? 0,
    };
    try {
      if (m != null) await stock.modifierModele(m!, champs);
      final cle = await stock.creerVariantes(
        reference: ref,
        champs: {...champs, 'actif': true},
        couleurs: _couleurs.isEmpty && m != null && m!.couleurs.contains(null) ? [null] : _couleurs,
        tailles: _tailles.isEmpty && m != null && m!.tailles.contains(null) ? [null] : _tailles,
        quantites: lireGrille(_qte),
        existant: m,
      );
      if (!mounted) return;
      final cree = stock.modeleParCle(cle);
      Navigator.pop(context, cle);
      if (m == null && cree != null) {
        showSnack(context, '${cree.variantes.length} variante(s) créée(s) · ${fmtInt(cree.stock)} pièces');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existantes = m == null ? <String>{} : {for (final v in m!.variantes) cleGrille(v.couleur, v.taille)};
    final verrouCouleurs = m == null ? <String>{} : m!.couleurs.whereType<String>().toSet();
    final verrouTailles = m == null ? <String>{} : m!.tailles.whereType<String>().toSet();
    final propCouleurs = {...couleursPalette.keys, ...stock.couleursUtilisees}.toList();
    final propTailles = {...taillesStandard, ...stock.taillesUtilisees}.toList()..sort((a, b) => ordreTaille(a).compareTo(ordreTaille(b)));
    return Scaffold(
      appBar: AppBar(title: Text(m == null ? 'Nouveau modèle' : 'Modifier ${m!.reference}')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Le modèle', subtitle: 'Une référence et un QR code sont créés pour chaque couleur et taille'),
              AutoGrid(minItemWidth: 240, children: [
                TextFormField(
                  controller: _ref,
                  enabled: m == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Référence du modèle', prefixIcon: Icon(Icons.qr_code_2_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                TextFormField(
                  controller: _nom,
                  autofocus: m == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nom (ex. Robe Karakou brodée)', prefixIcon: Icon(Icons.checkroom_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                ),
                TextFormField(controller: _cat, decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category_outlined))),
                TextFormField(
                  controller: _gros,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix de gros', suffixText: 'DA', prefixIcon: Icon(Icons.sell_outlined)),
                ),
                TextFormField(
                  controller: _detail,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix détail', suffixText: 'DA', prefixIcon: Icon(Icons.storefront_outlined)),
                ),
                TextFormField(
                  controller: _cout,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Main-d\'œuvre / pièce', suffixText: 'DA', prefixIcon: Icon(Icons.engineering_outlined)),
                ),
                TextFormField(
                  controller: _seuil,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Alerte si stock ≤ (par variante)', prefixIcon: Icon(Icons.warning_amber_rounded)),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Couleurs', subtitle: _couleurs.isEmpty ? 'Aucune couleur choisie : modèle sans couleur' : '${_couleurs.length} couleur(s)'),
              SelecteurValeurs(
                couleurs: true,
                proposees: propCouleurs,
                choisies: _couleurs,
                verrouillees: verrouCouleurs,
                onChanged: (v) => setState(() => _couleurs = v),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Tailles', subtitle: _tailles.isEmpty ? 'Aucune taille choisie : taille unique' : '${_tailles.length} taille(s)'),
              SelecteurValeurs(
                proposees: propTailles,
                choisies: _tailles,
                verrouillees: verrouTailles,
                onChanged: (v) => setState(() => _tailles = [...v]..sort((a, b) => ordreTaille(a).compareTo(ordreTaille(b)))),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(m == null ? 'Quantités en stock' : 'Ajouter des pièces',
                  subtitle: '$_nbVariantes variante(s) · total ${fmtInt(_total)} pièces'),
              GrilleQuantites(
                couleurs: _cs,
                tailles: _ts,
                ctrls: _qte,
                onChanged: () => setState(() {}),
                disponible: m == null ? null : {for (final v in m!.variantes) cleGrille(v.couleur, v.taille): v.stock},
              ),
              if (m != null && existantes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Les quantités saisies s\'ajoutent au stock actuel.', style: TextStyle(color: context.pal.muted)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
              label: Text(m == null ? 'Créer le modèle' : 'Enregistrer'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================================================================= carte modèle

class ModeleCard extends StatelessWidget {
  final Modele m;
  const ModeleCard(this.m, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = m.rupture ? AppColors.rose : (m.enAlerte ? const Color(0xFFF97316) : AppColors.green);
    final couleurs = m.couleurs.whereType<String>().toList();
    final tailles = m.tailles.whereType<String>().toList();
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModeleDetailScreen(cle: m.cle))),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.checkroom_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.reference, style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary, letterSpacing: 0.6)),
            Text(m.designation, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              for (final x in couleurs.take(8)) Padding(padding: const EdgeInsets.only(right: 4), child: Pastille(x, size: 14)),
              if (couleurs.length > 8) Text('+${couleurs.length - 8}', style: TextStyle(fontSize: 11, color: context.pal.muted)),
              if (couleurs.isNotEmpty && tailles.isNotEmpty) const SizedBox(width: 6),
              if (tailles.isNotEmpty)
                Flexible(
                  child: Text(tailles.join(' · '), style: TextStyle(fontSize: 11.5, color: context.pal.muted, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
            ]),
            if (m.prixGros > 0 || m.reserve > 0)
              Text([if (m.prixGros > 0) '${fmtDA(m.prixGros)} gros', if (m.reserve > 0) '${m.reserve} réservées'].join(' · '),
                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(fmtInt(m.stock), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: c)),
            Text('${m.variantes.length} var.', style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ======================================================================= détail modèle

class ModeleDetailScreen extends StatelessWidget {
  final String cle;
  const ModeleDetailScreen({super.key, required this.cle});

  Future<void> _stock(BuildContext context, Modele m, {required bool sortie}) async {
    final ctrls = <String, TextEditingController>{};
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(sortie ? 'Retirer du stock · ${m.reference}' : 'Ajouter du stock · ${m.reference}', style: ctx.tt.titleLarge),
            const SizedBox(height: 6),
            Text('Saisissez la quantité pour chaque couleur et taille.', style: TextStyle(color: ctx.pal.muted)),
            const SizedBox(height: 12),
            GrilleQuantites(
              couleurs: m.couleurs,
              tailles: m.tailles,
              ctrls: ctrls,
              cellulesActives: {for (final v in m.variantes) cleGrille(v.couleur, v.taille)},
              disponible: {for (final v in m.variantes) cleGrille(v.couleur, v.taille): v.stock},
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: InputDecoration(labelText: sortie ? 'Motif (défaut, perte…)' : 'Remarque (production, retour atelier…)')),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: sortie ? FilledButton.styleFrom(backgroundColor: AppColors.rose) : null,
              onPressed: () => Navigator.pop(ctx, true),
              icon: Icon(sortie ? Icons.remove_rounded : Icons.add_rounded),
              label: Text(sortie ? 'Retirer' : 'Ajouter au stock'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final q = lireGrille(ctrls);
    final par = <String, int>{};
    for (final v in m.variantes) {
      final n = q[cleGrille(v.couleur, v.taille)] ?? 0;
      if (n > 0) par[v.id] = sortie ? -n : n;
    }
    if (par.isEmpty) return;
    try {
      await stock.mouvementsGroupes(par, sortie ? TypeStock.sortie : TypeStock.entree, note: note.text);
      final total = par.values.fold<int>(0, (s, v) => s + v.abs());
      if (context.mounted) showSnack(context, '${sortie ? '−' : '+'}$total pièces');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final m = stock.modeleParCle(cle);
          if (m == null) return Scaffold(appBar: AppBar(), body: const EmptyState('Modèle introuvable.'));
          final cs = m.couleurs, ts = m.tailles;
          final head = TextStyle(fontWeight: FontWeight.w800, color: context.pal.muted, fontSize: 12);
          return Scaffold(
            appBar: AppBar(title: Text(m.reference), actions: [
              IconButton(tooltip: 'Modifier / ajouter couleurs et tailles', icon: const Icon(Icons.edit_outlined), onPressed: () => ouvrirModeleForm(context, modele: m)),
            ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                gradient: AppColors.heroGradient,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.designation, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text([m.reference, if (m.categorie != null) m.categorie!, if (m.prixGros > 0) '${fmtDA(m.prixGros)} gros'].join(' · '),
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 22, runSpacing: 10, children: [
                    _Chiffre('En stock', fmtInt(m.stock)),
                    _Chiffre('Disponible', fmtInt(m.disponible)),
                    _Chiffre('Réservé', fmtInt(m.reserve)),
                    _Chiffre('Vendu', fmtInt(m.vendus)),
                    _Chiffre('Valeur', fmtDA(m.valeurStock)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(onPressed: () => _stock(context, m, sortie: false), icon: const Icon(Icons.add_box_rounded), label: const Text('Ajouter du stock')),
                OutlinedButton.icon(onPressed: () => _stock(context, m, sortie: true), icon: const Icon(Icons.indeterminate_check_box_outlined), label: const Text('Retirer')),
                OutlinedButton.icon(
                  onPressed: () => ouvrirModeleForm(context, modele: m),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Couleurs / tailles'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(context: context, builder: (_) => EtiquettesDialog(produits: m.variantes)),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Étiquettes QR'),
                ),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Stock par couleur et taille', subtitle: 'Touchez une case pour la fiche, le QR et l\'historique'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(76),
                      columnWidths: const {0: IntrinsicColumnWidth()},
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(children: [
                          const SizedBox(),
                          for (final t in ts) Center(child: Padding(padding: const EdgeInsets.all(6), child: Text(nomTaille(t), style: head))),
                          Center(child: Text('Total', style: head)),
                        ]),
                        for (final c in cs)
                          TableRow(children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 6, 12, 6),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Pastille(c),
                                const SizedBox(width: 8),
                                Text(nomCouleur(c), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            for (final t in ts)
                              Builder(builder: (context) {
                                final v = m.variante(c, t);
                                if (v == null) return Center(child: Text('—', style: TextStyle(color: context.pal.muted)));
                                final col = stockColor(v);
                                return Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProduitDetailScreen(produitId: v.id))),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                                      child: Column(children: [
                                        Text(fmtInt(v.stock), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: col)),
                                        if (v.reserve > 0) Text('${v.reserve} rés.', style: TextStyle(fontSize: 10, color: col)),
                                      ]),
                                    ),
                                  ),
                                );
                              }),
                            Center(
                              child: Text(
                                fmtInt(m.variantes.where((v) => v.couleur == c).fold<int>(0, (s, v) => s + v.stock)),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ]),
          );
        },
      );
}

class _Chiffre extends StatelessWidget {
  final String label;
  final String value;
  const _Chiffre(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
}

// ======================================================================= choix pour vente / commande

/// Choisir un modèle puis les quantités par couleur et taille.
/// Renvoie la liste (variante, quantité).
Future<List<(Produit, int)>?> choisirArticles(BuildContext context, {bool verifierDispo = true}) async {
  final m = await showDialog<Modele>(context: context, builder: (_) => const _ChoixModeleDialog());
  if (m == null || !context.mounted) return null;
  if (m.variantes.length == 1) {
    final c = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m.reference} · ${m.designation}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Quantité', helperText: 'Disponible : ${m.base.disponible}'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );
    final n = int.tryParse(c.text) ?? 0;
    return ok == true && n > 0 ? [(m.base, n)] : null;
  }
  final ctrls = <String, TextEditingController>{};
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${m.reference} · ${m.designation}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quantité par couleur et taille', style: TextStyle(color: ctx.pal.muted)),
            const SizedBox(height: 10),
            GrilleQuantites(
              couleurs: m.couleurs,
              tailles: m.tailles,
              ctrls: ctrls,
              cellulesActives: {for (final v in m.variantes) cleGrille(v.couleur, v.taille)},
              disponible: {for (final v in m.variantes) cleGrille(v.couleur, v.taille): v.disponible},
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('Ajouter')),
      ],
    ),
  );
  if (ok != true) return null;
  final q = lireGrille(ctrls);
  return [
    for (final v in m.variantes)
      if ((q[cleGrille(v.couleur, v.taille)] ?? 0) > 0) (v, q[cleGrille(v.couleur, v.taille)]!),
  ];
}

class _ChoixModeleDialog extends StatefulWidget {
  const _ChoixModeleDialog();

  @override
  State<_ChoixModeleDialog> createState() => _ChoixModeleDialogState();
}

class _ChoixModeleDialogState extends State<_ChoixModeleDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = stock.modeles.where((m) => m.actif).where((m) => _q.isEmpty || m.contient(_q)).take(150).toList();
    return AlertDialog(
      title: const Text('Choisir un modèle'),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Référence, nom, couleur…', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const EmptyState('Aucun modèle.')
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final couleurs = m.couleurs.whereType<String>().toList();
                      return ListTile(
                        title: Text('${m.reference} · ${m.designation}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Row(children: [
                          for (final c in couleurs.take(10)) Padding(padding: const EdgeInsets.only(right: 3), child: Pastille(c, size: 12)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text([m.tailles.whereType<String>().join(' '), if (m.prixGros > 0) fmtDA(m.prixGros)].where((e) => e.isNotEmpty).join(' · '),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                        trailing: Text(fmtInt(m.disponible),
                            style: TextStyle(fontWeight: FontWeight.w900, color: m.disponible > 0 ? AppColors.green : AppColors.rose)),
                        onTap: () => Navigator.pop(context, m),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
