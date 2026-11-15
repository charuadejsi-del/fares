import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/commerce.dart';
import '../../data/session.dart';
import '../../data/stock.dart';
import '../../pdf/documents.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import 'ventes_screen.dart' show ChoixProduitDialog;

/// Création d'un avoir (retour client). Depuis une vente : les articles de la facture sont proposés.
class AvoirEditorScreen extends StatefulWidget {
  final Client client;
  final Vente? vente;
  final List<VenteLigne> lignesVente;
  const AvoirEditorScreen({super.key, required this.client, this.vente, this.lignesVente = const []});

  @override
  State<AvoirEditorScreen> createState() => _AvoirEditorScreenState();
}

class _Retour {
  final String produitId;
  final String reference;
  final String designation;
  final int max;
  int quantite = 0;
  double prix;
  _Retour(this.produitId, this.reference, this.designation, this.max, this.prix);
}

class _AvoirEditorScreenState extends State<AvoirEditorScreen> {
  final List<_Retour> _lignes = [];
  final _motif = TextEditingController();
  bool _remettre = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in widget.lignesVente) {
      _lignes.add(_Retour(l.produitId, l.reference, l.designation, l.quantite, l.prixUnitaire));
    }
  }

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  double get _total => _lignes.fold<double>(0, (s, l) => s + l.quantite * l.prix);
  int get _qte => _lignes.fold<int>(0, (s, l) => s + l.quantite);

  Future<void> _ajouterProduit() async {
    final p = await showDialog<Produit>(context: context, builder: (_) => const ChoixProduitDialog());
    if (p == null) return;
    setState(() {
      final i = _lignes.indexWhere((l) => l.produitId == p.id);
      if (i >= 0) {
        _lignes[i].quantite++;
      } else {
        _lignes.add(_Retour(p.id, p.reference, p.libelle, 999999, stock.prixPour(p, widget.client.id))..quantite = 1);
      }
    });
  }

  Future<void> _save() async {
    final l = _lignes.where((x) => x.quantite > 0).toList();
    if (l.isEmpty) {
      showSnack(context, 'Indiquez au moins une pièce retournée', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await commerce.creerAvoir(
        clientId: widget.client.id,
        venteId: widget.vente?.id,
        lignes: [for (final x in l) (x.produitId, x.quantite, x.prix)],
        motif: _motif.text,
        remettreEnStock: _remettre,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final av = (await commerce.avoirs(clientId: widget.client.id)).firstWhere((a) => a.id == id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AvoirDetailScreen(avoir: av)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.vente != null ? 'Retour sur ${widget.vente!.numero}' : 'Retour · ${widget.client.nom}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Pièces retournées', subtitle: '${fmtInt(_qte)} pièce(s)', trailing: widget.vente == null
                  ? OutlinedButton.icon(onPressed: _ajouterProduit, icon: const Icon(Icons.add_rounded), label: const Text('Ajouter'))
                  : null),
              if (_lignes.isEmpty)
                const EmptyState('Ajoutez les articles retournés.', icon: Icons.undo_rounded)
              else
                for (final l in _lignes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.reference, style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary)),
                          Text(l.designation, overflow: TextOverflow.ellipsis),
                          Text('${fmtDA(l.prix)} / pièce${l.max < 999999 ? ' · vendu : ${l.max}' : ''}',
                              style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                        ]),
                      ),
                      IconButton.filledTonal(
                        onPressed: l.quantite > 0 ? () => setState(() => l.quantite--) : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text('${l.quantite}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                      IconButton.filledTonal(
                        onPressed: l.quantite < l.max ? () => setState(() => l.quantite++) : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ]),
                  ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remettre les pièces dans le stock'),
                subtitle: const Text('Désactivez si les pièces sont abîmées et ne peuvent pas être revendues'),
                value: _remettre,
                onChanged: (v) => setState(() => _remettre = v),
              ),
              TextField(controller: _motif, decoration: const InputDecoration(labelText: 'Motif du retour', prefixIcon: Icon(Icons.notes))),
              const Divider(height: 24),
              Row(children: [
                const Expanded(child: Text('Montant de l\'avoir', style: TextStyle(fontWeight: FontWeight.w900))),
                Text(fmtDA(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.green)),
              ]),
              Text('Ce montant est déduit de ce que doit le client.', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy || _qte == 0 ? null : _save,
                  icon: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(_qte == 0 ? 'Choisissez les pièces' : 'Créer l\'avoir · ${fmtDA(_total)}'),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class AvoirDetailScreen extends StatefulWidget {
  final Avoir avoir;
  const AvoirDetailScreen({super.key, required this.avoir});

  @override
  State<AvoirDetailScreen> createState() => _AvoirDetailScreenState();
}

class _AvoirDetailScreenState extends State<AvoirDetailScreen> {
  List<AvoirLigne> _lignes = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    commerce.avoirLignes(widget.avoir.id).then((l) {
      if (mounted) setState(() => _lignes = l);
    }).catchError((_) {});
  }

  Future<void> _pdf({bool share = false}) async {
    final a = widget.avoir;
    setState(() => _busy = true);
    try {
      final bytes = await buildDocumentCommercial(
        atelier: session.atelier!,
        titre: 'AVOIR',
        infos: [
          ['N°', a.numero],
          ['Date', fmtDate(a.date)],
          if (a.venteNumero != null) ['Facture', a.venteNumero!],
        ],
        titreClient: 'Client',
        client: stock.client(a.clientId),
        lignes: [
          for (final l in _lignes)
            (
              reference: stock.produit(l.produitId)?.reference ?? '',
              designation: stock.produit(l.produitId)?.libelle ?? '',
              quantite: l.quantite,
              prix: l.prixUnitaire,
              montant: l.montant,
            ),
        ],
        totaux: [('MONTANT DE L\'AVOIR', a.total, true)],
        montantLettres: a.total,
        phraseLettres: 'Arrêté le présent avoir à la somme de :',
        note: [if (a.motif != null) 'Motif : ${a.motif}', a.remisEnStock ? 'Marchandise reprise en stock.' : 'Marchandise non remise en stock.'].join('\n'),
      );
      final nom = '${a.numero}.pdf';
      share ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.avoir;
    return Scaffold(
      appBar: AppBar(title: Text(a.numero)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Avoir ${a.numero}${a.venteNumero != null ? ' · facture ${a.venteNumero}' : ''}', style: const TextStyle(color: Colors.white70)),
            Text(a.clientNom ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(fmtDA(a.total), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            Text('${fmtDate(a.date)} · ${fmtInt(a.nbArticles)} pièce(s) · ${a.remisEnStock ? 'remis en stock' : 'non remis en stock'}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF047857)),
                onPressed: _busy ? null : () => _pdf(),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Avoir PDF'),
              ),
              IconButton.filledTonal(onPressed: _busy ? null : () => _pdf(share: true), icon: const Icon(Icons.share_rounded)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Articles'),
            for (final l in _lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text('${stock.produit(l.produitId)?.reference ?? ''} · ${stock.produit(l.produitId)?.libelle ?? ''}')),
                  Text('${fmtInt(l.quantite)} × ${fmtDA(l.prixUnitaire)} = ${fmtDA(l.montant)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            if (a.motif != null) ...[const SizedBox(height: 8), Text('Motif : ${a.motif}')],
          ]),
        ),
      ]),
    );
  }
}

class AvoirTile extends StatelessWidget {
  final Avoir a;
  const AvoirTile(this.a, {super.key});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AvoirDetailScreen(avoir: a))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.undo_rounded, color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Avoir ${a.numero}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${fmtDate(a.date)} · ${fmtInt(a.nbArticles)} pièce(s)${a.motif != null ? ' · ${a.motif}' : ''}',
                    style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Text('− ${fmtDA(a.total)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.teal)),
          ]),
        ),
      );
}
