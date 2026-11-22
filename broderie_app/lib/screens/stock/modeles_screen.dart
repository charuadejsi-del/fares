import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/session.dart';
import '../../data/stock.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import 'produits_screen.dart' show EtiquettesDialog, ProduitDetailScreen, stockColor;
import '../../i18n.dart';

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

String nomCouleur(String? c) => c ?? 'Sans couleur'.tr;
String nomTaille(String? t) => t ?? 'Unique'.tr;

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
        title: Text(couleurs ? 'Autre couleur'.tr : 'Autre taille'.tr),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: couleurs ? 'Nom de la couleur'.tr : 'Taille (ex. 56, Enfant 8 ans)'.tr),
          onSubmitted: (x) => Navigator.pop(ctx, x),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('Ajouter'.tr)),
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
      ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: Text(couleurs ? 'Autre couleur'.tr : 'Autre taille'.tr), onPressed: () => _autre(context)),
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
            Padding(padding: const EdgeInsets.all(6), child: Text('Couleur \\ Taille'.tr, style: head)),
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
  final List<(Uint8List, String)> _photos = [];
  final _desc = TextEditingController();
  bool _busy = false;

  Future<void> _choisirPhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 2000, imageQuality: 85);
      for (final f in files.take(12 - _photos.length)) {
        _photos.add((await f.readAsBytes(), f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg'));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

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
      showSnack(context, 'La référence {0} existe déjà'.trf([ref]), error: true);
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
      if (_photos.isNotEmpty || _desc.text.trim().isNotEmpty) {
        final chemins = <String>[];
        for (final (b, ext) in _photos) {
          chemins.add(await stock.envoyerPhotoVitrine(b, ext: ext));
        }
        await stock.saveInfo(cle, photos: [...stock.info(cle).photos, ...chemins], description: _desc.text.trim().isEmpty ? null : _desc.text.trim());
      }
      if (!mounted) return;
      final cree = stock.modeleParCle(cle);
      Navigator.pop(context, cle);
      if (m == null && cree != null) {
        showSnack(context, '{0} variante(s) créée(s) · {1} pièces'.trf([cree.variantes.length, fmtInt(cree.stock)]));
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
      appBar: AppBar(title: Text(m == null ? 'Nouveau modèle'.tr : 'Modifier {0}'.trf([m!.reference]))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Le modèle'.tr, subtitle: 'Une référence et un QR code sont créés pour chaque couleur et taille'.tr),
              AutoGrid(minItemWidth: 240, children: [
                TextFormField(
                  controller: _ref,
                  enabled: m == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: 'Référence du modèle'.tr, prefixIcon: Icon(Icons.qr_code_2_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
                ),
                TextFormField(
                  controller: _nom,
                  autofocus: m == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Nom (ex. Robe Karakou brodée)'.tr, prefixIcon: Icon(Icons.checkroom_rounded)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
                ),
                TextFormField(controller: _cat, decoration: InputDecoration(labelText: 'Catégorie'.tr, prefixIcon: Icon(Icons.category_outlined))),
                TextFormField(
                  controller: _gros,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Prix de gros'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.sell_outlined)),
                ),
                TextFormField(
                  controller: _detail,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Prix détail'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.storefront_outlined)),
                ),
                TextFormField(
                  controller: _cout,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Main-d\'œuvre / pièce'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.engineering_outlined)),
                ),
                TextFormField(
                  controller: _seuil,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Alerte si stock ≤ (par variante)'.tr, prefixIcon: Icon(Icons.warning_amber_rounded)),
                ),
              ]),
            ]),
          ),
          if (m == null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle('Photos pour le site'.tr, subtitle: '{0}/12 · la première est la photo principale'.trf([_photos.length])),
                SizedBox(
                  height: 130,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final (k, (b, _)) in _photos.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(b, width: 100, height: 130, fit: BoxFit.cover)),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(28, 28), padding: EdgeInsets.zero),
                              iconSize: 16,
                              onPressed: () => setState(() => _photos.removeAt(k)),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                    if (_photos.length < 12)
                      InkWell(
                        onTap: _choisirPhotos,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.4),
                            color: AppColors.gold.withValues(alpha: 0.06),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_photo_alternate_rounded, color: AppColors.gold, size: 30),
                            SizedBox(height: 4),
                            Text('Ajouter'.tr, style: TextStyle(fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Description sur le site (facultatif)'.tr, prefixIcon: Icon(Icons.notes_rounded)),
                ),
              ]),
            ),
          ],          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Couleurs'.tr, subtitle: _couleurs.isEmpty ? 'Aucune couleur choisie : modèle sans couleur'.tr : '{0} couleur(s)'.trf([_couleurs.length])),
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
              SectionTitle('Tailles'.tr, subtitle: _tailles.isEmpty ? 'Aucune taille choisie : taille unique'.tr : '{0} taille(s)'.trf([_tailles.length])),
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
              SectionTitle(m == null ? 'Quantités en stock'.tr : 'Ajouter des pièces'.tr,
                  subtitle: '{0} variante(s) · total {1} pièces'.trf([_nbVariantes, fmtInt(_total)])),
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
                  child: Text('Les quantités saisies s\'ajoutent au stock actuel.'.tr, style: TextStyle(color: context.pal.muted)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
              label: Text(m == null ? 'Créer le modèle'.tr : 'Enregistrer'.tr),
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
        Builder(builder: (context) {
          final photos = stock.info(m.cle).photos;
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 58,
              height: 72,
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: photos.isEmpty
                  ? const Icon(Icons.checkroom_rounded, color: Colors.white, size: 28)
                  : Image.network(stock.urlPublique(photos.first), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_rounded, color: Colors.white)),
            ),
          );
        }),
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
            Text(sortie ? 'Retirer du stock · {0}'.trf([m.reference]) : 'Ajouter du stock · {0}'.trf([m.reference]), style: ctx.tt.titleLarge),
            const SizedBox(height: 6),
            Text('Saisissez la quantité pour chaque couleur et taille.'.tr, style: TextStyle(color: ctx.pal.muted)),
            const SizedBox(height: 12),
            GrilleQuantites(
              couleurs: m.couleurs,
              tailles: m.tailles,
              ctrls: ctrls,
              cellulesActives: {for (final v in m.variantes) cleGrille(v.couleur, v.taille)},
              disponible: {for (final v in m.variantes) cleGrille(v.couleur, v.taille): v.stock},
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: InputDecoration(labelText: sortie ? 'Motif (défaut, perte…)'.tr : 'Remarque (production, retour atelier…)'.tr)),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: sortie ? FilledButton.styleFrom(backgroundColor: AppColors.rose) : null,
              onPressed: () => Navigator.pop(ctx, true),
              icon: Icon(sortie ? Icons.remove_rounded : Icons.add_rounded),
              label: Text(sortie ? 'Retirer'.tr : 'Ajouter au stock'.tr),
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
      if (context.mounted) showSnack(context, '{0}{1} pièces'.trf([sortie ? '−' : '+', total]));
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final m = stock.modeleParCle(cle);
          if (m == null) return Scaffold(appBar: AppBar(), body: EmptyState('Modèle introuvable.'.tr));
          final cs = m.couleurs, ts = m.tailles;
          final head = TextStyle(fontWeight: FontWeight.w800, color: context.pal.muted, fontSize: 12);
          return Scaffold(
            appBar: AppBar(title: Text(m.reference), actions: [
              IconButton(tooltip: 'Modifier / ajouter couleurs et tailles'.tr, icon: const Icon(Icons.edit_outlined), onPressed: () => ouvrirModeleForm(context, modele: m)),
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
                    _Chiffre('En stock'.tr, fmtInt(m.stock)),
                    _Chiffre('Disponible'.tr, fmtInt(m.disponible)),
                    _Chiffre('Réservé'.tr, fmtInt(m.reserve)),
                    _Chiffre('Vendu'.tr, fmtInt(m.vendus)),
                    _Chiffre('Valeur'.tr, fmtDA(m.valeurStock)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(onPressed: () => _stock(context, m, sortie: false), icon: const Icon(Icons.add_box_rounded), label: Text('Ajouter du stock'.tr)),
                OutlinedButton.icon(onPressed: () => _stock(context, m, sortie: true), icon: const Icon(Icons.indeterminate_check_box_outlined), label: Text('Retirer'.tr)),
                OutlinedButton.icon(
                  onPressed: () => ouvrirModeleForm(context, modele: m),
                  icon: const Icon(Icons.palette_outlined),
                  label: Text('Couleurs / tailles'.tr),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(context: context, builder: (_) => EtiquettesDialog(produits: m.variantes)),
                  icon: const Icon(Icons.print_rounded),
                  label: Text('Étiquettes QR'.tr),
                ),
              ]),
              const SizedBox(height: 12),
              SeriesModeleCard(m: m),
              const SizedBox(height: 12),
              if (session.atelier?.vitrineAutorisee ?? false) VitrineModeleCard(m: m),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle('Stock par couleur et taille'.tr, subtitle: 'Touchez une case pour la fiche, le QR et l\'historique'.tr),
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
                          Center(child: Text('Total'.tr, style: head)),
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
                                        if (v.reserve > 0) Text('{0} rés.'.trf([v.reserve]), style: TextStyle(fontSize: 10, color: col)),
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
          decoration: InputDecoration(labelText: 'Quantité'.tr, helperText: 'Disponible : {0}'.trf([m.base.disponible])),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Ajouter'.tr)),
        ],
      ),
    );
    final n = int.tryParse(c.text) ?? 0;
    return ok == true && n > 0 ? [(m.base, n)] : null;
  }
  final ctrls = <String, TextEditingController>{};
  final series = stock.info(m.cle).series.where((x) => x.total > 0).toList();
  final nbSeries = {for (var i = 0; i < series.length; i++) i: 1};
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final total = lireGrille(ctrls).values.fold(0, (s, v) => s + v);
        void ajouterSerie(int i) {
          final n = nbSeries[i] ?? 1;
          for (final e in series[i].pour(m, n).entries) {
            final c = ctrls.putIfAbsent(e.key, () => TextEditingController());
            c.text = '${(int.tryParse(c.text) ?? 0) + e.value}';
          }
          setD(() {});
        }

        return AlertDialog(
          title: Text('${m.reference} · ${m.designation}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (series.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Vente par série'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < series.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            const Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('{0} · {1} pièces'.trf([series[i].nom, series[i].total]),
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: (nbSeries[i] ?? 1) > 1 ? () => setD(() => nbSeries[i] = nbSeries[i]! - 1) : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            ),
                            Text('× {0}'.trf([nbSeries[i]]), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setD(() => nbSeries[i] = (nbSeries[i] ?? 1) + 1),
                              icon: const Icon(Icons.add_circle_outline_rounded),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonal(
                              onPressed: () => ajouterSerie(i),
                              child: Text('Ajouter {0} série(s)'.trf([nbSeries[i]])),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(children: [
                  Expanded(child: Text('Quantité par couleur et taille'.tr, style: TextStyle(color: ctx.pal.muted))),
                  if (total > 0) ...[
                    Text('Total : {0} pièces'.trf([total]), style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextButton(
                      onPressed: () {
                        for (final c in ctrls.values) {
                          c.clear();
                        }
                        setD(() {});
                      },
                      child: Text('Vider'.tr),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                GrilleQuantites(
                  couleurs: m.couleurs,
                  tailles: m.tailles,
                  ctrls: ctrls,
                  onChanged: () => setD(() {}),
                  cellulesActives: {for (final v in m.variantes) cleGrille(v.couleur, v.taille)},
                  disponible: {for (final v in m.variantes) cleGrille(v.couleur, v.taille): v.disponible},
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton.icon(
              onPressed: total > 0 ? () => Navigator.pop(ctx, true) : null,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(total > 0 ? 'Ajouter {0} pièces'.trf([total]) : 'Ajouter'.tr),
            ),
          ],
        );
      },
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
      title: Text('Choisir un modèle'.tr),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: 'Référence, nom, couleur…'.tr, prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? EmptyState('Aucun modèle.'.tr)
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
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'.tr))],
    );
  }
}

// ======================================================================= séries de vente

/// Séries programmées pour un modèle (ex. série de 12 : 1 pièce par couleur et taille).
class SeriesModeleCard extends StatelessWidget {
  final Modele m;
  const SeriesModeleCard({super.key, required this.m});

  Future<void> _editer(BuildContext context, {int? index}) async {
    final info = stock.info(m.cle);
    final r = await showDialog<SerieVente>(
      context: context,
      builder: (_) => _SerieDialog(m: m, existante: index == null ? null : info.series[index]),
    );
    if (r == null) return;
    final liste = [...info.series];
    if (index == null) {
      liste.add(r);
    } else {
      liste[index] = r;
    }
    try {
      await stock.saveInfo(m.cle, series: liste);
      if (context.mounted) showSnack(context, 'Série enregistrée'.tr);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _supprimer(BuildContext context, int index) async {
    final info = stock.info(m.cle);
    if (!await confirmDialog(context, 'Supprimer « {0} » ?'.trf([info.series[index].nom]), 'Les ventes déjà faites ne changent pas.'.tr,
        action: 'Supprimer'.tr)) {
      return;
    }
    try {
      await stock.saveInfo(m.cle, series: [...info.series]..removeAt(index));
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final series = stock.info(m.cle).series;
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Séries de vente'.tr, subtitle: 'Vendez ce modèle par série en un clic'.tr),
              if (series.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Aucune série. Programmez la composition d\'une série (ex. 12 pièces : 4 couleurs × 3 tailles).'.tr,
                      style: TextStyle(color: context.pal.muted)),
                ),
              for (var i = 0; i < series.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(12)),
                    child: Text('${series[i].total}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
                  ),
                  title: Text(series[i].nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([
                    '{0} pièces'.trf([series[i].total]),
                    if (m.prixGros > 0) '{0} la série'.trf([fmtDA(series[i].total * m.prixGros)]),
                    series[i].auto ? 'Automatique selon le stock'.tr : _resume(series[i]),
                  ].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Modifier'.tr, onPressed: () => _editer(context, index: i), icon: const Icon(Icons.edit_rounded)),
                    IconButton(tooltip: 'Supprimer'.tr, onPressed: () => _supprimer(context, i), icon: const Icon(Icons.delete_outline_rounded)),
                  ]),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () => _editer(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Programmer une série'.tr),
                ),
              ),
            ]),
          );
        },
      );

  String _resume(SerieVente s) {
    final couleurs = <String>{}, tailles = <String>{};
    for (final k in s.composition.keys) {
      final p = k.split('|');
      if (p[0].isNotEmpty) couleurs.add(p[0]);
      if (p.length > 1 && p[1].isNotEmpty) tailles.add(p[1]);
    }
    return '{0} couleur(s) × {1} taille(s)'.trf([couleurs.length, tailles.length]);
  }
}

class _SerieDialog extends StatefulWidget {
  final Modele m;
  final SerieVente? existante;
  const _SerieDialog({required this.m, this.existante});

  @override
  State<_SerieDialog> createState() => _SerieDialogState();
}

class _SerieDialogState extends State<_SerieDialog> {
  late final _nom = TextEditingController(text: widget.existante?.nom ?? '');
  final _ctrls = <String, TextEditingController>{};
  final _parCase = TextEditingController(text: '1');
  late final _cible = TextEditingController(text: '${widget.existante?.cible ?? 12}');
  late bool _auto = widget.existante?.auto ?? false;

  void _generer() {
    final n = int.tryParse(_cible.text) ?? 0;
    if (n <= 0) return;
    final r = repartirSerie(widget.m, n);
    for (final c in _ctrls.values) {
      c.clear();
    }
    for (final e in r.entries) {
      _ctrls.putIfAbsent(e.key, () => TextEditingController()).text = '${e.value}';
    }
    final place = r.values.fold(0, (s, v) => s + v);
    setState(() => _auto = true);
    if (place < n) showSnack(context, 'Stock insuffisant : seulement {0} pièces disponibles pour cette série.'.trf([place]), error: true);
  }

  Set<String> get _cases => {for (final v in widget.m.variantes) cleGrille(v.couleur, v.taille)};

  @override
  void initState() {
    super.initState();
    for (final e in (widget.existante?.composition ?? const <String, int>{}).entries) {
      _ctrls[e.key] = TextEditingController(text: '${e.value}');
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _parCase.dispose();
    _cible.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _remplir() {
    final n = int.tryParse(_parCase.text) ?? 1;
    for (final k in _cases) {
      _ctrls.putIfAbsent(k, () => TextEditingController()).text = '$n';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final compo = {for (final e in lireGrille(_ctrls).entries) if (_cases.contains(e.key)) e.key: e.value};
    final total = compo.values.fold(0, (s, v) => s + v);
    return AlertDialog(
      title: Text(widget.existante == null ? 'Programmer une série'.tr : 'Modifier la série'.tr),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${widget.m.reference} · ${widget.m.designation}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _nom,
              decoration: InputDecoration(
                labelText: 'Nom de la série'.tr,
                hintText: 'Série {0}'.trf([total]),
                prefixIcon: const Icon(Icons.inventory_2_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Programme automatique'.tr, style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 4),
                Text('Répartit les pièces à parts égales entre les couleurs et tailles en stock.'.tr,
                    style: TextStyle(fontSize: 12.5, color: context.pal.muted)),
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _cible,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(isDense: true, suffixText: 'pcs'.tr),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generer,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: Text('Programmer automatiquement'.tr),
                    ),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                  title: Text('Recalculer à chaque vente selon le stock'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_auto
                      ? 'Si une couleur ou une taille est épuisée, la série se répartit sur celles qui restent.'.tr
                      : 'La série garde exactement la composition de la grille ci-dessous.'.tr),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Remplir toutes les cases avec'.tr)),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _parCase,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _remplir, child: Text('Remplir'.tr)),
            ]),
            const SizedBox(height: 12),
            Text('Pièces de chaque couleur et taille dans une série'.tr, style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 8),
            GrilleQuantites(
              couleurs: widget.m.couleurs,
              tailles: widget.m.tailles,
              ctrls: _ctrls,
              cellulesActives: _cases,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('{0} pièces par série'.trf([total]),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                if (widget.m.prixGros > 0)
                  Text('{0} la série au prix de gros'.trf([fmtDA(total * widget.m.prixGros)]), style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler'.tr)),
        FilledButton(
          onPressed: total == 0
              ? null
              : () => Navigator.pop(
                    context,
                    SerieVente(
                      nom: _nom.text.trim().isEmpty ? 'Série {0}'.trf([_auto ? (int.tryParse(_cible.text) ?? total) : total]) : _nom.text.trim(),
                      composition: compo,
                      auto: _auto,
                      cible: _auto ? (int.tryParse(_cible.text) ?? total) : 0,
                    ),
                  ),
          child: Text('Enregistrer'.tr),
        ),
      ],
    );
  }
}

// ======================================================================= site vitrine

class VitrineModeleCard extends StatefulWidget {
  final Modele m;
  const VitrineModeleCard({super.key, required this.m});

  @override
  State<VitrineModeleCard> createState() => _VitrineModeleCardState();
}

class _VitrineModeleCardState extends State<VitrineModeleCard> {
  bool _busy = false;

  String get _cle => widget.m.cle;

  Future<void> _ajouter() async {
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 2000, imageQuality: 85);
      if (files.isEmpty) return;
      setState(() => _busy = true);
      final photos = [...stock.info(_cle).photos];
      for (final f in files.take(12 - photos.length)) {
        final ext = f.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
        photos.add(await stock.envoyerPhotoVitrine(await f.readAsBytes(), ext: ext));
      }
      await stock.saveInfo(_cle, photos: photos);
      if (mounted) showSnack(context, 'Photo(s) publiée(s) sur le site'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retirer(String path) async {
    if (!await confirmDialog(context, 'Retirer la photo'.tr, 'Retirer cette photo du site ?'.tr)) return;
    final photos = stock.info(_cle).photos.where((p) => p != path).toList();
    try {
      await stock.saveInfo(_cle, photos: photos);
      await stock.retirerPhotoVitrine(path);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _principale(String path) async {
    final photos = [path, ...stock.info(_cle).photos.where((p) => p != path)];
    await stock.saveInfo(_cle, photos: photos);
  }

  Future<void> _couleurPhoto(String path) async {
    final cur = stock.info(_cle).photosCouleurs[path];
    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Couleur de cette photo'.tr),
        children: [
          for (final c in widget.m.couleurs.whereType<String>())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Row(children: [
                Pastille(c),
                const SizedBox(width: 10),
                Text(c, style: TextStyle(fontWeight: c == cur ? FontWeight.w900 : FontWeight.w500)),
              ]),
            ),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, ''), child: Text('Aucune couleur'.tr)),
        ],
      ),
    );
    if (choix == null) return;
    final pc = {...stock.info(_cle).photosCouleurs};
    if (choix.isEmpty) {
      pc.remove(path);
    } else {
      pc[path] = choix;
    }
    await stock.saveInfo(_cle, photosCouleurs: pc);
  }

  Future<void> _description() async {
    final c = TextEditingController(text: stock.info(_cle).description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Description sur le site'.tr),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: c,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Tissu, broderie, finitions, conseils…'.tr),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
        ],
      ),
    );
    if (ok == true) await stock.saveInfo(_cle, description: c.text.trim());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final i = stock.info(_cle);
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Site vitrine'.tr,
                  subtitle: i.publie ? 'Visible par vos clients, mis à jour automatiquement'.tr : 'Masqué du site'.tr,
                  trailing: Switch(value: i.publie, onChanged: (v) => stock.saveInfo(_cle, publie: v))),
              SizedBox(
                height: 150,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final (k, p) in i.photos.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(stock.urlPublique(p), width: 116, height: 150, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(width: 116, color: context.pal.surface2, child: const Icon(Icons.broken_image_outlined))),
                        ),
                        if (i.photosCouleurs[p] != null)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Pastille(i.photosCouleurs[p], size: 12),
                                const SizedBox(width: 4),
                                Text(i.photosCouleurs[p]!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        if (k == 0)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                              child: Text('Principale'.tr, style: TextStyle(color: AppColors.ink, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                            ),
                            itemBuilder: (_) => [
                              if (k > 0) PopupMenuItem(value: 'main', child: Text('Mettre en photo principale'.tr)),
                              if (widget.m.couleurs.whereType<String>().isNotEmpty)
                                PopupMenuItem(value: 'col', child: Text('Associer à une couleur'.tr)),
                              PopupMenuItem(value: 'del', child: Text('Retirer'.tr)),
                            ],
                            onSelected: (v) => switch (v) {
                              'main' => _principale(p),
                              'col' => _couleurPhoto(p),
                              _ => _retirer(p),
                            },
                          ),
                        ),
                      ]),
                    ),
                  if (i.photos.length < 12)
                    InkWell(
                      onTap: _busy ? null : _ajouter,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 116,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.4),
                          color: AppColors.gold.withValues(alpha: 0.06),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _busy
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Icon(Icons.add_photo_alternate_rounded, color: AppColors.gold, size: 34),
                          const SizedBox(height: 6),
                          Text('Ajouter\ndes photos'.tr, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notes_rounded),
                title: Text(i.description == null || i.description!.isEmpty ? 'Ajouter une description'.tr : i.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _description,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.star_rounded, color: AppColors.gold),
                title: Text('Mettre en vedette'.tr),
                subtitle: Text('Affiché en premier sur le site'.tr),
                value: i.vedette,
                onChanged: (v) => stock.saveInfo(_cle, vedette: v),
              ),
            ]),
          );
        },
      );
}
