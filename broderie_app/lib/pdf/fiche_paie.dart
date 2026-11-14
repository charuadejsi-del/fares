import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../utils.dart';

const _violet = PdfColor.fromInt(0xFF5B21B6);
const _light = PdfColor.fromInt(0xFFF0EEFB);
const _grey = PdfColor.fromInt(0xFF6B6F80);
const _green = PdfColor.fromInt(0xFF047857);
const _red = PdfColor.fromInt(0xFFBE123C);

/// Fiche de paie d'un ouvrier : gains, avances, paiements et reste à payer.
Future<Uint8List> buildFichePaie({
  required Ouvrier ouvrier,
  required DateTimeRangeLite periode,
  required List<Production> rows,
  List<Piece> pieces = const [],
  List<Mouvement> mouvements = const [],
  Bilan bilan = const Bilan(),
}) async {
  pw.ThemeData theme;
  try {
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
    );
  } catch (_) {
    theme = pw.ThemeData.base();
  }

  final prod = [...rows]..sort((a, b) => a.dateProd.compareTo(b.dateProd));
  final pcs = [...pieces]..sort((a, b) => a.date.compareTo(b.date));
  final mvts = [...mouvements]..sort((a, b) => a.date.compareTo(b.date));
  final totPts = prod.fold<int>(0, (s, p) => s + p.totalPoints);

  final doc = pw.Document(title: 'Fiche de paie ${ouvrier.nom}', author: 'Atelier Broderie', theme: theme);

  pw.Widget title(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rowsData, Set<int> right) => pw.TableHelper.fromTextArray(
        headers: headers,
        data: rowsData,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: _light),
        cellAlignments: {for (var i = 0; i < headers.length; i++) i: right.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft},
        border: null,
      );

  pw.Widget line(String label, double v, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text('${v < 0 ? '- ' : ''}${fmtDA(v.abs())}',
              style: pw.TextStyle(fontSize: bold ? 13 : 10, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        ]),
      );

  final modeTxt = switch (ouvrier.modePaie) {
    ModePaie.points => 'Payé aux points (tarif selon le type de broderie)',
    ModePaie.mois => 'Salaire mensuel : ${fmtDA(ouvrier.salaireMensuel)}',
    ModePaie.piece => 'Payé à la pièce : ${fmtDA(ouvrier.prixPiece)} / pièce',
  };

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        margin: const pw.EdgeInsets.only(bottom: 14),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _violet, width: 2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ATELIER BRODERIE', style: pw.TextStyle(fontSize: 10, color: _violet, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            pw.Text('Fiche de paie', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Période : ${fmtDate(periode.start)} - ${fmtDate(periode.end)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Éditée le ${fmtDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: _grey)),
          ]),
        ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ),
      build: (ctx) => [
        // Identité
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _light, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Ouvrier', style: const pw.TextStyle(fontSize: 8, color: _grey)),
                pw.Text(ouvrier.nom, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.Text('${ouvrier.departement}${ouvrier.telephone != null ? '  ·  Tél. ${ouvrier.telephone}' : ''}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(modeTxt, style: const pw.TextStyle(fontSize: 9, color: _grey)),
              ]),
            ),
            if (prod.isNotEmpty)
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Tarifs broderie (1000 pts)', style: const pw.TextStyle(fontSize: 8, color: _grey)),
                for (final t in data.types.where((t) => t.actif))
                  pw.Text('${t.nom} : ${fmtDA(t.tarif1000)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
          ]),
        ),

        // Bilan
        title('Récapitulatif'),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            line('Solde reporté (avant la période)', bilan.anterieur, color: _grey),
            if (bilan.broderie != 0) line('+ Broderie (${fmtInt(totPts)} points)', bilan.broderie),
            if (bilan.pieces != 0) line('+ Travaux à la pièce', bilan.pieces),
            if (bilan.salaires != 0) line('+ Salaires', bilan.salaires),
            if (bilan.primes != 0) line('+ Primes', bilan.primes),
            line('- Avances', -bilan.avances, color: _red),
            if (bilan.retenues != 0) line('- Retenues', -bilan.retenues, color: _red),
            line('- Déjà payé', -bilan.paiements, color: _red),
            pw.Divider(color: _violet),
            line(bilan.reste < 0 ? 'AVANCE NON COUVERTE' : 'RESTE À PAYER', bilan.reste.abs(),
                bold: true, color: bilan.reste < 0 ? _red : _green),
          ]),
        ),

        if (prod.isNotEmpty) ...[
          title('Broderie : relevés du compteur'),
          table(
            ['Date', 'Équipe', 'Machine', 'Type', 'Points', 'Tarif /1000', 'Montant'],
            [
              for (final p in prod)
                [
                  fmtDate(p.dateProd),
                  p.equipe.label,
                  data.machineNom(p.machineId),
                  data.typeNom(p.typeId),
                  fmtInt(p.totalPoints),
                  fmtDA(p.tarif1000),
                  fmtDA(p.montant),
                ],
            ],
            {4, 5, 6},
          ),
        ],

        if (pcs.isNotEmpty) ...[
          title('Travaux à la pièce'),
          table(
            ['Date', 'Travail', 'Quantité', 'Prix unitaire', 'Montant'],
            [for (final p in pcs) [fmtDate(p.date), p.libelle, fmtNum(p.quantite), fmtDA(p.prixUnitaire), fmtDA(p.montant)]],
            {2, 3, 4},
          ),
        ],

        if (mvts.isNotEmpty) ...[
          title('Avances, paiements et autres mouvements'),
          table(
            ['Date', 'Opération', 'Remarque', 'Montant'],
            [
              for (final m in mvts)
                [fmtDate(m.date), m.type.label, m.note ?? '', '${m.type.signe < 0 ? '- ' : '+ '}${fmtDA(m.montant)}'],
            ],
            {3},
          ),
        ],

        pw.SizedBox(height: 40),
        pw.Row(children: [
          pw.Expanded(child: _signature('Signature de l\'ouvrier')),
          pw.SizedBox(width: 40),
          pw.Expanded(child: _signature('Signature du responsable')),
        ]),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _signature(String label) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _grey)),
      pw.SizedBox(height: 36),
      pw.Container(height: 1, color: PdfColors.grey400),
    ]);

/// Plage de dates sans dépendre de Flutter material.
class DateTimeRangeLite {
  final DateTime start;
  final DateTime end;
  const DateTimeRangeLite(this.start, this.end);
}
