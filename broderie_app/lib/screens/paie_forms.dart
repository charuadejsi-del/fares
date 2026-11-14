import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'refs_screens.dart';

/// Couleur et icône de chaque type de mouvement.
Color mvtColor(TypeMvt t) => switch (t) {
      TypeMvt.avance => AppColors.rose,
      TypeMvt.paiement => AppColors.sky,
      TypeMvt.salaire => AppColors.green,
      TypeMvt.prime => AppColors.gold,
      TypeMvt.retenue => const Color(0xFFF97316),
    };

IconData mvtIcon(TypeMvt t) => switch (t) {
      TypeMvt.avance => Icons.north_east_rounded,
      TypeMvt.paiement => Icons.payments_rounded,
      TypeMvt.salaire => Icons.account_balance_wallet_rounded,
      TypeMvt.prime => Icons.star_rounded,
      TypeMvt.retenue => Icons.remove_circle_outline_rounded,
    };

String mvtHelp(TypeMvt t) => switch (t) {
      TypeMvt.avance => 'Argent donné à l\'avance : il sera déduit de la paie.',
      TypeMvt.paiement => 'Argent versé à l\'ouvrier pour régler sa paie.',
      TypeMvt.salaire => 'Salaire gagné (ex. salaire du mois) : ajouté au montant dû.',
      TypeMvt.prime => 'Prime ou bonus : ajouté au montant dû.',
      TypeMvt.retenue => 'Retenue (absence, erreur…) : déduite de la paie.',
    };

/// Ouvre le formulaire d'un mouvement d'argent.
Future<void> openMouvementForm(BuildContext context, Ouvrier o, TypeMvt type, {Mouvement? existing, double? montant, String? note}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => MouvementForm(ouvrier: o, type: type, existing: existing, montantInitial: montant, noteInitiale: note),
  );
  if (ok == true && context.mounted) showSnack(context, '${type.label} enregistré${type == TypeMvt.avance || type == TypeMvt.paiement || type == TypeMvt.salaire ? '' : 'e'}');
}

class MouvementForm extends StatefulWidget {
  final Ouvrier ouvrier;
  final TypeMvt type;
  final Mouvement? existing;
  final double? montantInitial;
  final String? noteInitiale;
  const MouvementForm({super.key, required this.ouvrier, required this.type, this.existing, this.montantInitial, this.noteInitiale});

  @override
  State<MouvementForm> createState() => _MouvementFormState();
}

class _MouvementFormState extends State<MouvementForm> {
  final _form = GlobalKey<FormState>();
  late TypeMvt _type = widget.existing?.type ?? widget.type;
  late DateTime _date = widget.existing?.date ?? dayOnly(DateTime.now());
  late final _montant = TextEditingController(
    text: widget.existing != null
        ? _fmt(widget.existing!.montant)
        : (widget.montantInitial != null && widget.montantInitial! > 0 ? _fmt(widget.montantInitial!) : ''),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? widget.noteInitiale ?? '');
  bool _busy = false;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _montant.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _montant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveMouvement(
        Mouvement.toRow(
          ouvrierId: widget.ouvrier.id,
          dateKey: dateKey(_date),
          type: _type,
          montant: parseNum(_montant.text)!,
          note: _note.text,
        ),
        id: widget.existing?.id,
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
  Widget build(BuildContext context) {
    final solde = data.solde(widget.ouvrier.id).solde;
    final m = parseNum(_montant.text) ?? 0;
    final apres = solde + (widget.existing == null ? _type.signe * m : 0);
    final c = mvtColor(_type);
    return FormDialog(
      title: '${_type.label} · ${widget.ouvrier.nom}',
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in TypeMvt.values)
            ChoiceChip(
              avatar: Icon(mvtIcon(t), size: 16, color: _type == t ? Colors.white : mvtColor(t)),
              label: Text(t.label),
              selected: _type == t,
              selectedColor: mvtColor(t),
              labelStyle: TextStyle(color: _type == t ? Colors.white : null, fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _type = t),
            ),
        ]),
        Text(mvtHelp(_type), style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
        TextFormField(
          controller: _montant,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c),
          decoration: InputDecoration(labelText: 'Montant', suffixText: 'DA', prefixIcon: Icon(mvtIcon(_type), color: c)),
          validator: (v) {
            final n = parseNum(v ?? '');
            return (n == null || n <= 0) ? 'Montant supérieur à 0' : null;
          },
        ),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
            child: Text(fmtDate(_date)),
          ),
        ),
        TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
        if (widget.existing == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _line(context, 'Solde actuel', solde),
              const SizedBox(height: 4),
              _line(context, 'Après ce mouvement', apres, bold: true),
            ]),
          ),
      ],
    );
  }

  Widget _line(BuildContext context, String label, double v, {bool bold = false}) => Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: context.pal.muted, fontWeight: bold ? FontWeight.w700 : null))),
        Text(soldeLabel(v), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: soldeColor(v))),
      ]);
}

String soldeLabel(double v) {
  if (v.abs() < 0.005) return 'À jour (0 DA)';
  return v > 0 ? 'À payer ${fmtDA(v)}' : 'Avance ${fmtDA(-v)}';
}

Color soldeColor(double v) => v.abs() < 0.005 ? const Color(0xFF9AA0B4) : (v > 0 ? AppColors.green : AppColors.rose);

/// Formulaire d'un travail payé à la pièce.
Future<void> openPieceForm(BuildContext context, Ouvrier o, {Piece? existing}) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => PieceForm(ouvrier: o, existing: existing));
  if (ok == true && context.mounted) showSnack(context, 'Pièces enregistrées');
}

class PieceForm extends StatefulWidget {
  final Ouvrier ouvrier;
  final Piece? existing;
  const PieceForm({super.key, required this.ouvrier, this.existing});

  @override
  State<PieceForm> createState() => _PieceFormState();
}

class _PieceFormState extends State<PieceForm> {
  final _form = GlobalKey<FormState>();
  late DateTime _date = widget.existing?.date ?? dayOnly(DateTime.now());
  late final _libelle = TextEditingController(text: widget.existing?.libelle ?? 'Robe');
  late final _qte = TextEditingController(text: widget.existing == null ? '' : _fmt(widget.existing!.quantite));
  late final _prix = TextEditingController(
    text: _fmt(widget.existing?.prixUnitaire ?? widget.ouvrier.prixPiece),
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _busy = false;

  static String _fmt(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    _qte.addListener(() => setState(() {}));
    _prix.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _libelle.dispose();
    _qte.dispose();
    _prix.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.savePiece(
        Piece.toRow(
          ouvrierId: widget.ouvrier.id,
          dateKey: dateKey(_date),
          libelle: _libelle.text,
          quantite: parseNum(_qte.text)!,
          prixUnitaire: parseNum(_prix.text) ?? 0,
          note: _note.text,
        ),
        id: widget.existing?.id,
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
  Widget build(BuildContext context) {
    final total = (parseNum(_qte.text) ?? 0) * (parseNum(_prix.text) ?? 0);
    return FormDialog(
      title: 'Pièces · ${widget.ouvrier.nom}',
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        TextFormField(
          controller: _libelle,
          decoration: const InputDecoration(labelText: 'Travail (ex. Robe cousue, Repassage)', prefixIcon: Icon(Icons.checkroom_rounded)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in const ['Robe', 'Robe cousue', 'Repassage', 'Finition', 'Coupe'])
            ActionChip(label: Text(s), onPressed: () => _libelle.text = s),
        ]),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _qte,
              autofocus: widget.existing == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantité', prefixIcon: Icon(Icons.numbers)),
              validator: (v) {
                final n = parseNum(v ?? '');
                return (n == null || n <= 0) ? 'Supérieur à 0' : null;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _prix,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix / pièce', suffixText: 'DA'),
              validator: (v) {
                final n = parseNum(v ?? '');
                return (n == null || n < 0) ? 'Invalide' : null;
              },
            ),
          ),
        ]),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
            child: Text(fmtDate(_date)),
          ),
        ),
        TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('${_qte.text.isEmpty ? '0' : _qte.text} × ${fmtDA(parseNum(_prix.text) ?? 0)}', style: const TextStyle(color: Colors.white70)),
            Text(fmtDA(total), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          ]),
        ),
      ],
    );
  }
}

/// Une ligne du journal d'un ouvrier (production, pièces ou argent).
class JournalItem {
  final DateTime date;
  final DateTime tri;
  final String titre;
  final String detail;
  final double montant; // signé : + gagné, − déduit
  final IconData icon;
  final Color color;
  final VoidCallback? onEdit;
  final Future<void> Function() onDelete;

  const JournalItem({
    required this.date,
    required this.tri,
    required this.titre,
    required this.detail,
    required this.montant,
    required this.icon,
    required this.color,
    required this.onDelete,
    this.onEdit,
  });
}

class JournalTile extends StatelessWidget {
  final JournalItem item;
  const JournalTile(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final plus = item.montant >= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.titre, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text('${fmtDate(item.date)} · ${item.detail}',
                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text('${plus ? '+' : '−'} ${fmtDA(item.montant.abs())}',
              style: TextStyle(fontWeight: FontWeight.w800, color: plus ? AppColors.green : AppColors.rose)),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.pal.muted, size: 20),
            itemBuilder: (_) => [
              if (item.onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Modifier')),
              const PopupMenuItem(value: 'del', child: Text('Supprimer')),
            ],
            onSelected: (v) async {
              if (v == 'edit') {
                item.onEdit?.call();
              } else if (await confirmDialog(context, 'Supprimer', 'Supprimer « ${item.titre} » du ${fmtDate(item.date)} ?')) {
                try {
                  await item.onDelete();
                  if (context.mounted) showSnack(context, 'Supprimé');
                } catch (e) {
                  if (context.mounted) showSnack(context, errorMessage(e), error: true);
                }
              }
            },
          ),
        ]),
      ),
    );
  }
}

/// Carte du solde global d'un ouvrier avec boutons d'action.
class SoldeCard extends StatelessWidget {
  final Ouvrier ouvrier;
  const SoldeCard(this.ouvrier, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final s = data.solde(ouvrier.id);
          final v = s.solde;
          final grad = v < -0.005
              ? const LinearGradient(colors: [Color(0xFFBE123C), Color(0xFFF43F5E)])
              : const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]);
          final mois = fmtMonthYear(DateTime.now());
          return AppCard(
            gradient: grad,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(v < -0.005 ? 'Avance non couverte' : 'Reste à payer', style: const TextStyle(color: Colors.white70)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(fmtDA(v.abs()), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              ),
              Text('Gagné ${fmtDA(s.gains)} · Avances ${fmtDA(s.avances)} · Payé ${fmtDA(s.paiements)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _btn(context, Icons.north_east_rounded, 'Avance', () => openMouvementForm(context, ouvrier, TypeMvt.avance)),
                _btn(context, Icons.payments_rounded, 'Payer', () => openMouvementForm(context, ouvrier, TypeMvt.paiement, montant: v > 0 ? v : null)),
                if (ouvrier.modePaie == ModePaie.mois)
                  _btn(context, Icons.account_balance_wallet_rounded, 'Salaire du mois',
                      () => openMouvementForm(context, ouvrier, TypeMvt.salaire, montant: ouvrier.salaireMensuel, note: 'Salaire $mois')),
                if (ouvrier.modePaie == ModePaie.piece)
                  _btn(context, Icons.add_box_rounded, 'Pièces', () => openPieceForm(context, ouvrier)),
                _btn(context, Icons.star_rounded, 'Prime', () => openMouvementForm(context, ouvrier, TypeMvt.prime)),
                _btn(context, Icons.remove_circle_outline_rounded, 'Retenue', () => openMouvementForm(context, ouvrier, TypeMvt.retenue)),
              ]),
            ]),
          );
        },
      );

  Widget _btn(BuildContext context, IconData i, String label, VoidCallback onTap) => Material(
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
