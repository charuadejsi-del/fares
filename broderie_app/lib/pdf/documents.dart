import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/gestion.dart' show LignePaie;
import '../data/session.dart';
import '../data/stock.dart';
import '../utils.dart';
import '../i18n.dart';

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

/// Polices des documents : Inter (latin) + Cairo (arabe), selon la langue.
Future<pw.ThemeData> pdfThemeLangue() async {
  try {
    final arR = await PdfGoogleFonts.cairoRegular();
    final arB = await PdfGoogleFonts.cairoBold();
    if (langue.ar) return pw.ThemeData.withFont(base: arR, bold: arB, fontFallback: [await PdfGoogleFonts.interRegular()]);
    return pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
      fontFallback: [arR, arB],
    );
  } catch (_) {
    return pw.ThemeData.base();
  }
}

/// Sens d'écriture des documents.
pw.TextDirection get pdfSens => langue.ar ? pw.TextDirection.rtl : pw.TextDirection.ltr;

String? _themeLangue;

Future<pw.ThemeData> _pdfTheme() async {
  if (_theme != null && _themeLangue == langue.value) return _theme!;
  _theme = await pdfThemeLangue();
  _themeLangue = langue.value;
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

String _montantEnLettresFr(double montant) {
  final dinars = montant.floor();
  final centimes = ((montant - dinars) * 100).round();
  var s = '{0} dinar{1} algérien{2}'.trf([nombreEnLettres(dinars), dinars > 1 ? 's' : '', dinars > 1 ? 's' : '']);
  if (centimes > 0) s += ' et {0} centime{1}'.trf([nombreEnLettres(centimes), centimes > 1 ? 's' : '']);
  return s[0].toUpperCase() + s.substring(1);
}


// ---------------------------------------------------------------- en arabe
const _arUnites = ['صفر', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة', 'عشرة',
  'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
const _arDizaines = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
const _arCentaines = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];

String _arMoinsDeMille(int n) {
  final c = n ~/ 100, r = n % 100;
  final parts = <String>[];
  if (c > 0) parts.add(_arCentaines[c]);
  if (r > 0) {
    if (r < 20) {
      parts.add(_arUnites[r]);
    } else {
      final u = r % 10, d = r ~/ 10;
      parts.add(u == 0 ? _arDizaines[d] : '${_arUnites[u]} و${_arDizaines[d]}');
    }
  }
  return parts.join(' و');
}

String _arGroupe(int n, String un, String deux, String pluriel) {
  if (n == 1) return un;
  if (n == 2) return deux;
  if (n <= 10) return '${_arMoinsDeMille(n)} $pluriel';
  return '${_arMoinsDeMille(n)} $un';
}

String nombreEnLettresAr(int n) {
  if (n == 0) return _arUnites[0];
  final parts = <String>[];
  final milliards = n ~/ 1000000000;
  final millions = (n ~/ 1000000) % 1000;
  final milliers = (n ~/ 1000) % 1000;
  final reste = n % 1000;
  if (milliards > 0) parts.add(_arGroupe(milliards, 'مليار', 'ملياران', 'مليارات'));
  if (millions > 0) parts.add(_arGroupe(millions, 'مليون', 'مليونان', 'ملايين'));
  if (milliers > 0) parts.add(_arGroupe(milliers, 'ألف', 'ألفان', 'آلاف'));
  if (reste > 0) parts.add(_arMoinsDeMille(reste));
  return parts.join(' و');
}

/// Montant en toutes lettres, dans la langue de l'application.
String montantEnLettres(double montant) {
  if (!langue.ar) return _montantEnLettresFr(montant);
  final dinars = montant.floor();
  final centimes = ((montant - dinars) * 100).round();
  var s = 'فقط ${nombreEnLettresAr(dinars)} دينار جزائري';
  if (centimes > 0) s += ' و${nombreEnLettresAr(centimes)} سنتيم';
  return '$s لا غير';
}

// ============================================================== charte des documents

const _ink = PdfColor.fromInt(0xFF101828);
const _gold = PdfColor.fromInt(0xFFB8902F);
const _goldLight = PdfColor.fromInt(0xFFF7F0DE);
const _line = PdfColor.fromInt(0xFFE4E7EC);
const _zebra = PdfColor.fromInt(0xFFF8F9FB);

pw.PageTheme _page(pw.ThemeData theme) => pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      textDirection: pdfSens,
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
  final numero = infos.isNotEmpty && infos.first[0] == 'N°'.tr ? infos.first[1] : null;
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
            pw.Text([if (a.telephone != null) 'Tél. {0}'.trf([a.telephone]), if (a.email != null) a.email!].join('   |   '),
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
            child: pw.Text('N° {0}'.trf([numero]), style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ]),
    ]),
  ]);
}

/// Bloc client + bloc informations du document côte à côte.
pw.Widget _parties(String titreClient, Client? c, List<List<String>> infos, {String? extra}) {
  final details = infos.where((i) => i[0] != 'N°'.tr).toList();
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: const pw.BoxDecoration(color: _zebra, border: pw.Border(left: pw.BorderSide(color: _gold, width: 3))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(titreClient.toUpperCase(), style: _label()),
          pw.SizedBox(height: 4),
          pw.Text(c?.nom ?? 'Client de passage'.tr, style: pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold, color: _ink)),
          if (c != null) ...[
            if (c.adresse != null || c.wilaya != null)
              pw.Text([if (c.adresse != null) c.adresse!, if (c.wilaya != null) c.wilaya!].join(', '), style: const pw.TextStyle(fontSize: 9)),
            if (c.telephone != null) pw.Text('Tél. {0}'.trf([c.telephone]), style: const pw.TextStyle(fontSize: 9)),
            if (c.rc != null || c.nif != null)
              pw.Text([if (c.rc != null) 'RC {0}'.trf([c.rc]), if (c.nif != null) 'NIF ${c.nif}'].join('   '), style: const pw.TextStyle(fontSize: 8, color: _grey)),
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
  final String modele;
  final String designation;
  final String? couleur;
  final int quantite;
  final double prix;
  final double montant;
  _L(this.modele, this.designation, this.couleur, this.quantite, this.prix, this.montant);
}

_L _ligne(String reference, String designation, int q, double prix, double montant, {String? produitId}) {
  final p = (produitId != null ? stock.produit(produitId) : null) ?? stock.parReference(reference);
  return _L(p?.modele ?? reference, p?.designation ?? designation, p?.couleur, q, prix, montant);
}

/// Un bloc par modèle : titre du modèle, puis une ligne par couleur (tailles regroupées).
class _Groupe {
  final String modele;
  final String designation;
  final double prix;
  final Map<String, (int, double)> couleurs = {};
  int quantite = 0;
  double montant = 0;
  _Groupe(this.modele, this.designation, this.prix);
}

List<pw.Widget> _tableLignes(List<_L> l, {bool prix = true}) {
  final groupes = <String, _Groupe>{};
  for (final x in l) {
    final g = groupes.putIfAbsent('${x.modele}|${x.prix}', () => _Groupe(x.modele, x.designation, x.prix));
    final c = x.couleur ?? '—';
    final prev = g.couleurs[c] ?? (0, 0.0);
    g.couleurs[c] = (prev.$1 + x.quantite, prev.$2 + x.montant);
    g.quantite += x.quantite;
    g.montant += x.montant;
  }
  final gs = groupes.values.toList();

  final widths = <int, pw.TableColumnWidth>{
    0: const pw.FlexColumnWidth(),
    1: const pw.FixedColumnWidth(70),
    if (prix) 2: const pw.FixedColumnWidth(90),
    if (prix) 3: const pw.FixedColumnWidth(100),
  };
  pw.Widget c(String t, {pw.Alignment al = pw.Alignment.centerLeft, pw.TextStyle? st}) => pw.Container(
        alignment: al,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Text(t, style: st ?? const pw.TextStyle(fontSize: 9.5)),
      );
  pw.TextStyle h() => pw.TextStyle(color: PdfColors.white, fontSize: 7.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8);
  final bold = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _ink);

  return [
    pw.Table(columnWidths: widths, children: [
      pw.TableRow(decoration: const pw.BoxDecoration(color: _ink), children: [
        c('MODÈLE / COULEUR'.tr, st: h()),
        c('QUANTITÉ'.tr, al: pw.Alignment.center, st: h()),
        if (prix) c('PRIX UNIT.'.tr, al: pw.Alignment.centerRight, st: h()),
        if (prix) c('MONTANT'.tr, al: pw.Alignment.centerRight, st: h()),
      ]),
    ]),
    for (final g in gs) ...[
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: const pw.BoxDecoration(color: _goldLight, border: pw.Border(left: pw.BorderSide(color: _gold, width: 3))),
        child: pw.Row(children: [
          pw.Text(g.modele, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.Text('   ${g.designation}', style: const pw.TextStyle(fontSize: 10, color: _grey)),
        ]),
      ),
      pw.Table(columnWidths: widths, children: [
        for (final e in g.couleurs.entries)
          pw.TableRow(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
            children: [
              c('      ${e.key}'),
              c('x ${fmtInt(e.value.$1)}', al: pw.Alignment.center, st: bold),
              if (prix) c(fmtDA(g.prix), al: pw.Alignment.centerRight),
              if (prix) c(fmtDA(e.value.$2), al: pw.Alignment.centerRight),
            ],
          ),
        pw.TableRow(children: [
          c('Total {0}'.trf([g.modele]), st: bold),
          c(fmtInt(g.quantite), al: pw.Alignment.center, st: bold),
          if (prix) pw.SizedBox(),
          if (prix) c(fmtDA(g.montant), al: pw.Alignment.centerRight, st: bold),
        ]),
      ]),
    ],
  ];
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
            child: pw.Text(labels[i].tr.toUpperCase(), style: _label(_grey)),
          ),
        ),
      ],
    ]);

pw.Widget _annulee() => pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _red, width: 2), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text('DOCUMENT ANNULÉ'.tr, textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _red, fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 3)),
    );

pw.Widget _footer(pw.Context ctx, Atelier a) {
  final legal = [
    if (a.rc != null) 'RC {0}'.trf([a.rc]),
    if (a.nif != null) 'NIF {0}'.trf([a.nif]),
    if (a.nis != null) 'NIS {0}'.trf([a.nis]),
    if (a.art != null) 'ART {0}'.trf([a.art]),
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
          if (a.rib != null) pw.Text('RIB {0}'.trf([a.rib]), style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
          if (a.mentions != null) pw.Text(a.mentions!, style: const pw.TextStyle(fontSize: 7, color: _grey)),
          pw.SizedBox(height: 3),
          pw.Text('Page {0} / {1}'.trf([ctx.pageNumber, ctx.pagesCount]), style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        ]),
      ),
      if (lien != null) ...[
        pw.SizedBox(width: 10),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text((a.qrLibelle ?? 'Suivez-nous'.tr).toUpperCase(), style: _label()),
          pw.SizedBox(height: 2),
          pw.Text('Scannez le code'.tr, style: const pw.TextStyle(fontSize: 7, color: _grey)),
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
  final doc = await _nouveau(atelier, 'Facture {0}'.trf([vente.numero]));
  final ls = [for (final l in lignes) _ligne(l.reference, l.designation, l.quantite, l.prixUnitaire, l.montant, produitId: l.produitId)];
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  final infos = [
    ['N°'.tr, vente.numero],
    ['Date'.tr, fmtDate(vente.date)],
    ['Bon de livraison'.tr, vente.numeroBl],
    ['Articles'.tr, fmtInt(qte)],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'FACTURE'.tr, infos),
      pw.SizedBox(height: 18),
      _parties('Facturé à'.tr, client, infos, extra: vente.adresseLivraison == null ? null : 'Livraison : {0}'.trf([vente.adresseLivraison])),
      pw.SizedBox(height: 16),
      ..._tableLignes(ls),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _lettres('Arrêtée la présente facture à la somme de :'.tr, vente.totalTtc),
            if (vente.note != null) ...[pw.SizedBox(height: 8), pw.Text('Remarque : {0}'.trf([vente.note]), style: const pw.TextStyle(fontSize: 9))],
            pw.SizedBox(height: 18),
            if (!vente.annulee)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20),
                child: vente.reste <= 0.005 ? _tampon('PAYÉE'.tr, _green) : (vente.verse > 0 ? _tampon('ACOMPTE'.tr, _gold) : _tampon('À RÉGLER'.tr, _red)),
              ),
          ]),
        ),
        pw.SizedBox(width: 20),
        _totaux(
          [
            if (vente.remise > 0) ('Total brut'.tr, vente.totalBrut, false),
            if (vente.remise > 0) ('Remise'.tr, -vente.remise, false),
            ('Total HT'.tr, vente.totalHt, false),
            if (vente.tvaTaux > 0) ('TVA {0} %'.trf([fmtNum(vente.tvaTaux)]), vente.totalTva, false),
          ],
          net: (vente.tvaTaux > 0 ? 'Total TTC'.tr : 'Net à payer'.tr, vente.totalTtc),
          apres: vente.annulee ? const [] : [('Versé'.tr, vente.verse, _green), ('Reste à payer'.tr, vente.reste, vente.reste > 0.005 ? _red : _green)],
        ),
      ]),
      pw.SizedBox(height: 26),
      _signatures(['Le client'.tr, 'Cachet et signature']),
    ],
  ));
  return doc.save();
}

// ============================================================== bon de livraison

Future<Uint8List> buildBonLivraison({required Atelier atelier, required Vente vente, required List<VenteLigne> lignes, Client? client}) async {
  final doc = await _nouveau(atelier, 'Bon de livraison {0}'.trf([vente.numeroBl]));
  final ls = [for (final l in lignes) _ligne(l.reference, l.designation, l.quantite, l.prixUnitaire, l.montant, produitId: l.produitId)];
  final qte = lignes.fold<int>(0, (s, l) => s + l.quantite);
  final infos = [
    ['N°'.tr, vente.numeroBl],
    ['Date'.tr, fmtDate(vente.date)],
    ['Facture'.tr, vente.numero],
    ['Colis / articles'.tr, fmtInt(qte)],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (vente.annulee) _annulee(),
      _entete(atelier, 'BON DE LIVRAISON'.tr, infos),
      pw.SizedBox(height: 18),
      _parties('Destinataire'.tr, client, infos, extra: vente.adresseLivraison == null ? null : 'Livraison : {0}'.trf([vente.adresseLivraison])),
      pw.SizedBox(height: 16),
      ..._tableLignes(ls, prix: false),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(children: [
          pw.Text('TOTAL DES ARTICLES LIVRÉS'.tr, style: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
          pw.Spacer(),
          pw.Text(fmtInt(qte), style: pw.TextStyle(color: const PdfColor.fromInt(0xFFE9C46A), fontSize: 15, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.SizedBox(height: 10),
      pw.Text('Marchandise reçue en bon état, conforme en nombre, couleurs et tailles au présent bon.'.tr, style: const pw.TextStyle(fontSize: 9, color: _grey)),
      pw.SizedBox(height: 22),
      _signatures(['Expéditeur'.tr, 'Réceptionnaire (nom, date, signature)']),
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
  final doc = await _nouveau(atelier, 'Relevé {0}'.trf([client.nom]));
  final ops = <(DateTime, String, double, double)>[
    for (final v in ventes.where((v) => !v.annulee)) (v.date, 'Facture {0}'.trf([v.numero]), v.totalTtc, 0),
    for (final x in versements) (x.date, 'Versement ({0}){1}'.trf([x.modeTexte, x.note != null ? ' — ${x.note}' : '']), 0, x.montant),
    for (final a in avoirs) (a.$1, a.$2, 0, a.$3),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  var solde = 0.0;
  final rows = <List<String>>[];
  for (final o in ops) {
    solde += o.$3 - o.$4;
    rows.add([fmtDate(o.$1), o.$2, o.$3 > 0 ? fmtDA(o.$3) : '', o.$4 > 0 ? fmtDA(o.$4) : '', fmtDA(solde)]);
  }
  final infos = [
    ['Date'.tr, fmtDate(DateTime.now())],
    ['Opérations'.tr, '${ops.length}'],
  ];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      _entete(atelier, 'RELEVÉ DE COMPTE'.tr, infos),
      pw.SizedBox(height: 18),
      _parties('Client'.tr, client, infos),
      pw.SizedBox(height: 16),
      _tableau(
        ['Date'.tr, 'Opération'.tr, 'Débit'.tr, 'Crédit'.tr, 'Solde'],
        rows,
        widths: const {0: pw.FixedColumnWidth(62), 1: pw.FlexColumnWidth(), 2: pw.FixedColumnWidth(78), 3: pw.FixedColumnWidth(78), 4: pw.FixedColumnWidth(84)},
        droite: {2, 3, 4},
      ),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Spacer(),
        _totaux(
          [('Total des achats'.tr, client.totalAchats, false), ('Total versé'.tr, client.totalVerse, false), if (client.totalAvoirs > 0) ('Avoirs'.tr, client.totalAvoirs, false)],
          net: (client.solde >= 0 ? 'Reste à payer'.tr : 'Crédit client'.tr, client.solde.abs()),
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
  final infosPlus = [...infos, ['Articles'.tr, fmtInt(qte)]];
  doc.addPage(pw.MultiPage(
    pageTheme: _page(await _pdfTheme()),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      if (annule) _annulee(),
      _entete(atelier, titre, infosPlus),
      pw.SizedBox(height: 18),
      _parties(titreClient, client, infosPlus),
      pw.SizedBox(height: 16),
      ..._tableLignes(ls),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (montantLettres != null) _lettres(phraseLettres ?? 'Arrêté le présent document à la somme de :'.tr, montantLettres),
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
        FormatEtiquette.a4Grand => 'Grand QR : 1 par feuille A4'.tr,
        FormatEtiquette.a4 => 'Feuille A4 (24 étiquettes 70 × 37 mm)'.tr,
        FormatEtiquette.thermique => 'Imprimante d\'étiquettes (50 × 30 mm)'.tr,
      };
}

Future<Uint8List> buildEtiquettes(List<(Produit, int)> items, {FormatEtiquette format = FormatEtiquette.a4, bool prix = true}) async {
  final doc = pw.Document(title: 'Étiquettes'.tr, theme: await _pdfTheme());
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
        textDirection: pdfSens,
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
              pw.Text('Prix de gros : {0}'.trf([fmtDA(p.prixGros)]), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink)),
            ],
          ],
        ),
      ));
    }
  } else if (format == FormatEtiquette.thermique) {
    const w = 50 * PdfPageFormat.mm, h = 30 * PdfPageFormat.mm;
    for (final p in etiquettes) {
      doc.addPage(pw.Page(textDirection: pdfSens, pageFormat: const PdfPageFormat(w, h), margin: pw.EdgeInsets.zero, build: (_) => etiquette(p, w, h)));
    }
  } else {
    const cols = 3, rows = 8;
    const w = 70 * PdfPageFormat.mm, h = 37 * PdfPageFormat.mm;
    for (var start = 0; start < etiquettes.length; start += cols * rows) {
      final page = etiquettes.skip(start).take(cols * rows).toList();
      doc.addPage(pw.Page(
        textDirection: pdfSens,
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
  if (etiquettes.isEmpty) doc.addPage(pw.Page(textDirection: pdfSens, build: (_) => pw.Text('Aucune étiquette'.tr)));
  return doc.save();
}

/// Ouvre la fenêtre d'impression (ou d'enregistrement PDF).
Future<void> imprimer(Uint8List bytes, String nom) => Printing.layoutPdf(onLayout: (_) async => bytes, name: nom);

Future<void> partager(Uint8List bytes, String nom) => Printing.sharePdf(bytes: bytes, filename: nom);

// ============================================================== clôture de paie

String _modePaie(String m) => switch (m) {
      'points' => 'Payé aux points'.tr,
      'mois' => 'Salaire mensuel'.tr,
      'piece' => 'Payé à la pièce'.tr,
      _ => '',
    };

/// État global de la paie du mois + une fiche de paie par ouvrier, dans un seul PDF.
Future<Uint8List> buildCloturePaie({required Atelier atelier, required DateTime mois, required List<LignePaie> lignes}) async {
  final libMois = fmtMonthYear(mois);
  final doc = await _nouveau(atelier, 'Paie {0}'.trf([libMois]));
  final theme = await _pdfTheme();
  double tot(double Function(LignePaie) f) => lignes.fold<double>(0, (s, l) => s + f(l));

  doc.addPage(pw.MultiPage(
    pageTheme: _page(theme),
    footer: (ctx) => _footer(ctx, atelier),
    build: (ctx) => [
      _entete(atelier, 'ÉTAT DE PAIE'.tr, [
        ['Mois'.tr, libMois],
        ['Ouvriers'.tr, '${lignes.length}'],
        ['Édité le'.tr, fmtDate(DateTime.now())],
      ]),
      pw.SizedBox(height: 18),
      _tableau(
        ['Ouvrier'.tr, 'Report'.tr, 'Gains'.tr, 'Avances'.tr, 'Retenues'.tr, 'Payé (mois)'.tr, 'Net'.tr, 'Réglé'.tr, 'Reste'],
        [
          for (final l in lignes)
            [
              l.departement.isEmpty ? l.nom : '${l.nom}\n${l.departement}',
              l.anterieur == 0 ? '' : fmtDA(l.anterieur),
              fmtDA(l.gains),
              l.avances == 0 ? '' : fmtDA(l.avances),
              l.retenues == 0 ? '' : fmtDA(l.retenues),
              l.paiements == 0 ? '' : fmtDA(l.paiements),
              fmtDA(l.net),
              l.paye == 0 ? '' : fmtDA(l.paye),
              fmtDA(l.reste),
            ],
        ],
        widths: const {0: pw.FlexColumnWidth(1.6), 1: pw.FlexColumnWidth(), 2: pw.FlexColumnWidth(), 3: pw.FlexColumnWidth(), 4: pw.FlexColumnWidth(), 5: pw.FlexColumnWidth(), 6: pw.FlexColumnWidth(), 7: pw.FlexColumnWidth(), 8: pw.FlexColumnWidth()},
        droite: {1, 2, 3, 4, 5, 6, 7, 8},
      ),
      pw.SizedBox(height: 14),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Spacer(),
        _totaux(
          [
            ('Total des gains'.tr, tot((l) => l.gains), false),
            ('Avances'.tr, tot((l) => l.avances), false),
            ('Retenues'.tr, tot((l) => l.retenues), false),
            ('Déjà payé dans le mois'.tr, tot((l) => l.paiements), false),
          ],
          net: ('Net à payer'.tr, tot((l) => l.net)),
          apres: [
            if (tot((l) => l.paye) > 0) ('Réglé à la clôture'.tr, tot((l) => l.paye), _green),
            ('Reste dû'.tr, tot((l) => l.reste), _red),
          ],
        ),
      ]),
      pw.SizedBox(height: 24),
      _signatures(['Établi par'.tr, 'Visa de la direction']),
    ],
  ));

  for (final l in lignes) {
    pw.Widget ligne(String t, double v, {bool gras = false, String signe = ''}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: gras ? pw.FontWeight.bold : null))),
            pw.Text('$signe${fmtDA(v)}', style: pw.TextStyle(fontSize: 10, fontWeight: gras ? pw.FontWeight.bold : null)),
          ]),
        );
    pw.Widget bloc(String titre, List<pw.Widget> c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: _goldLight,
            child: pw.Text(titre.toUpperCase(), style: _label()),
          ),
          ...c,
        ]);
    final regle = l.paye > 0 && l.reste.abs() < 0.5;
    doc.addPage(pw.Page(
      pageTheme: _page(theme),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        _entete(atelier, 'FICHE DE PAIE'.tr, [
          ['Mois'.tr, libMois],
          ['Ouvrier'.tr, l.nom],
          if (l.departement.isNotEmpty) ['Département'.tr, l.departement],
          if (_modePaie(l.mode).isNotEmpty) ['Mode'.tr, _modePaie(l.mode)],
        ]),
        pw.SizedBox(height: 20),
        bloc('Gains du mois'.tr, [
          if (l.broderie != 0) ligne('Broderie (points)'.tr, l.broderie),
          if (l.pieces != 0) ligne('Travaux à la pièce'.tr, l.pieces),
          if (l.salaires != 0) ligne('Salaire'.tr, l.salaires),
          if (l.primes != 0) ligne('Primes'.tr, l.primes),
          ligne('Total des gains'.tr, l.gains, gras: true),
        ]),
        pw.SizedBox(height: 12),
        bloc('Déductions du mois'.tr, [
          if (l.avances != 0) ligne('Avances'.tr, l.avances, signe: '− '),
          if (l.retenues != 0) ligne('Retenues'.tr, l.retenues, signe: '− '),
          if (l.paiements != 0) ligne('Déjà payé dans le mois'.tr, l.paiements, signe: '− '),
          ligne('Total des déductions'.tr, l.deductions, gras: true, signe: '− '),
        ]),
        if (l.anterieur != 0) ...[
          pw.SizedBox(height: 12),
          bloc('Report'.tr, [ligne(l.anterieur > 0 ? 'Reste dû des mois précédents'.tr : 'Avance non couverte des mois précédents'.tr, l.anterieur)]),
        ],
        pw.SizedBox(height: 16),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (l.net > 0) _lettres('Net à payer :'.tr, l.net),
              if (regle) ...[pw.SizedBox(height: 16), pw.Padding(padding: const pw.EdgeInsets.only(left: 30), child: _tampon('PAYÉE'.tr, _green))],
            ]),
          ),
          pw.SizedBox(width: 16),
          _totaux(
            [],
            net: (l.net >= 0 ? 'Net à payer'.tr : 'Avance à reporter'.tr, l.net.abs()),
            apres: [
              if (l.paye > 0) ('Réglé'.tr, l.paye, _green),
              if (l.paye > 0) ('Reste dû'.tr, l.reste, l.reste.abs() < 0.5 ? _grey : _red),
            ],
          ),
        ]),
        pw.Spacer(),
        _signatures(['Signature de l\'ouvrier'.tr, 'L\'employeur']),
        pw.SizedBox(height: 10),
        _footer(ctx, atelier),
      ]),
    ));
  }
  return doc.save();
}

// ============================================================== fiche de livraison d'un paquet de broderie

const _red2 = PdfColor.fromInt(0xFFD92D50);
const _goldSoft = PdfColor.fromInt(0xFFFBF6E9);
const _goldLine = PdfColor.fromInt(0xFFE6D3A3);

/// Coche ✓ dessinée (indépendante des polices).
pw.Widget _coche(PdfColor c, double t) => pw.CustomPaint(
      size: PdfPoint(t, t),
      painter: (canvas, size) {
        canvas
          ..setStrokeColor(c)
          ..setLineWidth(t * 0.16)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round)
          ..moveTo(size.x * 0.12, size.y * 0.52)
          ..lineTo(size.x * 0.40, size.y * 0.24)
          ..lineTo(size.x * 0.90, size.y * 0.80)
          ..strokePath();
      },
    );

/// Fiche remise à l'atelier de couture quand un paquet brodé est livré (une seule page A4).
/// Uniquement des pièces (pas de points par brodeur) + les points de la rechma.
Future<Uint8List> buildFicheLot({
  required Atelier atelier,
  required String numero,
  required int nbPieces,
  required String? dessinNom,
  required int dessinPoints,
  required Uint8List? dessinPhoto,
  required String? machineNom,
  required String? fil,
  required String? note,
  required DateTime? debut,
  required DateTime? livraison,
  required List<(String, String, int, int)> parOuvrier, // nom, équipes, jours, pièces
  required List<(DateTime, String, String, int)> jours, // date, équipe, brodeur, pièces
}) async {
  final doc = await _nouveau(atelier, 'Paquet {0}'.trf([numero]));
  final theme = await _pdfTheme();
  // Police des chiffres : toujours latine, de gauche à droite
  pw.Font? nR, nB;
  try {
    nR = await PdfGoogleFonts.interRegular();
    nB = await PdfGoogleFonts.interBold();
  } catch (_) {}
  final fin = livraison ?? DateTime.now();
  final duree = debut == null ? 0 : DateTime(fin.year, fin.month, fin.day).difference(DateTime(debut.year, debut.month, debut.day)).inDays + 1;
  final brodees = parOuvrier.fold<int>(0, (s, x) => s + x.$4);
  final ecart = brodees - nbPieces;
  final ok = ecart == 0;
  final cEcart = ok ? _green : _red2;

  /// Nombre (ou date) toujours écrit de gauche à droite avec la police latine.
  pw.Widget n(String v, {double size = 10, bool gras = false, PdfColor color = _ink}) => pw.Directionality(
        textDirection: pw.TextDirection.ltr,
        child: pw.Text(v, style: pw.TextStyle(font: gras ? nB : nR, fontBold: nB, fontSize: size, fontWeight: gras ? pw.FontWeight.bold : null, color: color)),
      );
  pw.Widget t(String v, {double size = 10, bool gras = false, PdfColor color = _ink, double espacement = 0}) =>
      pw.Text(v, style: pw.TextStyle(fontSize: size, fontWeight: gras ? pw.FontWeight.bold : null, color: color, letterSpacing: espacement));

  pw.Widget info(String k, pw.Widget v) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 3),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: pw.BoxDecoration(color: _goldSoft, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _goldLine, width: 0.7)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(k, size: 7.5, color: _grey),
            pw.SizedBox(height: 3),
            v,
          ]),
        ),
      );

  pw.Widget compteur(String titre, int? valeur, {required PdfColor bord, required PdfColor fond, pw.Widget? extra}) => pw.Expanded(
        child: pw.Container(
          height: 78,
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(color: fond, borderRadius: pw.BorderRadius.circular(12), border: pw.Border.all(color: bord, width: 1.4)),
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            t(titre, size: 9, gras: true, color: bord == _goldLine ? _grey : bord),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              if (valeur != null) n(valeur > 0 && extra == null && titre == 'Écart'.tr ? '+$valeur' : '$valeur', size: 30, gras: true, color: bord == _goldLine ? _ink : bord),
              if (extra != null) ...[pw.SizedBox(width: 6), extra],
            ]),
          ]),
        ),
      );

  pw.Widget titre(String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
        child: pw.Row(children: [
          pw.Container(width: 18, height: 1.2, color: _gold),
          pw.SizedBox(width: 6),
          t(v, size: 11, gras: true, color: _ink),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Container(height: 0.6, color: _goldLine)),
        ]),
      );

  /// Tableau élégant : en-tête or clair, lignes alternées ; [nums] = colonnes numériques.
  pw.Widget tableau(List<String> entetes, List<List<String>> lignes, List<int> flex, Set<int> nums) {
    pw.Widget cell(String v, int i, {bool head = false}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: head ? 6 : 5),
          alignment: nums.contains(i) ? pw.Alignment.center : (pdfSens == pw.TextDirection.rtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
          child: head
              ? t(v, size: 8.5, gras: true, color: _ink)
              : (nums.contains(i) || RegExp(r'^[0-9/ ]+$').hasMatch(v) ? n(v, size: 9.5, gras: nums.contains(i)) : t(v, size: 9.5)),
        );
    return pw.Container(
      decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: _goldLine, width: 0.8)),
      child: pw.Column(children: [
        pw.Container(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF3E7C6), borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(8))),
          child: pw.Row(children: [for (var i = 0; i < entetes.length; i++) pw.Expanded(flex: flex[i], child: cell(entetes[i], i, head: true))]),
        ),
        for (var r = 0; r < lignes.length; r++)
          pw.Container(
            color: r.isOdd ? _goldSoft : PdfColors.white,
            child: pw.Row(children: [for (var i = 0; i < lignes[r].length; i++) pw.Expanded(flex: flex[i], child: cell(lignes[r][i], i))]),
          ),
      ]),
    );
  }

  pw.Widget signature(String v) => pw.Expanded(
        child: pw.Container(
          height: 92,
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(10), border: pw.Border.all(color: _gold, width: 1)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            t(v, size: 10, gras: true, color: _ink),
            pw.SizedBox(height: 10),
            pw.Row(children: [t('Nom'.tr, size: 9, color: _grey), pw.SizedBox(width: 6), pw.Expanded(child: pw.Container(height: 0.7, color: _grey))]),
            pw.SizedBox(height: 12),
            pw.Row(children: [t('Date'.tr, size: 9, color: _grey), pw.SizedBox(width: 6), pw.Expanded(child: pw.Container(height: 0.7, color: _grey))]),
            pw.SizedBox(height: 12),
            pw.Row(children: [t('Signature'.tr, size: 9, color: _grey), pw.SizedBox(width: 6), pw.Expanded(child: pw.Container(height: 0.7, color: _grey))]),
          ]),
        ),
      );

  final page = pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    textDirection: pdfSens,
    theme: theme,
    margin: const pw.EdgeInsets.fromLTRB(34, 32, 34, 26),
    buildBackground: (ctx) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Stack(children: [
        pw.Positioned(left: 0, top: 0, right: 0, bottom: 0, 
          child: pw.Container(
            margin: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _gold, width: 1.4), borderRadius: pw.BorderRadius.circular(14)),
          ),
        ),
        pw.Positioned(left: 0, top: 0, right: 0, bottom: 0, 
          child: pw.Container(
            margin: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _goldLine, width: 0.5), borderRadius: pw.BorderRadius.circular(11)),
          ),
        ),
        if (_logo != null)
          pw.Center(child: pw.Opacity(opacity: 0.035, child: pw.Image(pw.MemoryImage(_logo!), width: 320, fit: pw.BoxFit.contain))),
      ]),
    ),
  );

  final contenu = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
    // ---- en-tête
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      if (_logo != null) ...[
        pw.Container(width: 54, height: 54, child: pw.Image(pw.MemoryImage(_logo!), fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 12),
      ],
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          t(atelier.nom.toUpperCase(), size: 9, gras: true, color: _gold, espacement: 1.6),
          pw.SizedBox(height: 3),
          t('FICHE DE LIVRAISON BRODERIE'.tr, size: 18, gras: true),
          pw.SizedBox(height: 2),
          t('De l\'atelier de broderie vers l\'atelier de couture'.tr, size: 8.5, color: _grey),
        ]),
      ),
      pw.Container(
        width: 86,
        height: 86,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: _gold,
          border: pw.Border.all(color: _goldLine, width: 3),
        ),
        child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
          t('Paquet'.tr, size: 8, gras: true, color: PdfColors.white),
          n('#$numero', size: 22, gras: true, color: PdfColors.white),
        ]),
      ),
    ]),
    pw.SizedBox(height: 12),
    pw.Container(height: 0.8, color: _goldLine),
    pw.SizedBox(height: 12),
    // ---- rechma
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Container(
        width: 128,
        height: 128,
        padding: const pw.EdgeInsets.all(3),
        decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(14), border: pw.Border.all(color: _gold, width: 1.4)),
        child: dessinPhoto != null
            ? pw.ClipRRect(horizontalRadius: 11, verticalRadius: 11, child: pw.Image(pw.MemoryImage(dessinPhoto), fit: pw.BoxFit.cover))
            : pw.Container(
                decoration: pw.BoxDecoration(color: _goldSoft, borderRadius: pw.BorderRadius.circular(11)),
                alignment: pw.Alignment.center,
                child: t('Pas de photo'.tr, size: 9, color: _grey),
              ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          t('Rechma'.tr, size: 9, gras: true, color: _gold, espacement: 1),
          pw.SizedBox(height: 2),
          t(dessinNom ?? '—', size: 20, gras: true),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(color: _goldSoft, borderRadius: pw.BorderRadius.circular(20), border: pw.Border.all(color: _gold, width: 1)),
            child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              n(fmtInt(dessinPoints), size: 13, gras: true, color: _ink),
              pw.SizedBox(width: 6),
              t('points par pièce'.tr, size: 10, gras: true, color: _ink),
            ]),
          ),
        ]),
      ),
    ]),
    pw.SizedBox(height: 12),
    pw.Row(children: [
      info('Machine'.tr, t(machineNom ?? '—', size: 10, gras: true)),
      info('Fil'.tr, t((fil ?? '').isEmpty ? '—' : fil!, size: 10, gras: true)),
      info('Début'.tr, n(debut == null ? '—' : fmtDate(debut), size: 10, gras: true)),
      info('Livraison'.tr, n(livraison == null ? '—' : fmtDate(livraison), size: 10, gras: true)),
      info('Durée'.tr, pw.Row(children: [n('$duree', size: 10, gras: true), pw.SizedBox(width: 3), t('jour(s)'.tr, size: 10, gras: true)])),
    ]),
    pw.SizedBox(height: 14),
    // ---- comptage
    pw.Row(children: [
      compteur('Pièces reçues'.tr, nbPieces, bord: _goldLine, fond: _goldSoft),
      compteur('Pièces brodées'.tr, brodees, bord: _goldLine, fond: PdfColors.white),
      compteur('Écart'.tr, ok ? null : ecart, bord: cEcart, fond: PdfColors.white, extra: ok ? _coche(_green, 30) : null),
    ]),
    if (!ok)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(children: [
          t(ecart < 0 ? 'Attention : pièces manquantes'.tr : 'Attention : pièces en plus'.tr, size: 10, gras: true, color: _red2),
          pw.SizedBox(width: 4),
          n('(${ecart.abs()})', size: 10, gras: true, color: _red2),
        ]),
      ),
    // ---- brodeurs
    titre('Brodeurs'.tr),
    tableau(
      ['Brodeur'.tr, 'Équipe'.tr, 'Jours'.tr, 'Pièces'.tr],
      [for (final o in parOuvrier) [o.$1, o.$2, '${o.$3}', '${o.$4}']],
      const [5, 3, 2, 2],
      {2, 3},
    ),
    // ---- jours
    titre('Détail par jour'.tr),
    tableau(
      ['Date'.tr, 'Équipe'.tr, 'Brodeur'.tr, 'Pièces'.tr],
      [for (final j in jours) [fmtDate(j.$1), j.$2, j.$3, '${j.$4}']],
      const [3, 3, 5, 2],
      {3},
    ),
    if (note != null && note.isNotEmpty) ...[
      pw.SizedBox(height: 8),
      pw.Row(children: [t('Remarque'.tr, size: 9, gras: true, color: _gold), pw.SizedBox(width: 6), pw.Expanded(child: t(note, size: 9.5))]),
    ],
    pw.SizedBox(height: 14),
    // ---- contrôle + signatures
    pw.Row(children: [
      pw.Container(
        width: 13,
        height: 13,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.3), borderRadius: pw.BorderRadius.circular(3)),
      ),
      pw.SizedBox(width: 8),
      t('Pièces comptées et vérifiées à la réception'.tr, size: 10.5, gras: true),
    ]),
    pw.SizedBox(height: 10),
    pw.Row(children: [
      signature('Livré par (broderie)'.tr),
      signature('Reçu par (couture)'.tr),
    ]),
  ]);

  doc.addPage(pw.Page(
    pageTheme: page,
    build: (ctx) => pw.Column(children: [
      // Tout tient sur une page : réduit automatiquement si les jours sont nombreux
      pw.Expanded(
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.topCenter,
          child: pw.SizedBox(width: PdfPageFormat.a4.width - 68, child: contenu),
        ),
      ),
      pw.SizedBox(height: 6),
      _footer(ctx, atelier),
    ]),
  ));
  return doc.save();
}
