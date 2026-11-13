import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../utils.dart';

/// Génère la fiche de paie d'un ouvrier sur une période.
Future<Uint8List> buildFichePaie({
  required Ouvrier ouvrier,
  required DateTimeRangeLite periode,
  required List<Production> rows,
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

  const violet = PdfColor.fromInt(0xFF5B21B6);
  const light = PdfColor.fromInt(0xFFF0EEFB);
  const grey = PdfColor.fromInt(0xFF6B6F80);

  final sorted = [...rows]..sort((a, b) => a.dateProd.compareTo(b.dateProd));
  final totPts = sorted.fold<int>(0, (s, p) => s + p.totalPoints);
  final totRob = sorted.fold<int>(0, (s, p) => s + p.nbRobes);
  final totMt = sorted.fold<double>(0, (s, p) => s + p.montant);
  final jours = sorted.map((p) => dateKey(p.dateProd)).toSet().length;

  final parDessin = <String, List<int>>{}; // id -> [robes, points]
  for (final p in sorted) {
    final v = parDessin.putIfAbsent(p.dessinId, () => [0, 0]);
    v[0] += p.nbRobes;
    v[1] += p.totalPoints;
  }

  final doc = pw.Document(title: 'Fiche de paie ${ouvrier.nom}', author: 'Atelier Broderie', theme: theme);

  pw.Widget kpi(String label, String value) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: grey)),
            pw.SizedBox(height: 3),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        margin: const pw.EdgeInsets.only(bottom: 16),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: violet, width: 2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ATELIER BRODERIE', style: pw.TextStyle(fontSize: 10, color: violet, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            pw.Text('Fiche de paie', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Période : ${fmtDate(periode.start)} - ${fmtDate(periode.end)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Éditée le ${fmtDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: grey)),
          ]),
        ]),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: grey)),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: light, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Ouvrier', style: const pw.TextStyle(fontSize: 8, color: grey)),
              pw.Text(ouvrier.nom, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              if (ouvrier.telephone != null) pw.Text('Tél. ${ouvrier.telephone}', style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tarif actuel', style: const pw.TextStyle(fontSize: 8, color: grey)),
              pw.Text('${fmtDA(ouvrier.tarif1000)} / 1000 points', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Row(children: [
          kpi('Total points', fmtInt(totPts)),
          kpi('Robes', fmtInt(totRob)),
          kpi('Jours travaillés', '$jours'),
          kpi('Montant', fmtDA(totMt)),
        ]),
        pw.SizedBox(height: 18),
        pw.Text('Détail des travaux', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Dessin', 'Robes', 'Points/robe', 'Total points', 'Montant'],
          data: [
            for (final p in sorted)
              [
                fmtDate(p.dateProd),
                data.dessinNom(p.dessinId),
                fmtInt(p.nbRobes),
                fmtInt(p.pointsParRobe),
                fmtInt(p.totalPoints),
                fmtDA(p.montant),
              ],
          ],
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: violet),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(color: light),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          border: null,
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: violet, width: 1.5))),
          child: pw.Row(children: [
            pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Spacer(),
            pw.Text('${fmtInt(totRob)} robes   ${fmtInt(totPts)} points   ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(fmtDA(totMt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: violet)),
          ]),
        ),
        if (parDessin.length > 1) ...[
          pw.SizedBox(height: 16),
          pw.Text('Récapitulatif par dessin', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Dessin', 'Robes', 'Points'],
            data: [
              for (final e in parDessin.entries) [data.dessinNom(e.key), fmtInt(e.value[0]), fmtInt(e.value[1])],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: light),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
            border: null,
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
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B6F80))),
      pw.SizedBox(height: 36),
      pw.Container(height: 1, color: PdfColors.grey400),
    ]);

/// Plage de dates sans dépendre de Flutter material.
class DateTimeRangeLite {
  final DateTime start;
  final DateTime end;
  const DateTimeRangeLite(this.start, this.end);
}
