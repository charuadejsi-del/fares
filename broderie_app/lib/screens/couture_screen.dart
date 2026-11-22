import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/couture.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../i18n.dart';
import '../pdf/documents.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'coupe_screen.dart' show PaquetDetailScreen, PuceEtape;
import 'refs_screens.dart' show FormDialog;

/// Délai (jours) au-delà duquel un envoi est signalé en retard.
const _retard = 15;

final _listen = Listenable.merge([data, couture]);

String _numero(String lotId) => data.lot(lotId)?.numero ?? '?';

Future<DateTime?> _choisirDate(BuildContext context, DateTime d) =>
    showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));

Widget _ligneDate(BuildContext context, String label, DateTime d, ValueChanged<DateTime> onChange) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_rounded),
      title: Text(label),
      subtitle: Text(fmtDate(d)),
      onTap: () async {
        final x = await _choisirDate(context, d);
        if (x != null) onChange(x);
      },
    );

TextFormField _champNombre(TextEditingController c, String label, {bool obligatoire = false, bool decimal = false, IconData? icon}) => TextFormField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [decimal ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')) : FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
      validator: obligatoire ? (v) => (parseNum(v ?? '') ?? 0) <= 0 ? 'Obligatoire'.tr : null : null,
    );

Future<void> _pdfEnvoi(BuildContext context, EnvoiCouture e, {bool partage = false}) async {
  final a = session.atelier, c = couture.atelier(e.couturierId), l = data.lot(e.lotId);
  if (a == null || c == null) return;
  try {
    final bytes = await buildBonEnvoiCouture(atelier: a, couturier: c, numeroLot: _numero(e.lotId), modele: l?.modele, couleur: l?.couleur, envoi: e);
    final nom = 'Envoi_couture_${_numero(e.lotId)}.pdf';
    partage ? await partager(bytes, nom) : await imprimer(bytes, nom);
  } catch (err) {
    if (context.mounted) showSnack(context, errorMessage(err), error: true);
  }
}

// ====================================================================== module

class CoutureModule extends StatelessWidget {
  const CoutureModule({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(icon: const Icon(Icons.local_shipping_rounded), text: 'Chez les ateliers'.tr),
              Tab(icon: const Icon(Icons.store_rounded), text: 'Ateliers & comptes'.tr),
              Tab(icon: const Icon(Icons.history_rounded), text: 'Historique'.tr),
            ]),
          ),
          const Expanded(child: TabBarView(children: [_EnCours(), _Ateliers(), _Historique()])),
        ]),
      );
}

// ---------------------------------------------------------------------- en cours

class _EnCours extends StatelessWidget {
  const _EnCours();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _listen,
        builder: (context, _) {
          final aEnvoyer = data.lots.where((l) => l.etape == 'couture' && couture.aEnvoyer(l) > 0).toList();
          final enCours = couture.envois.where((e) => !e.termine).toList()..sort((a, b) => a.date.compareTo(b.date));
          final retards = enCours.where((e) => e.jours > _retard).length;
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          return RefreshIndicator(
            onRefresh: () => Future.wait([couture.load(), data.loadLots()]),
            child: ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 40), children: [
              AutoGrid(minItemWidth: 170, children: [
                StatTile(label: 'Paquets à envoyer'.tr, value: '${aEnvoyer.length}', icon: Icons.inventory_2_rounded, color: AppColors.gold),
                StatTile(
                  label: 'Pièces chez les ateliers'.tr,
                  value: fmtInt(enCours.fold<int>(0, (s, e) => s + e.restant)),
                  icon: Icons.design_services_rounded,
                  color: AppColors.sky,
                ),
                StatTile(label: 'En retard (+{0} j)'.trf([_retard]), value: '$retards', icon: Icons.warning_amber_rounded, color: retards > 0 ? AppColors.rose : AppColors.green),
              ]),
              if (couture.ateliers.isEmpty) ...[
                const SizedBox(height: 16),
                EmptyState('Ajoutez d\'abord vos ateliers de couture dans l\'onglet « Ateliers & comptes ».'.tr, icon: Icons.store_rounded),
              ],
              if (aEnvoyer.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionTitle('Paquets arrivés à la couture'.tr),
                const SizedBox(height: 8),
                AutoGrid(minItemWidth: 320, children: [
                  for (final l in aEnvoyer)
                    AppCard(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('#${l.numero}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            Text(
                              [
                                'Reste à envoyer : {0} / {1}'.trf([fmtInt(couture.aEnvoyer(l)), fmtInt(l.nbPieces)]),
                                if (l.modele != null) l.modele!,
                              ].join(' · '),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ]),
                        ),
                        FilledButton.icon(
                          onPressed: couture.ateliers.any((a) => a.actif) ? () => ouvrirEnvoi(context, l) : null,
                          icon: const Icon(Icons.send_rounded),
                          label: Text('Envoyer'.tr),
                        ),
                      ]),
                    ),
                ]),
              ],
              const SizedBox(height: 18),
              SectionTitle('Chez les ateliers'.tr),
              const SizedBox(height: 8),
              if (enCours.isEmpty)
                EmptyState('Aucune pièce chez les ateliers de couture.'.tr, icon: Icons.design_services_outlined)
              else
                AutoGrid(minItemWidth: 340, children: [for (final e in enCours) CarteEnvoi(e)]),
            ]),
          );
        },
      );
}

class CarteEnvoi extends StatelessWidget {
  final EnvoiCouture e;
  final bool montrerAtelier;
  const CarteEnvoi(this.e, {super.key, this.montrerAtelier = true});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final enRetard = !e.termine && e.jours > _retard;
    return AppCard(
      onTap: () => _detailEnvoi(context, e),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${_numero(e.lotId)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          if (montrerAtelier) Expanded(child: Text(couture.nom(e.couturierId), style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)) else const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (enRetard ? AppColors.rose : AppColors.sky).withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
            child: Text(
              e.termine ? 'Rendu'.tr : '{0} j'.trf([e.jours]),
              style: TextStyle(color: e.termine ? AppColors.green : (enRetard ? AppColors.rose : AppColors.sky), fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Parti le {0} · {1} / pièce'.trf([fmtDate(e.date), fmtDA(e.prix)]), style: TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: e.pieces == 0 ? 0 : e.rendues / e.pieces, minHeight: 6, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _chiffre('Envoyées'.tr, e.pieces, null),
          _chiffre('Bonnes'.tr, e.bonnes, AppColors.green),
          if (e.abimees > 0) _chiffre('Abîmées'.tr, e.abimees, AppColors.rose),
          if (e.retouche > 0) _chiffre('Retouches'.tr, e.retouche, AppColors.gold),
          _chiffre('Chez l\'atelier'.tr, e.restant, AppColors.sky),
        ]),
        if (!e.termine) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(onPressed: () => ouvrirRetour(context, e), icon: const Icon(Icons.assignment_return_rounded), label: Text('Enregistrer un retour'.tr)),
            IconButton(tooltip: 'Bon d\'envoi PDF'.tr, onPressed: () => _pdfEnvoi(context, e), icon: const Icon(Icons.print_rounded)),
          ]),
        ],
      ]),
    );
  }

  Widget _chiffre(String label, int v, Color? c) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label : ', style: const TextStyle(fontSize: 12)),
        TextSpan(text: fmtInt(v), style: TextStyle(fontWeight: FontWeight.w800, color: c)),
      ]));
}

// ---------------------------------------------------------------------- envoi

Future<void> ouvrirEnvoi(BuildContext context, Lot l) => showDialog(context: context, builder: (_) => _EnvoiForm(l));

class _EnvoiForm extends StatefulWidget {
  final Lot l;
  const _EnvoiForm(this.l);

  @override
  State<_EnvoiForm> createState() => _EnvoiFormState();
}

class _EnvoiFormState extends State<_EnvoiForm> {
  final _form = GlobalKey<FormState>();
  late final _pieces = TextEditingController(text: '${couture.aEnvoyer(widget.l)}');
  late final _prix = TextEditingController(text: couture.prixModele(widget.l.modele)?.toStringAsFixed(0) ?? '');
  final _note = TextEditingController();
  String? _couturier;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _pieces.dispose();
    _prix.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_couturier == null) {
      showSnack(context, 'Choisissez l\'atelier de couture.'.tr, error: true);
      return;
    }
    final n = parseInt(_pieces.text)!, max = couture.aEnvoyer(widget.l);
    if (n > max) {
      showSnack(context, 'Il reste seulement {0} pièces à envoyer.'.trf([max]), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await couture.envoyer(widget.l, couturierId: _couturier!, pieces: n, prix: parseNum(_prix.text) ?? 0, date: _date, note: _note.text);
      if (!mounted) return;
      Navigator.pop(context);
      final e = couture.envois.where((x) => x.lotId == widget.l.id && x.couturierId == _couturier).firstOrNull;
      showSnack(context, 'Envoi enregistré.'.tr);
      if (e != null) await _pdfEnvoi(context, e);
    } catch (err) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(err), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return FormDialog(
      title: 'Envoyer le paquet {0} à la couture'.trf(['#${l.numero}']),
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        if (l.modele != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('{0} : {1}'.trf(['Modèle'.tr, l.modele!]))),
        DropdownButtonFormField<String>(
          initialValue: _couturier,
          decoration: InputDecoration(labelText: 'Atelier de couture'.tr, prefixIcon: const Icon(Icons.store_rounded)),
          items: [for (final a in couture.ateliers.where((a) => a.actif)) DropdownMenuItem(value: a.id, child: Text(a.nom))],
          onChanged: (v) => setState(() => _couturier = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _champNombre(_pieces, 'Pièces envoyées'.tr, obligatoire: true, icon: Icons.checkroom_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _champNombre(_prix, 'Prix par pièce (DA)'.tr, decimal: true, icon: Icons.payments_rounded)),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Reste à envoyer : {0} / {1}'.trf([fmtInt(couture.aEnvoyer(l)), fmtInt(l.nbPieces)]), style: const TextStyle(fontSize: 12)),
        ),
        _ligneDate(context, 'Date de départ'.tr, _date, (d) => setState(() => _date = d)),
        TextFormField(controller: _note, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
      ],
    );
  }
}

// ---------------------------------------------------------------------- retour

Future<void> ouvrirRetour(BuildContext context, EnvoiCouture e) => showDialog(context: context, builder: (_) => _RetourForm(e));

class _RetourForm extends StatefulWidget {
  final EnvoiCouture e;
  const _RetourForm(this.e);

  @override
  State<_RetourForm> createState() => _RetourFormState();
}

class _RetourFormState extends State<_RetourForm> {
  final _form = GlobalKey<FormState>();
  late final _bonnes = TextEditingController(text: '${widget.e.restant}');
  final _retouche = TextEditingController();
  final _abimees = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_bonnes, _retouche, _abimees, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final b = parseInt(_bonnes.text) ?? 0, r = parseInt(_retouche.text) ?? 0, a = parseInt(_abimees.text) ?? 0;
    if (b + r + a == 0) {
      showSnack(context, 'Saisissez au moins une pièce.'.tr, error: true);
      return;
    }
    if (b + a + r > widget.e.restant) {
      showSnack(context, 'Seulement {0} pièces sont chez l\'atelier.'.trf([widget.e.restant]), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final vers = await couture.retour(widget.e, date: _date, bonnes: b, retouche: r, abimees: a, note: _note.text);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, vers == null ? 'Retour enregistré.'.tr : 'Paquet complet : envoyé à {0}.'.trf([etapeNom(vers)]));
    } catch (err) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(err), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: 'Retour du paquet {0}'.trf(['#${_numero(widget.e.lotId)}']),
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          Text('{0} · chez l\'atelier : {1} pièces'.trf([couture.nom(widget.e.couturierId), fmtInt(widget.e.restant)])),
          const SizedBox(height: 12),
          _champNombre(_bonnes, 'Pièces bonnes (payées)'.tr, icon: Icons.check_circle_rounded),
          const SizedBox(height: 10),
          _champNombre(_retouche, 'À retoucher (rendues à l\'atelier)'.tr, icon: Icons.build_circle_rounded),
          const SizedBox(height: 10),
          _champNombre(_abimees, 'Abîmées'.tr, icon: Icons.cancel_rounded),
          const SizedBox(height: 6),
          Text('Les pièces à retoucher restent comptées chez l\'atelier jusqu\'à leur retour.'.tr, style: const TextStyle(fontSize: 12)),
          _ligneDate(context, 'Date du retour'.tr, _date, (d) => setState(() => _date = d)),
          TextFormField(controller: _note, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
        ],
      );
}

// ---------------------------------------------------------------------- détail d'un envoi

Future<void> _detailEnvoi(BuildContext context, EnvoiCouture e) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: couture,
        builder: (ctx, _) {
          final x = couture.envois.where((v) => v.id == e.id).firstOrNull;
          if (x == null) return const SizedBox(height: 80);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .8),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                Text('{0} → {1}'.trf(['#${_numero(x.lotId)}', couture.nom(x.couturierId)]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Parti le {0} · {1} pièces · {2} / pièce'.trf([fmtDate(x.date), fmtInt(x.pieces), fmtDA(x.prix)])),
                Text('Montant dû (pièces bonnes) : {0}'.trf([fmtDA(x.montant)]), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (x.note != null) Text(x.note!),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (!x.termine) FilledButton.tonalIcon(onPressed: () => ouvrirRetour(ctx, x), icon: const Icon(Icons.assignment_return_rounded), label: Text('Enregistrer un retour'.tr)),
                  OutlinedButton.icon(onPressed: () => _pdfEnvoi(ctx, x), icon: const Icon(Icons.print_rounded), label: Text('Bon d\'envoi PDF'.tr)),
                  OutlinedButton.icon(onPressed: () => _pdfEnvoi(ctx, x, partage: true), icon: const Icon(Icons.share_rounded), label: Text('Partager'.tr)),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: x.lotId))),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: Text('Voir le paquet'.tr),
                  ),
                  if (x.retours.isEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await confirmDialog(ctx, 'Supprimer cet envoi ?'.tr, 'L\'envoi sera effacé (aucun retour enregistré).'.tr);
                        if (!ok) return;
                        await couture.deleteEnvoi(x.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                      label: Text('Supprimer'.tr, style: const TextStyle(color: AppColors.rose)),
                    ),
                ]),
                const SizedBox(height: 12),
                SectionTitle('Retours'.tr),
                if (x.retours.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('Aucun retour pour l\'instant.'.tr)),
                for (final r in x.retours.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_return_rounded, color: AppColors.green),
                    title: Text(fmtDate(r.date)),
                    subtitle: Text([
                      '{0} : {1}'.trf(['Bonnes'.tr, r.bonnes]),
                      if (r.retouche > 0) '{0} : {1}'.trf(['Retouches'.tr, r.retouche]),
                      if (r.abimees > 0) '{0} : {1}'.trf(['Abîmées'.tr, r.abimees]),
                      if (r.note != null) r.note!,
                    ].join(' · ')),
                    trailing: IconButton(
                      tooltip: 'Supprimer'.tr,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await confirmDialog(ctx, 'Supprimer ce retour ?'.tr, 'Les pièces seront de nouveau comptées chez l\'atelier.'.tr);
                        if (ok) await couture.deleteRetour(r.id);
                      },
                    ),
                  ),
              ]),
            ),
          );
        },
      ),
    );

// ---------------------------------------------------------------------- ateliers & comptes

class _Ateliers extends StatelessWidget {
  const _Ateliers();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _listen,
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          final totalDu = couture.ateliers.fold<double>(0, (s, a) => s + couture.solde(a.id));
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _ouvrirAtelier(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvel atelier'.tr),
            ),
            body: ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 96), children: [
              AutoGrid(minItemWidth: 170, children: [
                StatTile(label: 'Ateliers de couture'.tr, value: '${couture.ateliers.where((a) => a.actif).length}', icon: Icons.store_rounded, color: AppColors.sky),
                StatTile(label: 'Reste à payer (total)'.tr, value: fmtDA(totalDu), icon: Icons.account_balance_wallet_rounded, color: AppColors.rose),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(onPressed: () => _ouvrirTarifs(context), icon: const Icon(Icons.sell_rounded), label: Text('Prix par modèle'.tr)),
              ),
              const SizedBox(height: 12),
              if (couture.ateliers.isEmpty)
                EmptyState('Aucun atelier de couture.\nAjoutez les ateliers externes avec qui vous travaillez.'.tr, icon: Icons.store_outlined)
              else
                AutoGrid(minItemWidth: 320, children: [
                  for (final a in couture.ateliers)
                    AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CouturierScreen(id: a.id))),
                      child: Opacity(
                        opacity: a.actif ? 1 : .5,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.store_rounded, color: AppColors.sky),
                            const SizedBox(width: 8),
                            Expanded(child: Text(a.nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                            if (!a.actif) Text('Inactif'.tr),
                          ]),
                          if (a.telephone != null) Text(a.telephone!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Text('{0} pièces chez lui'.trf([fmtInt(couture.chezAtelier(a.id))])),
                          Text(
                            'Reste à payer : {0}'.trf([fmtDA(couture.solde(a.id))]),
                            style: TextStyle(fontWeight: FontWeight.w800, color: couture.solde(a.id) > 0 ? AppColors.rose : AppColors.green),
                          ),
                        ]),
                      ),
                    ),
                ]),
            ]),
          );
        },
      );
}

Future<void> _ouvrirAtelier(BuildContext context, [Couturier? c]) => showDialog(context: context, builder: (_) => _AtelierForm(c));

class _AtelierForm extends StatefulWidget {
  final Couturier? c;
  const _AtelierForm(this.c);

  @override
  State<_AtelierForm> createState() => _AtelierFormState();
}

class _AtelierFormState extends State<_AtelierForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.c?.nom ?? '');
  late final _tel = TextEditingController(text: widget.c?.telephone ?? '');
  late final _adr = TextEditingController(text: widget.c?.adresse ?? '');
  late final _note = TextEditingController(text: widget.c?.note ?? '');
  late bool _actif = widget.c?.actif ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nom, _tel, _adr, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await couture.saveAtelier(id: widget.c?.id, nom: _nom.text, telephone: _tel.text, adresse: _adr.text, note: _note.text, actif: _actif);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.c == null ? 'Nouvel atelier de couture'.tr : 'Modifier l\'atelier'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: widget.c == null,
            decoration: InputDecoration(labelText: 'Nom de l\'atelier'.tr, prefixIcon: const Icon(Icons.store_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire'.tr : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _tel, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone'.tr, prefixIcon: const Icon(Icons.phone_rounded))),
          const SizedBox(height: 10),
          TextFormField(controller: _adr, decoration: InputDecoration(labelText: 'Adresse'.tr, prefixIcon: const Icon(Icons.place_rounded))),
          const SizedBox(height: 10),
          TextFormField(controller: _note, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
          if (widget.c != null) SwitchListTile(contentPadding: EdgeInsets.zero, value: _actif, onChanged: (v) => setState(() => _actif = v), title: Text('Actif'.tr)),
        ],
      );
}

// ---------------------------------------------------------------------- prix par modèle

Future<void> _ouvrirTarifs(BuildContext context) => showDialog(context: context, builder: (_) => const _TarifsDialog());

class _TarifsDialog extends StatefulWidget {
  const _TarifsDialog();

  @override
  State<_TarifsDialog> createState() => _TarifsDialogState();
}

class _TarifsDialogState extends State<_TarifsDialog> {
  TextEditingController? _ac;
  final _prix = TextEditingController();

  @override
  void dispose() {
    _prix.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final m = (_ac?.text ?? '').trim(), p = parseNum(_prix.text);
    if (m.isEmpty || p == null) return;
    try {
      await couture.saveTarif(m, p);
      _ac?.clear();
      _prix.clear();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeles = {for (final l in data.lots) if (l.modele != null) l.modele!}.toList()..sort();
    return AlertDialog(
      title: Text('Prix de couture par modèle'.tr),
      content: SizedBox(
        width: 460,
        child: ListenableBuilder(
          listenable: couture,
          builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Ce prix est proposé automatiquement à chaque envoi (modifiable).'.tr, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 3,
                child: Autocomplete<String>(
                  optionsBuilder: (v) => modeles.where((m) => m.toLowerCase().contains(v.text.toLowerCase())),
                  fieldViewBuilder: (ctx, c, f, _) {
                    _ac = c;
                    return TextField(controller: c, focusNode: f, decoration: InputDecoration(isDense: true, labelText: 'Modèle'.tr));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextField(controller: _prix, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(isDense: true, labelText: 'Prix (DA)'.tr))),
              IconButton.filled(onPressed: _ajouter, icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final t in couture.tarifs)
                  ListTile(
                    dense: true,
                    title: Text(t.modele),
                    subtitle: Text(fmtDA(t.prix)),
                    onTap: () {
                      _ac?.text = t.modele;
                      _prix.text = t.prix.toStringAsFixed(0);
                    },
                    trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => couture.deleteTarif(t.id)),
                  ),
                if (couture.tarifs.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('Aucun prix enregistré.'.tr)),
              ]),
            ),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'.tr))],
    );
  }
}

// ---------------------------------------------------------------------- compte d'un atelier

class CouturierScreen extends StatelessWidget {
  final String id;
  const CouturierScreen({super.key, required this.id});

  Future<void> _payer(BuildContext context, Couturier c) async {
    final montant = TextEditingController(text: couture.solde(c.id) > 0 ? couture.solde(c.id).toStringAsFixed(0) : '');
    final note = TextEditingController();
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Paiement à {0}'.trf([c.nom])),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Reste à payer : {0}'.trf([fmtDA(couture.solde(c.id))])),
              const SizedBox(height: 8),
              _champNombre(montant, 'Montant (DA)'.tr, decimal: true, icon: Icons.payments_rounded),
              _ligneDate(ctx, 'Date'.tr, date, (d) => set(() => date = d)),
              TextField(controller: note, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
          ],
        ),
      ),
    );
    final m = parseNum(montant.text) ?? 0;
    if (ok != true || m <= 0) return;
    try {
      await couture.payer(c.id, montant: m, date: date, note: note.text);
      if (context.mounted) showSnack(context, 'Paiement enregistré.'.tr);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _releve(BuildContext context, Couturier c, {bool partage = false}) async {
    final a = session.atelier;
    if (a == null) return;
    try {
      final bytes = await buildReleveCouturier(
        atelier: a,
        couturier: c,
        envois: couture.envoisDe(c.id).reversed.toList(),
        paiements: couture.paiementsDe(c.id).reversed.toList(),
        numeroLot: _numero,
      );
      final nom = 'Releve_${c.nom.replaceAll(' ', '_')}.pdf';
      partage ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _listen,
        builder: (context, _) {
          final c = couture.atelier(id);
          if (c == null) return Scaffold(appBar: AppBar(), body: EmptyState('Atelier introuvable.'.tr));
          final envois = couture.envoisDe(c.id), paiements = couture.paiementsDe(c.id);
          return Scaffold(
            appBar: AppBar(
              title: Text(c.nom),
              actions: [
                IconButton(tooltip: 'Modifier'.tr, icon: const Icon(Icons.edit_rounded), onPressed: () => _ouvrirAtelier(context, c)),
                if (envois.isEmpty && paiements.isEmpty)
                  IconButton(
                    tooltip: 'Supprimer'.tr,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'Supprimer {0} ?'.trf([c.nom]), 'Cet atelier n\'a aucun envoi ni paiement.'.tr);
                      if (!ok) return;
                      await couture.deleteAtelier(c.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AutoGrid(minItemWidth: 170, children: [
                StatTile(label: 'Pièces chez lui'.tr, value: fmtInt(couture.chezAtelier(c.id)), icon: Icons.design_services_rounded, color: AppColors.sky),
                StatTile(label: 'Dû (pièces bonnes)'.tr, value: fmtDA(couture.du(c.id)), icon: Icons.receipt_long_rounded, color: AppColors.gold),
                StatTile(label: 'Payé'.tr, value: fmtDA(couture.paye(c.id)), icon: Icons.payments_rounded, color: AppColors.green),
                StatTile(label: 'Reste à payer'.tr, value: fmtDA(couture.solde(c.id)), icon: Icons.account_balance_wallet_rounded, color: AppColors.rose),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(onPressed: () => _payer(context, c), icon: const Icon(Icons.payments_rounded), label: Text('Enregistrer un paiement'.tr)),
                OutlinedButton.icon(onPressed: () => _releve(context, c), icon: const Icon(Icons.print_rounded), label: Text('Relevé PDF'.tr)),
                OutlinedButton.icon(onPressed: () => _releve(context, c, partage: true), icon: const Icon(Icons.share_rounded), label: Text('Partager'.tr)),
              ]),
              if (c.telephone != null || c.adresse != null) ...[
                const SizedBox(height: 8),
                Text([if (c.telephone != null) c.telephone!, if (c.adresse != null) c.adresse!].join(' · ')),
              ],
              const SizedBox(height: 16),
              SectionTitle('Envois'.tr),
              const SizedBox(height: 8),
              if (envois.isEmpty) EmptyState('Aucun envoi.'.tr, icon: Icons.local_shipping_outlined) else AutoGrid(minItemWidth: 340, children: [for (final e in envois) CarteEnvoi(e, montrerAtelier: false)]),
              const SizedBox(height: 16),
              SectionTitle('Paiements'.tr),
              if (paiements.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('Aucun paiement.'.tr)),
              for (final p in paiements)
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: AppColors.green),
                  title: Text(fmtDA(p.montant), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([fmtDate(p.date), if (p.note != null) p.note!].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Supprimer'.tr,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'Supprimer ce paiement ?'.tr, '{0} du {1}'.trf([fmtDA(p.montant), fmtDate(p.date)]));
                      if (ok) await couture.deletePaiement(p.id);
                    },
                  ),
                ),
            ]),
          );
        },
      );
}

// ---------------------------------------------------------------------- historique

class _Historique extends StatefulWidget {
  const _Historique();

  @override
  State<_Historique> createState() => _HistoriqueState();
}

class _HistoriqueState extends State<_Historique> {
  String _q = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _listen,
        builder: (context, _) {
          final q = _q.toLowerCase();
          final liste = couture.envois.where((e) => q.isEmpty || _numero(e.lotId).toLowerCase().contains(q) || couture.nom(e.couturierId).toLowerCase().contains(q)).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            TextField(
              decoration: InputDecoration(isDense: true, hintText: 'N° de paquet ou atelier…'.tr, prefixIcon: const Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: 12),
            if (liste.isEmpty) EmptyState('Aucun envoi.'.tr, icon: Icons.history_rounded),
            for (final e in liste)
              Card(
                child: ListTile(
                  onTap: () => _detailEnvoi(context, e),
                  leading: data.lot(e.lotId) == null ? null : PuceEtape(data.lot(e.lotId)!.etape),
                  title: Text('{0} → {1}'.trf(['#${_numero(e.lotId)}', couture.nom(e.couturierId)])),
                  subtitle: Text('Parti le {0} · {1} pièces · bonnes : {2}'.trf([fmtDate(e.date), fmtInt(e.pieces), fmtInt(e.bonnes)])),
                  trailing: Text(e.termine ? 'Rendu'.tr : '{0} j'.trf([e.jours]), style: TextStyle(fontWeight: FontWeight.w700, color: e.termine ? AppColors.green : AppColors.sky)),
                ),
              ),
          ]);
        },
      );
}
