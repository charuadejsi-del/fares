import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
import '../data/stock.dart';
import '../utils.dart';

const _grey = PdfColor.fromInt(0xFF6B6F80);
const _green = PdfColor.fromInt(0xFF047857);
const _red = PdfColor.fromInt(0xFFBE123C);

pw.ThemeData? _theme;

/// Logo de l'entreprise (chargé depuis Supabase Storage, mis en cache).
Uint8List? _logo;
String? _logoPath;

Future<void> chargerLogo(Atelier a) async {
  if (a.logoPath == null) {
    _logo = null;
    _logoPath = null;
    return;
  }
  if (_logoPath == a.logoPath && _logo != null) return;
  try {
    _logo = await Supabase.instance.client.storage.from('broderie-dessins').download(a.logoPath!);
    _logoPath = a.logoPath;
  } catch (_) {
    _logo = null;
  }
}

void oublierLogo() {
  _logo = null;
  _logoPath = null;
}

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

// ============================================================== charte des documents

const _ink = PdfColor.fromInt(0xFF101828);
const _gold = PdfColor.fromInt(0xFFB8902F);
const _goldLight = PdfColor.fromInt(0xFFF7F0DE);
const _line = PdfColor.fromInt(0xFFE4E7EC);
const _zebra = PdfColor.fromInt(0xFFF8F9FB);

pw.PageTheme _page(pw.ThemeData theme) => pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(34, 30, 34, 24),
      buildBackground: (ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(children: [
          pw.Positioned(left: 0, top: 0, right: 0, child: pw.Container(height: 7, color: _ink)),
          pw.Positioned(left: 0, top: 7, right: 0, child: pw.Container(height: 2.5, color: _gold)),
          if (_logo != null)
            pw.Center(
              child: pw.Opacity(opacity: 0.045, child: pw.Image(pw.MemoryImage(_logo!), width: 330, fit: pw.BoxFit.contain)),
            ),
        ]),
      ),
    );

pw.TextStyle _label([PdfColor c = _gold]) => pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: c, letterSpacing: 1.2);

pw.Widget _entete(Atelier a, String titre, List<List<String>> infos) {
  final numero = infos.isNotEmpty && infos.first[0] == 'N°' ? infos.first[1] : null;
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
    pw.SizedBox(height: 6),
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (_logo != null) ...[
        pw.Container(width: 66, height: 66, child: pw.Image(pw.MemoryImage(_logo!), fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 14),
      ],
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(a.nom.toUpperCase(), style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: _ink, letterSpacing: 0.6)),
          if (a.activite != null) pw.Text(a.activite!.toUpperCase(), style: _label()),
          pw.SizedBox(height: 6),
          if (a.adresse != null) pw.Text(a.adresse!, style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
          if (a.telephone != null || a.email != null)
            pw.Text([if (a.telephone != null) 'Tél. ${a.telephone}', if (a.email != null) a.email!].join('   |   '),
                style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
        ]),
      ),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text(titre, style: pw.TextStyle(fontSize: titre.length > 14 ? 20 : 25, fontWeight: pw.FontWeight.bold, color: _ink, letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        pw.Container(width: 46, height: 3, color: _gold),
        if (numero != null) ...[
          pw.SizedBox(height: 7),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Text('N° $numero', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ]),
    ]),
  ]);
}

/// Bloc client + bloc informations du document côte à côte.
pw.Widget _parties(String titreClient, Client? c, List<List<String>> infos, {String? extra}) {
  final details = infos.where((i) => i[0] != 'N°').toList();
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: const pw.BoxDecoration(color: _zebra, border: pw.Border(left: pw.BorderSide(color: _gold, width: 3))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(titreClient.toUpperCase(), style: _label()),
          pw.SizedBox(height: 4),
          pw.Text(c?.nom ?? 'Client de passage', style: pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold, color: _ink)),
          if (c != null) ...[
            if (c.adresse != null || c.wilaya != null)
              pw.Text([if (c.adresse != null) c.adresse!, if (c.wilaya != null) c.wilaya!].join(', '), style: const pw.TextStyle(fontSize: 9)),
            if (c.telephone != null) pw.Text('Tél. ${c.telephone}', style: const pw.TextStyle(fontSize: 9)),
            if (c.rc != null || c.nif != null)
              pw.Text([if (c.rc != null) 'RC ${c.rc}', if (c.nif != null) 'NIF ${c.nif}'].join('   '), style: const pw.TextStyle(fontSize: 8, color: _grey)),
          ],
          if (extra != null) ...[pw.SizedBox(height: 3), pw.Text(extra, style: const pw.TextStyle(fontSize: 9))],
        ]),
      ),
    ),
    if (details.isNotEmpty) ...[
      pw.SizedBox(width: 14),
      pw.Container(
        width: 190,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Column(children: [
          for (final i in details)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(i[0].toUpperCase(), style: _label(_grey))),
                pw.Text(i[1], style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink)),
              ]),
            ),
        ]),
      ),
    ],
  ]);
}

/// Tableau élégant : en-tête sombre, lignes fines, alternance discrète.
pw.Widget _tableau(List<String> headers, List<List<String>> rows, {required Map<int, pw.TableColumnWidth> widths, Set<int> droite = const {}, Set<int> centre = const {}}) {
  pw.Alignment al(int i) => droite.contains(i) ? pw.Alignment.centerRight : (centre.contains(i) ? pw.Alignment.center : pw.Alignment.centerLeft);
  return pw.Table(
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _ink),
        children: [
          for (var i = 0; i < headers.length; i++)
            pw.Container(
              alignment: al(i),
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text(headers[i].toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
            ),
        ],
      ),
      for (var r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: r.isOdd ? _zebra : null, border: const pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
          children: [
            for (var i = 0; i < rows[r].length; i++)
              pw.Container(
                alignment: al(i),
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: pw.Text(rows[r][i], style: pw.TextStyle(fontSize: 9, fontWeight: i == rows[r].length - 1 && droite.contains(i) ? pw.FontWeight.bold : null)),
              ),
          ],
        ),
    ],
  );
}

class _L {
  final String reference;
  final String designation;
  final String? couleur;
  final String? taille;
  final int quantite;
  final double prix;
  final double montant;
  _L(this.reference, this.designation, this.couleur, this.taille, this.quantite, this.prix, this.montant);
}

_L _ligne(String reference, String designation, int q, double prix, double montant, {String? produitId}) {
  final p = (produitId != null ? stock.produit(produitId) : null) ?? stock.parReference(reference);
  return _L(reference, p?.designation ?? designation, p?.couleur, p?.taille, q, prix, montant);
}

pw.Widget _tableLignes(List<_L> l, {bool prix = true}) {
  final var_ = l.any((x) => x.couleur != null || x.taille != null);
  final headers = ['N°', 'Référence', 'Désignation', if (var_) 'Couleur', if (var_) 'Taille', 'Qté', if (prix) 'Prix unit.', if (prix) 'Montant'];
  final rows = [
    for (var i = 0; i < l.length; i++)
      [
        '${i + 1}',
        l[i].reference,
        l[i].designation,
        if (var_) l[i].couleur ?? '—',
        if (var_) l[i].taille ?? '—',
        fmtInt(l[i].quantite),
        if (prix) fmtDA(l[i].prix),
        if (prix) fmtDA(l[i].montant),
      ],
  ];
  var k = 0;
  final w = <int, pw.TableColumnWidth>{};
  w[k++] = const pw.FixedColumnWidth(24);
  w[k++] = const pw.FixedColumnWidth(78);
  w[k++] = const pw.FlexColumnWidth();
  if (var_) {
    w[k++] = const pw.FixedColumnWidth(58);
    w[k++] = const pw.FixedColumnWidth(40);
  }
  final iQte = k;
  w[k++] = const pw.FixedColumnWidth(34);
  final droite = <int>{};
  if (prix) {
    droite.add(k);
    w[k++] = const pw.FixedColumnWidth(66);
    droite.add(k);
    w[k++] = const pw.FixedColumnWidth(78);
  }
  return _tableau(headers, rows, widths: w, centre: {0, iQte, if (var_) iQte - 1}, droite: droite);
}

pw.Widget _totaux(List<(String, double, bool)> lignes, {(String, double)? net, List<(String, double, PdfColor)> apres = const []}) => pw.Container(
      width: 240,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        for (final t in lignes)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(t.$1, style: pw.TextStyle(fontSize: 9.5, fontWeight: t.$3 ? pw.FontWeight.bold : null))),
              pw.Text(fmtDA(t.$2), style: pw.TextStyle(fontSize: 9.5, fontWeight: t.$3 ? pw.FontWeight.bold : null)),
            ]),
          ),
        if (net != null)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(net.$1.toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1))),
              pw.Text(fmtDA(net.$2), style: pw.TextStyle(color: const PdfColor.fromInt(0xFFE9C46A), fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        for (final a in apres)
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 5, 10, 0),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(a.$1, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: a.$3))),
              pw.Text(fmtDA(a.$2), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: a.$3)),
            ]),
          ),
      ]),
    );

pw.Widget _lettres(String phrase, double montant) => pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _goldLight, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(phrase, style: const pw.TextStyle(fontSize: 8.5, color: _grey)),
        pw.SizedBox(height: 2),
        pw.Text(montantEnLettres(montant), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
      ]),
    );

pw.Widget _tampon(String texte, PdfColor c) => pw.Transform.rotate(
      angle: 0.18,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: c, width: 2.2), borderRadius: pw.BorderRadius.circular(5)),
        child: pw.Text(texte, style: pw.TextStyle(color: c, fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
      ),
    );

pw.Widget _signatures(List<String> labels) => pw.Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Container(
            height: 78,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(labels[i].toUpperCase(), style: _label(_grey)),
          ),
        ),
      ],
    ]);

pw.Widget _annulee() => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _red, width: 2), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text('DOCUMENT ANNULÉ', textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _red, fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
    );

pw.Widget _footer(pw.Context ctx, Atelier a) {
  final legal = [
    if (a.rc != null) 'RC ${a.rc}',
    if (a.nif != null) 'NIF ${a.nif}',
    if (a.nis != null) 'NIS ${a.nis}',
    if (a.art != null) 'ART ${a.art}',
  ].join('   ·   ');
  final lien = a.qrLien;
  return pw.Column(children: [
    pw.Container(height: 1, color: _gold),
    pw.SizedBox(height: 6),
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(a.nom, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _ink)),
          if (legal.isNotEmpty) pw.Text(legal, style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          if (a.rib != null) pw.Text('RIB ${a.rib}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          if (a.mentions != null) pw.Text(a.mentions!, style: const pw.TextStyle(fontSize: 7, color: _grey)),
          pw.SizedBox(height: 3),
          pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        ]),
      ),
      if (lien != null) ...[
        pw.SizedBox(width: 10),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text((a.qrLibelle ?? 'Suivez-nous').toUpperCase(), style: _label()),
          pw.SizedBox(height: 2),
          pw.Text('Scannez le code', style: const pw.TextStyle(fontSize: 7, color: _grey)),
        ]),
        pw.SizedBox(width: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(3),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(3)),
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: lien, width: 56, height: 56, drawText: false),
        ),
      ],
    ]),
  ]);
}

Future<pw.Document> _nouveau(Atelier a, String titre) async {
  await chargerLogo(a);
  return pw.Document(title: titre, author: a.nom, theme: await _pdfTheme());
}

// ============================================================== facture

Future<Uint8List> buildFacture({required Atelier atelier, required Vente vente, required List<VenteLigne> lignes, Client? client}) async {
  final doc = await _nouveau(atelier, 'Facture ${vente.numero}');
  final ls = [for (final l in lignes) _ligne(l.reference, l.designation, l.quantite, l.prixUnitaire, l.montant, produitId: l.produitId)];
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  final infos = [
    ['N°', vente.numero],
    ['Date', fmtDate(vente.date)],
    ['Bon de livraison', vente.numeroBl],
    ['Articles', fmtInt(qte)],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'FACTURE', infos),
      pw.SizedBox(height: 18),
      _parties('Facturé à', client, infos, extra: vente.adresseLivraison == null ? null : 'Livraison : ${vente.adresseLivraison}'),
      pw.SizedBox(height: 16),
      _tableLignes(ls),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _lettres('Arrêtée la présente facture à la somme de :', vente.totalTtc),
            if (vente.note != null) ...[pw.SizedBox(height: 8), pw.Text('Remarque : ${vente.note}', style: const pw.TextStyle(fontSize: 9))],
            pw.SizedBox(height: 18),
            if (!vente.annulee)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20),
                child: vente.reste <= 0.005 ? _tampon('PAYÉE', _green) : (vente.verse > 0 ? _tampon('ACOMPTE', _gold) : _tampon('À RÉGLER', _red)),
              ),
          ]),
        ),
        pw.SizedBox(width: 20),
        _totaux(
          [
            if (vente.remise > 0) ('Total brut', vente.totalBrut, false),
            if (vente.remise > 0) ('Remise', -vente.remise, false),
            ('Total HT', vente.totalHt, false),
            if (vente.tvaTaux > 0) ('TVA ${fmtNum(vente.tvaTaux)} %', vente.totalTva, false),
          ],
          net: (vente.tvaTaux > 0 ? 'Total TTC' : 'Net à payer', vente.totalTtc),
          apres: vente.annulee ? const [] : [('Versé', vente.verse, _green), ('Reste à payer', vente.reste, vente.reste > 0.005 ? _red : _green)],
        ),
      ]),
      pw.SizedBox(height: 26),
      _signatures(['Le client', 'Cachet et signature']),
    ],
  ));
  return doc.save();
}

// ============================================================== bon de livraison

Future<Uint8List> buildBonLivraison({required Atelier atelier, required Vente vente, required List<VenteLigne> lignes, Client? client}) async {
  final doc = await _nouveau(atelier, 'Bon de livraison ${vente.numeroBl}');
  final ls = [for (final l in lignes) _ligne(l.reference, l.designation, l.quantite, l.prixUnitaire, l.montant, produitId: l.produitId)];
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  final infos = [
    ['N°', vente.numeroBl],
    ['Date', fmtDate(vente.date)],
    ['Facture', vente.numero],
    ['Colis / articles', fmtInt(qte)],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'BON DE LIVRAISON', infos),
      pw.SizedBox(height: 18),
      _parties('Destinataire', client, infos, extra: vente.adresseLivraison == null ? null : 'Livraison : ${vente.adresseLivraison}'),
      pw.SizedBox(height: 16),
      _tableLignes(ls, prix: false),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(children: [
          pw.Text('TOTAL DES ARTICLES LIVRÉS', style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.Spacer(),
          pw.Text(fmtInt(qte), style: pw.TextStyle(color: const PdfColor.fromInt(0xFFE9C46A), fontSize: 15, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Text('Marchandise reçue en bon état, conforme en nombre, couleurs et tailles au présent bon.', style: const pw.TextStyle(fontSize: 9, color: _grey)),
      pw.SizedBox(height: 22),
      _signatures(['Expéditeur', 'Réceptionnaire (nom, date, signature)']),
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
  List<(DateTime, String, double)> avoirs = const [],
}) async {
  final doc = await _nouveau(atelier, 'Relevé ${client.nom}');
  final ops = <(DateTime, String, double, double)>[
    for (final v in ventes.where((v) => !v.annulee)) (v.date, 'Facture ${v.numero}', v.totalTtc, 0),
    for (final x in versements) (x.date, 'Versement (${x.modeTexte})${x.note != null ? ' — ${x.note}' : ''}', 0, x.montant),
    for (final a in avoirs) (a.$1, a.$2, 0, a.$3),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var solde = 0.0;
  final rows = <List<String>>[];
  for (final o in ops) {
    solde += o.$3 - o.$4;
    rows.add([fmtDate(o.$1), o.$2, o.$3 > 0 ? fmtDA(o.$3) : '', o.$4 > 0 ? fmtDA(o.$4) : '', fmtDA(solde)]);
  }
  final infos = [
    ['Date', fmtDate(DateTime.now())],
    ['Opérations', '${ops.length}'],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      _entete(atelier, 'RELEVÉ DE COMPTE', infos),
      pw.SizedBox(height: 18),
      _parties('Client', client, infos),
      pw.SizedBox(height: 16),
      _tableau(
        ['Date', 'Opération', 'Débit', 'Crédit', 'Solde'],
        rows,
        widths: const {0: pw.FixedColumnWidth(62), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(78), 3: pw.FixedColumnWidth(78), 4: pw.FixedColumnWidth(84)},
        droite: {2, 3, 4},
      ),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Spacer(),
        _totaux(
          [('Total des achats', client.totalAchats, false), ('Total versé', client.totalVerse, false), if (client.totalAvoirs > 0) ('Avoirs', client.totalAvoirs, false)],
          net: (client.solde >= 0 ? 'Reste à payer' : 'Crédit client', client.solde.abs()),
        ),
      ]),
    ],
  ));
  return doc.save();
}

// ============================================================== devis, bon de commande, avoir

typedef LigneDoc = ({String reference, String designation, int quantite, double prix, double montant});

Future<Uint8List> buildDocumentCommercial({
  required Atelier atelier,
  required String titre,
  required List<List<String>> infos,
  required String titreClient,
  Client? client,
  required List<LigneDoc> lignes,
  required List<(String, double, bool)> totaux,
  double? montantLettres,
  String? phraseLettres,
  String? note,
  List<String> signatures = const ['Le client', 'Cachet et signature'],
  bool annule = false,
}) async {
  final doc = await _nouveau(atelier, titre);
  final ls = [for (final l in lignes) _ligne(l.reference, l.designation, l.quantite, l.prix, l.montant)];
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  final net = totaux.where((t) => t.$3).toList();
  final autres = totaux.where((t) => !t.$3).toList();
  final infosPlus = [...infos, ['Articles', fmtInt(qte)]];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (annule) _annulee(),
      _entete(atelier, titre, infosPlus),
      pw.SizedBox(height: 18),
      _parties(titreClient, client, infosPlus),
      pw.SizedBox(height: 16),
      _tableLignes(ls),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (montantLettres != null) _lettres(phraseLettres ?? 'Arrêté le présent document à la somme de :', montantLettres),
            if (note != null) ...[pw.SizedBox(height: 8), pw.Text(note, style: const pw.TextStyle(fontSize: 9))],
          ]),
        ),
        pw.SizedBox(width: 20),
        _totaux(autres, net: net.isEmpty ? null : (net.last.$1, net.last.$2)),
      ]),
      pw.SizedBox(height: 26),
      _signatures(signatures),
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
              pw.Text('Prix de gros : ${fmtDA(p.prixGros)}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink)),
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
