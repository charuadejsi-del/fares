import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/session.dart';
import '../data/stock.dart';
import '../utils.dart';

const _violet = PdfColor.fromInt(0xFF5B21B6);
const _light = PdfColor.fromInt(0xFFF0EEFB);
const _grey = PdfColor.fromInt(0xFF6B6F80);
const _green = PdfColor.fromInt(0xFF047857);
const _red = PdfColor.fromInt(0xFFBE123C);

pw.ThemeData? _theme;

Future<pw.ThemeData> _pdfTheme() async {
  if (_theme != null) return _theme!;
  try {
    _theme = pw.ThemeData.withFont(base: await PdfGoogleFonts.interRegular(), bold: await PdfGoogleFonts.interBold());
  } catch (_) {
    _theme = pw.ThemeData.base();
  }
  return _theme!;
}

// ============================================================== montant en lettres

const _unites = [
  'zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix',
  'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf',
];
const _dizaines = ['', 'dix', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante', 'quatre-vingt', 'quatre-vingt'];

String _moinsDeCent(int n) {
  if (n < 20) return _unites[n];
  final d = n ~/ 10, u = n % 10;
  if (d == 7 || d == 9) {
    if (d == 7 && u == 1) return 'soixante et onze';
    return '${_dizaines[d]}-${_unites[10 + u]}';
  }
  if (u == 0) return d == 8 ? 'quatre-vingts' : _dizaines[d];
  if (u == 1 && d != 8) return '${_dizaines[d]} et un';
  return '${_dizaines[d]}-${_unites[u]}';
}

String _moinsDeMille(int n) {
  final c = n ~/ 100, r = n % 100;
  if (c == 0) return _moinsDeCent(r);
  final cent = c == 1 ? 'cent' : '${_unites[c]} cent';
  if (r == 0) return c > 1 ? '${cent}s' : cent;
  return '$cent ${_moinsDeCent(r)}';
}

/// 12345 → « douze mille trois cent quarante-cinq »
String nombreEnLettres(int n) {
  if (n == 0) return 'zéro';
  if (n < 0) return 'moins ${nombreEnLettres(-n)}';
  final parts = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n ~/ 1000000) % 1000;
  final milliers = (n ~/ 1000) % 1000;
  final reste = n % 1000;
  String sansS(String s) => s.endsWith('cents') || s.endsWith('vingts') ? s.substring(0, s.length - 1) : s;
  if (milliards > 0) parts.add('${_moinsDeMille(milliards)} milliard${milliards > 1 ? 's' : ''}');
  if (millions > 0) parts.add('${_moinsDeMille(millions)} million${millions > 1 ? 's' : ''}');
  if (milliers > 0) parts.add(milliers == 1 ? 'mille' : '${sansS(_moinsDeMille(milliers))} mille');
  if (reste > 0) parts.add(_moinsDeMille(reste));
  return parts.join(' ');
}

String montantEnLettres(double montant) {
  final dinars = montant.floor();
  final centimes = ((montant - dinars) * 100).round();
  var s = '${nombreEnLettres(dinars)} dinar${dinars > 1 ? 's' : ''} algérien${dinars > 1 ? 's' : ''}';
  if (centimes > 0) s += ' et ${nombreEnLettres(centimes)} centime${centimes > 1 ? 's' : ''}';
  return s[0].toUpperCase() + s.substring(1);
}

// ============================================================== éléments communs

pw.Widget _entete(Atelier a, String titre, List<List<String>> infos) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(a.nom.toUpperCase(), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _violet)),
            if (a.activite != null) pw.Text(a.activite!, style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.SizedBox(height: 4),
            if (a.adresse != null) pw.Text(a.adresse!, style: const pw.TextStyle(fontSize: 9)),
            if (a.telephone != null || a.email != null)
              pw.Text([if (a.telephone != null) 'Tél. ${a.telephone}', if (a.email != null) a.email!].join('  ·  '),
                  style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 3),
            pw.Text(
              [
                if (a.rc != null) 'RC : ${a.rc}',
                if (a.nif != null) 'NIF : ${a.nif}',
                if (a.nis != null) 'NIS : ${a.nis}',
                if (a.art != null) 'ART : ${a.art}',
              ].join('   '),
              style: const pw.TextStyle(fontSize: 8, color: _grey),
            ),
            if (a.rib != null) pw.Text('RIB : ${a.rib}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
          ]),
        ),
        pw.Container(
          width: 190,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: _violet, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(titre, style: pw.TextStyle(color: PdfColors.white, fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final i in infos)
              pw.Row(children: [
                pw.Text('${i[0]} : ', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                pw.Expanded(child: pw.Text(i[1], style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold))),
              ]),
          ]),
        ),
      ],
    );

pw.Widget _blocClient(String titre, Client? c, {String? extra}) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _light, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(titre, style: const pw.TextStyle(fontSize: 8, color: _grey)),
        pw.Text(c?.nom ?? 'Client de passage', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (c != null) ...[
          if (c.adresse != null || c.wilaya != null)
            pw.Text([if (c.adresse != null) c.adresse!, if (c.wilaya != null) c.wilaya!].join(', '), style: const pw.TextStyle(fontSize: 9)),
          if (c.telephone != null) pw.Text('Tél. ${c.telephone}', style: const pw.TextStyle(fontSize: 9)),
          if (c.rc != null || c.nif != null)
            pw.Text([if (c.rc != null) 'RC : ${c.rc}', if (c.nif != null) 'NIF : ${c.nif}'].join('   '),
                style: const pw.TextStyle(fontSize: 8, color: _grey)),
        ],
        if (extra != null) pw.Text(extra, style: const pw.TextStyle(fontSize: 9)),
      ]),
    );

pw.Widget _signatures(List<String> labels) => pw.Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 24),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(labels[i], style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.SizedBox(height: 40),
            pw.Container(height: 1, color: PdfColors.grey400),
          ]),
        ),
      ],
    ]);

pw.Widget _annulee() => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _red, width: 2), borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Text('DOCUMENT ANNULÉ', textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _red, fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
    );

pw.Widget _footer(pw.Context ctx, Atelier a) => pw.Column(children: [
      if (a.mentions != null) pw.Text(a.mentions!, style: const pw.TextStyle(fontSize: 7.5, color: _grey), textAlign: pw.TextAlign.center),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _grey)),
      ),
    ]);

// ============================================================== facture

Future<Uint8List> buildFacture({required Atelier atelier, required Vente vente, required List<VenteLigne> lignes, Client? client}) async {
  final doc = pw.Document(title: 'Facture ${vente.numero}', author: atelier.nom, theme: await _pdfTheme());
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);

  pw.Widget tot(String label, double v, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: bold ? 11 : 9.5, fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text(fmtDA(v), style: pw.TextStyle(fontSize: bold ? 12 : 9.5, fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        ]),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(30),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'FACTURE', [
        ['N°', vente.numero],
        ['Date', fmtDate(vente.date)],
        ['Bon de livraison', vente.numeroBl],
      ]),
      pw.SizedBox(height: 14),
      _blocClient('Facturé à', client),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        headers: ['N°', 'Référence', 'Désignation', 'Qté', 'Prix unitaire', 'Montant'],
        data: [
          for (var i = 0; i < lignes.length; i++)
            ['${i + 1}', lignes[i].reference, lignes[i].designation, fmtInt(lignes[i].quantite), fmtDA(lignes[i].prixUnitaire), fmtDA(lignes[i].montant)],
        ],
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: _light),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FixedColumnWidth(70),
          2: const pw.FlexColumnWidth(),
          3: const pw.FixedColumnWidth(40),
          4: const pw.FixedColumnWidth(80),
          5: const pw.FixedColumnWidth(90),
        },
        cellAlignments: {
          0: pw.Alignment.center,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        border: null,
      ),
      pw.SizedBox(height: 10),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Nombre d\'articles : ${fmtInt(qte)}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
            pw.Text('Arrêtée la présente facture à la somme de :', style: const pw.TextStyle(fontSize: 9, color: _grey)),
            pw.Text(montantEnLettres(vente.totalTtc), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            if (vente.note != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Remarque : ${vente.note}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ]),
        ),
        pw.SizedBox(width: 20),
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            if (vente.remise > 0) ...[tot('Total brut', vente.totalBrut), tot('Remise', -vente.remise)],
            tot('Total HT', vente.totalHt),
            if (vente.tvaTaux > 0) tot('TVA ${fmtNum(vente.tvaTaux)} %', vente.totalTva),
            pw.Divider(color: _violet),
            tot(vente.tvaTaux > 0 ? 'TOTAL TTC' : 'TOTAL À PAYER', vente.totalTtc, bold: true, color: _violet),
            if (!vente.annulee) ...[
              pw.SizedBox(height: 6),
              tot('Versé', vente.verse, color: _green),
              tot('Reste à payer', vente.reste, bold: true, color: vente.reste > 0 ? _red : _green),
            ],
          ]),
        ),
      ]),
      pw.SizedBox(height: 30),
      _signatures(['Le client', 'Cachet et signature']),
    ],
  ));
  return doc.save();
}

// ============================================================== bon de livraison

Future<Uint8List> buildBonLivraison({required Atelier atelier, required Vente vente, required List<VenteLigne> lignes, Client? client}) async {
  final doc = pw.Document(title: 'Bon de livraison ${vente.numeroBl}', author: atelier.nom, theme: await _pdfTheme());
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(30),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'BON DE LIVRAISON', [
        ['N°', vente.numeroBl],
        ['Date', fmtDate(vente.date)],
        ['Facture', vente.numero],
      ]),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _blocClient('Destinataire', client, extra: vente.adresseLivraison == null ? null : 'Livraison : ${vente.adresseLivraison}')),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _light, width: 1.5), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Transport', style: const pw.TextStyle(fontSize: 8, color: _grey)),
            pw.Text('Chauffeur : ${vente.chauffeur ?? '....................'}', style: const pw.TextStyle(fontSize: 9.5)),
            pw.SizedBox(height: 3),
            pw.Text('Véhicule : ${vente.vehicule ?? '....................'}', style: const pw.TextStyle(fontSize: 9.5)),
          ]),
        ),
      ]),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        headers: ['N°', 'Référence', 'Désignation', 'Quantité', 'Contrôle'],
        data: [
          for (var i = 0; i < lignes.length; i++) ['${i + 1}', lignes[i].reference, lignes[i].designation, fmtInt(lignes[i].quantite), ''],
        ],
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        oddRowDecoration: const pw.BoxDecoration(color: _light),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FixedColumnWidth(80),
          2: const pw.FlexColumnWidth(),
          3: const pw.FixedColumnWidth(60),
          4: const pw.FixedColumnWidth(60),
        },
        cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight, 4: pw.Alignment.center},
        border: null,
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _violet, width: 1.5))),
        child: pw.Row(children: [
          pw.Text('TOTAL DES ARTICLES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Spacer(),
          pw.Text(fmtInt(qte), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: _violet)),
        ]),
      ),
      pw.SizedBox(height: 8),
      pw.Text('Marchandise reçue en bon état et conforme au présent bon.', style: const pw.TextStyle(fontSize: 9, color: _grey)),
      pw.SizedBox(height: 30),
      _signatures(['Expéditeur', 'Transporteur', 'Réceptionnaire (nom, date, signature)']),
    ],
  ));
  return doc.save();
}

// ============================================================== relevé de compte client

Future<Uint8List> buildReleveClient({
  required Atelier atelier,
  required Client client,
  required List<Vente> ventes,
  required List<Versement> versements,
}) async {
  final doc = pw.Document(title: 'Relevé ${client.nom}', author: atelier.nom, theme: await _pdfTheme());
  final ops = <(DateTime, String, double, double)>[
    for (final v in ventes.where((v) => !v.annulee)) (v.date, 'Facture ${v.numero}', v.totalTtc, 0),
    for (final x in versements) (x.date, 'Versement (${x.modeTexte})${x.note != null ? ' — ${x.note}' : ''}', 0, x.montant),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var solde = 0.0;
  final rows = <List<String>>[];
  for (final o in ops) {
    solde += o.$3 - o.$4;
    rows.add([fmtDate(o.$1), o.$2, o.$3 > 0 ? fmtDA(o.$3) : '', o.$4 > 0 ? fmtDA(o.$4) : '', fmtDA(solde)]);
  }
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(30),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      _entete(atelier, 'RELEVÉ DE COMPTE', [
        ['Date', fmtDate(DateTime.now())],
        ['Opérations', '${ops.length}'],
      ]),
      pw.SizedBox(height: 14),
      _blocClient('Client', client),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Opération', 'Débit (achats)', 'Crédit (versements)', 'Solde'],
        data: rows,
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9),
        oddRowDecoration: const pw.BoxDecoration(color: _light),
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        border: null,
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text('Total achats : ${fmtDA(client.totalAchats)}     Total versé : ${fmtDA(client.totalVerse)}',
                style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Text(client.solde > 0 ? 'RESTE À PAYER : ${fmtDA(client.solde)}' : 'CRÉDIT CLIENT : ${fmtDA(-client.solde)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: client.solde > 0 ? _red : _green)),
        ]),
      ),
    ],
  ));
  return doc.save();
}

// ============================================================== étiquettes QR

enum FormatEtiquette { a4Grand, a4, thermique }

extension FormatEtiquetteX on FormatEtiquette {
  String get label => switch (this) {
        FormatEtiquette.a4Grand => 'Grand QR : 1 par feuille A4',
        FormatEtiquette.a4 => 'Feuille A4 (24 étiquettes 70 × 37 mm)',
        FormatEtiquette.thermique => 'Imprimante d\'étiquettes (50 × 30 mm)',
      };
}

Future<Uint8List> buildEtiquettes(List<(Produit, int)> items, {FormatEtiquette format = FormatEtiquette.a4, bool prix = true}) async {
  final doc = pw.Document(title: 'Étiquettes', theme: await _pdfTheme());
  final etiquettes = <Produit>[for (final it in items) for (var i = 0; i < it.$2; i++) it.$1];
  final qr = pw.Barcode.qrCode();

  pw.Widget etiquette(Produit p, double w, double h) {
    final qrSize = h - 8;
    return pw.Container(
      width: w,
      height: h,
      padding: const pw.EdgeInsets.all(4),
      child: pw.Row(children: [
        pw.BarcodeWidget(barcode: qr, data: p.reference, width: qrSize, height: qrSize, drawText: false),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(p.reference, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(p.designation, maxLines: 2, style: const pw.TextStyle(fontSize: 7)),
            if (p.variante.isNotEmpty) pw.Text(p.variante, maxLines: 1, style: const pw.TextStyle(fontSize: 7, color: _grey)),
            if (prix && p.prixGros > 0) pw.Text(fmtDA(p.prixGros), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  if (format == FormatEtiquette.a4Grand) {
    for (final p in etiquettes) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(p.reference, style: pw.TextStyle(fontSize: 54, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
            pw.SizedBox(height: 18),
            pw.BarcodeWidget(barcode: qr, data: p.reference, width: 165 * PdfPageFormat.mm, height: 165 * PdfPageFormat.mm, drawText: false),
            pw.SizedBox(height: 22),
            pw.Text(p.designation, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
            if (p.variante.isNotEmpty) pw.Text(p.variante, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 20, color: _grey)),
            if (prix && p.prixGros > 0) ...[
              pw.SizedBox(height: 10),
              pw.Text('Prix de gros : ${fmtDA(p.prixGros)}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _violet)),
            ],
          ],
        ),
      ));
    }
  } else if (format == FormatEtiquette.thermique) {
    const w = 50 * PdfPageFormat.mm, h = 30 * PdfPageFormat.mm;
    for (final p in etiquettes) {
      doc.addPage(pw.Page(pageFormat: const PdfPageFormat(w, h), margin: pw.EdgeInsets.zero, build: (_) => etiquette(p, w, h)));
    }
  } else {
    const cols = 3, rows = 8;
    const w = 70 * PdfPageFormat.mm, h = 37 * PdfPageFormat.mm;
    for (var start = 0; start < etiquettes.length; start += cols * rows) {
      final page = etiquettes.skip(start).take(cols * rows).toList();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(vertical: 0.5 * PdfPageFormat.mm),
        build: (_) => pw.Wrap(children: [
          for (final p in page)
            pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border.fromBorderSide(pw.BorderSide(color: PdfColors.grey300, width: 0.3))),
              child: etiquette(p, w, h),
            ),
        ]),
      ));
    }
  }
  if (etiquettes.isEmpty) doc.addPage(pw.Page(build: (_) => pw.Text('Aucune étiquette')));
  return doc.save();
}

/// Ouvre la fenêtre d'impression (ou d'enregistrement PDF).
Future<void> imprimer(Uint8List bytes, String nom) => Printing.layoutPdf(onLayout: (_) async => bytes, name: nom);

Future<void> partager(Uint8List bytes, String nom) => Printing.sharePdf(bytes: bytes, filename: nom);
