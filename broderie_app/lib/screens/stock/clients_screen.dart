import 'package:flutter/material.dart';

import '../../data/session.dart';
import '../../data/stock.dart';
import '../../pdf/documents.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import '../refs_screens.dart' show FormDialog;
import '../../data/commerce.dart';
import 'avoirs_screen.dart';
import 'ventes_screen.dart';

Color soldeClientColor(double s) => s > 0.005 ? AppColors.rose : (s < -0.005 ? AppColors.green : const Color(0xFF9AA0B4));

String soldeClientTexte(double s) {
  if (s.abs() < 0.005) return 'À jour';
  return s > 0 ? 'Reste ${fmtDA(s)}' : 'Crédit ${fmtDA(-s)}';
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _q = '';
  bool _dettes = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final q = _q.toLowerCase();
          final list = stock.clients
              .where((c) => !_dettes || c.solde > 0.005)
              .where((c) => q.isEmpty || c.nom.toLowerCase().contains(q) || (c.telephone ?? '').contains(q) || (c.wilaya ?? '').toLowerCase().contains(q))
              .toList()
            ..sort((a, b) => _dettes ? b.solde.compareTo(a.solde) : a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-client',
              onPressed: () => ouvrirClientForm(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nouveau client'),
            ),
            body: RefreshIndicator(
              onRefresh: stock.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  AutoGrid(minItemWidth: 190, children: [
                    StatTile(label: 'Reste à encaisser (clients)', value: fmtDA(stock.totalCreances), icon: Icons.account_balance_wallet_rounded, color: AppColors.rose),
                    StatTile(label: 'Clients', value: '${stock.clients.length}', icon: Icons.storefront_rounded, color: AppColors.sky),
                    StatTile(label: 'Clients qui doivent', value: '${stock.clients.where((c) => c.solde > 0.005).length}', icon: Icons.warning_amber_rounded, color: const Color(0xFFF97316)),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(hintText: 'Nom, téléphone, wilaya…', prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                    FilterChip(label: const Text('Seulement ceux qui doivent'), selected: _dettes, onSelected: (v) => setState(() => _dettes = v)),
                  ]),
                  const SizedBox(height: 14),
                  if (list.isEmpty)
                    EmptyState(stock.clients.isEmpty ? 'Aucun client.\nAjoutez vos clients de gros.' : 'Aucun résultat.', icon: Icons.storefront_outlined)
                  else
                    AutoGrid(minItemWidth: 320, children: [
                      for (final c in list)
                        AppCard(
                          padding: const EdgeInsets.all(14),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: c.id))),
                          child: Row(children: [
                            NameAvatar(c.nom, size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5), overflow: TextOverflow.ellipsis),
                                Text([if (c.telephone != null) c.telephone!, if (c.wilaya != null) c.wilaya!, '${c.nbVentes} vente${c.nbVentes > 1 ? 's' : ''}'].join(' · '),
                                    style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: soldeClientColor(c.solde).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                              child: Text(soldeClientTexte(c.solde), style: TextStyle(color: soldeClientColor(c.solde), fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ),
                    ]),
                ],
              ),
            ),
          );
        },
      );
}

Future<String?> ouvrirClientForm(BuildContext context, {Client? client}) =>
    showDialog<String>(context: context, builder: (_) => ClientForm(client: client));

class ClientForm extends StatefulWidget {
  final Client? client;
  const ClientForm({super.key, this.client});

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.client?.nom);
  late final _tel = TextEditingController(text: widget.client?.telephone);
  late final _adr = TextEditingController(text: widget.client?.adresse);
  late final _wil = TextEditingController(text: widget.client?.wilaya);
  late final _rc = TextEditingController(text: widget.client?.rc);
  late final _nif = TextEditingController(text: widget.client?.nif);
  late final _note = TextEditingController(text: widget.client?.note);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nom, _tel, _adr, _wil, _rc, _nif, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await stock.saveClient(
        Client.toRow(nom: _nom.text, telephone: _tel.text, adresse: _adr.text, wilaya: _wil.text, rc: _rc.text, nif: _nif.text, note: _note.text),
        id: widget.client?.id,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.client == null ? 'Nouveau client' : 'Modifier le client',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: widget.client == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom / raison sociale', prefixIcon: Icon(Icons.storefront_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(controller: _tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined))),
          TextFormField(controller: _adr, decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.place_outlined))),
          TextFormField(controller: _wil, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Wilaya', prefixIcon: Icon(Icons.map_outlined))),
          Row(children: [
            Expanded(child: TextFormField(controller: _rc, decoration: const InputDecoration(labelText: 'RC'))),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _nif, decoration: const InputDecoration(labelText: 'NIF'))),
          ]),
          TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque', prefixIcon: Icon(Icons.notes))),
        ],
      );
}

// ======================================================================= versement

Future<void> ouvrirVersementForm(BuildContext context, Client c, {Vente? vente, Versement? existant}) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => VersementForm(client: c, vente: vente, existant: existant));
  if (ok == true && context.mounted) showSnack(context, 'Versement enregistré');
}

class VersementForm extends StatefulWidget {
  final Client client;
  final Vente? vente;
  final Versement? existant;
  const VersementForm({super.key, required this.client, this.vente, this.existant});

  @override
  State<VersementForm> createState() => _VersementFormState();
}

class _VersementFormState extends State<VersementForm> {
  final _form = GlobalKey<FormState>();
  late final _mt = TextEditingController(
    text: widget.existant != null
        ? _f(widget.existant!.montant)
        : _f(widget.vente != null ? widget.vente!.reste : (widget.client.solde > 0 ? widget.client.solde : 0)),
  );
  late final _note = TextEditingController(text: widget.existant?.note ?? '');
  late DateTime _date = widget.existant?.date ?? dayOnly(DateTime.now());
  late String _mode = widget.existant?.mode ?? 'especes';
  late String? _venteId = widget.existant?.venteId ?? widget.vente?.id;
  List<Vente> _impayees = [];
  bool _busy = false;

  static String _f(double v) => v <= 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2));

  @override
  void initState() {
    super.initState();
    stock.ventes(clientId: widget.client.id).then((l) {
      if (mounted) setState(() => _impayees = l.where((v) => !v.annulee && (v.reste > 0.005 || v.id == _venteId)).toList());
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _mt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await stock.saveVersement(
        id: widget.existant?.id,
        clientId: widget.client.id,
        venteId: _venteId,
        date: _date,
        montant: parseNum(_mt.text)!,
        mode: _mode,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: 'Versement · ${widget.client.nom}',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Expanded(child: Text('Solde du client')),
              Text(soldeClientTexte(widget.client.solde), style: TextStyle(fontWeight: FontWeight.w900, color: soldeClientColor(widget.client.solde))),
            ]),
          ),
          TextFormField(
            controller: _mt,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.green),
            decoration: const InputDecoration(labelText: 'Montant versé', suffixText: 'DA', prefixIcon: Icon(Icons.payments_rounded)),
            validator: (v) {
              final n = parseNum(v ?? '');
              return (n == null || n <= 0) ? 'Montant supérieur à 0' : null;
            },
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in modesPaiement.entries)
              ChoiceChip(label: Text(m.value), selected: _mode == m.key, onSelected: (_) => setState(() => _mode = m.key)),
          ]),
          DropdownButtonFormField<String?>(
            value: _impayees.any((v) => v.id == _venteId) ? _venteId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pour la facture', prefixIcon: Icon(Icons.receipt_long_outlined)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Acompte sur le compte (sans facture précise)')),
              for (final v in _impayees)
                DropdownMenuItem<String?>(value: v.id, child: Text('${v.numero} · ${fmtDate(v.date)} · reste ${fmtDA(v.reste)}')),
            ],
            onChanged: (v) => setState(() => _venteId = v),
          ),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)), child: Text(fmtDate(_date))),
          ),
          TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (n° de chèque…)', prefixIcon: Icon(Icons.notes))),
        ],
      );
}

// ======================================================================= fiche client

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  List<Vente> _ventes = [];
  List<Versement> _versements = [];
  List<Avoir> _avoirs = [];
  bool _loading = true;
  bool _pdf = false;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    stock.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    stock.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (stock.version != _seen) _load();
  }

  Future<void> _load() async {
    _seen = stock.version;
    try {
      final r = await Future.wait<Object>([
        stock.ventes(clientId: widget.clientId),
        stock.versements(clientId: widget.clientId),
        commerce.avoirs(clientId: widget.clientId),
      ]);
      if (mounted) {
        setState(() {
          _ventes = r[0] as List<Vente>;
          _versements = r[1] as List<Versement>;
          _avoirs = r[2] as List<Avoir>;
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _releve(Client c, {bool share = false}) async {
    setState(() => _pdf = true);
    try {
      final bytes = await buildReleveClient(
        atelier: session.atelier!,
        client: c,
        ventes: _ventes,
        versements: _versements,
        avoirs: [for (final a in _avoirs) (a.date, 'Avoir ${a.numero} (retour)', a.total)],
      );
      final nom = 'releve_${c.nom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';
      share ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _pdf = false);
    }
  }

  Future<void> _supprimer(Client c) async {
    if (!await confirmDialog(context, 'Supprimer', 'Supprimer le client ${c.nom} ?')) return;
    try {
      await stock.deleteClient(c.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'Impossible : ce client a des ventes ou des versements.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final c = stock.client(widget.clientId);
          if (c == null) return Scaffold(appBar: AppBar(), body: const EmptyState('Client introuvable.'));
          final grad = c.solde > 0.005
              ? const LinearGradient(colors: [Color(0xFFBE123C), Color(0xFFF43F5E)])
              : const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]);
          return Scaffold(
            appBar: AppBar(title: Text(c.nom), actions: [
              IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => ouvrirClientForm(context, client: c)),
              PopupMenuButton<String>(
                itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Supprimer'))],
                onSelected: (_) => _supprimer(c),
              ),
            ]),
            body: RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                  gradient: grad,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(c.solde > 0.005 ? 'Reste à payer' : (c.solde < -0.005 ? 'Crédit du client' : 'Compte à jour'),
                        style: const TextStyle(color: Colors.white70)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(fmtDA(c.solde.abs()), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                    ),
                    Text('Achats ${fmtDA(c.totalAchats)} · Versé ${fmtDA(c.totalVerse)}${c.totalAvoirs > 0 ? ' · Avoirs ${fmtDA(c.totalAvoirs)}' : ''} · ${c.nbVentes} vente(s)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _btn(Icons.payments_rounded, 'Versement', () => ouvrirVersementForm(context, c)),
                      _btn(Icons.add_shopping_cart_rounded, 'Nouvelle vente',
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NouvelleVenteScreen(clientId: c.id)))),
                      _btn(Icons.undo_rounded, 'Retour', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvoirEditorScreen(client: c)))),
                      _btn(Icons.print_rounded, _pdf ? '…' : 'Relevé PDF', _pdf ? null : () => _releve(c)),
                      _btn(Icons.share_rounded, 'Partager', _pdf ? null : () => _releve(c, share: true)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('Coordonnées'),
                    if (c.telephone != null) _info(Icons.phone_outlined, c.telephone!),
                    if (c.adresse != null || c.wilaya != null) _info(Icons.place_outlined, [if (c.adresse != null) c.adresse!, if (c.wilaya != null) c.wilaya!].join(', ')),
                    if (c.rc != null || c.nif != null) _info(Icons.badge_outlined, [if (c.rc != null) 'RC ${c.rc}', if (c.nif != null) 'NIF ${c.nif}'].join(' · ')),
                    if (c.note != null) _info(Icons.notes, c.note!),
                    if (c.telephone == null && c.adresse == null && c.wilaya == null) Text('—', style: TextStyle(color: context.pal.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Ventes'),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_ventes.isEmpty)
                      const EmptyState('Aucune vente.', icon: Icons.receipt_long_outlined)
                    else
                      for (final v in _ventes) VenteTile(v, showClient: false),
                  ]),
                ),
                const SizedBox(height: 12),
                _PrixSpeciaux(client: c),
                if (_avoirs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Retours (avoirs)'),
                      for (final a in _avoirs) AvoirTile(a),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionTitle('Versements'),
                    if (_versements.isEmpty && !_loading)
                      const EmptyState('Aucun versement.', icon: Icons.payments_outlined)
                    else
                      for (final x in _versements) VersementTile(x, client: c, ventes: _ventes),
                  ]),
                ),
              ]),
            ),
          );
        },
      );

  Widget _info(IconData i, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Icon(i, size: 18, color: context.pal.muted), const SizedBox(width: 10), Expanded(child: Text(t))]),
      );

  Widget _btn(IconData i, String label, VoidCallback? onTap) => Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class VersementTile extends StatelessWidget {
  final Versement x;
  final Client client;
  final List<Vente> ventes;
  const VersementTile(this.x, {super.key, required this.client, this.ventes = const []});

  @override
  Widget build(BuildContext context) {
    String? numero;
    for (final v in ventes) {
      if (v.id == x.venteId) numero = v.numero;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.payments_rounded, color: AppColors.green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${x.modeTexte}${numero != null ? ' · $numero' : ' · acompte'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${fmtDate(x.date)}${x.note != null ? ' · ${x.note}' : ''}', style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
          ]),
        ),
        Text('+ ${fmtDA(x.montant)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.green)),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: context.pal.muted, size: 20),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Modifier')),
            PopupMenuItem(value: 'del', child: Text('Supprimer')),
          ],
          onSelected: (v) async {
            if (v == 'edit') {
              await ouvrirVersementForm(context, client, existant: x);
            } else if (await confirmDialog(context, 'Supprimer', 'Supprimer ce versement de ${fmtDA(x.montant)} ?')) {
              try {
                await stock.deleteVersement(x.id);
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

/// Prix spéciaux d'un client de gros.
class _PrixSpeciaux extends StatelessWidget {
  final Client client;
  const _PrixSpeciaux({required this.client});

  Future<void> _edit(BuildContext context, {Produit? produit}) async {
    Produit? p = produit;
    p ??= await showDialog<Produit>(context: context, builder: (_) => const ChoixProduitDialog());
    if (p == null || !context.mounted) return;
    final actuel = stock.prixClients[client.id]?[p.id];
    final c = TextEditingController(text: actuel == null ? '' : actuel.toStringAsFixed(actuel == actuel.roundToDouble() ? 0 : 2));
    final prod = p;
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Prix spécial · ${prod.reference}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${prod.libelle}\nPrix de gros normal : ${fmtDA(prod.prixGros)}'),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Prix pour ${client.nom}', suffixText: 'DA'),
          ),
        ]),
        actions: [
          if (actuel != null) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Retirer')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (v == null) return;
    try {
      await commerce.setPrixClient(client.id, prod.id, v.isEmpty ? null : parseNum(v));
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prix = stock.prixClients[client.id] ?? {};
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Prix spéciaux', subtitle: 'Appliqués automatiquement dans ses ventes et commandes',
            trailing: IconButton.filledTonal(tooltip: 'Ajouter', onPressed: () => _edit(context), icon: const Icon(Icons.add_rounded))),
        if (prix.isEmpty)
          Text('Aucun : ce client paie le prix de gros normal.', style: TextStyle(color: context.pal.muted))
        else
          for (final e in prix.entries)
            Builder(builder: (context) {
              final p = stock.produit(e.key);
              if (p == null) return const SizedBox.shrink();
              return InkWell(
                onTap: () => _edit(context, produit: p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text('${p.reference} · ${p.libelle}', overflow: TextOverflow.ellipsis)),
                    Text(fmtDA(p.prixGros), style: TextStyle(color: context.pal.muted, decoration: TextDecoration.lineThrough)),
                    const SizedBox(width: 8),
                    Text(fmtDA(e.value), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.green)),
                  ]),
                ),
              );
            }),
      ]),
    );
  }
}
