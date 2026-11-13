import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _int = NumberFormat.decimalPattern('fr_FR');
final _money = NumberFormat('#,##0.00', 'fr_FR');
final _dateKey = DateFormat('yyyy-MM-dd');
final _dateFr = DateFormat('dd/MM/yyyy', 'fr_FR');
final _dateLong = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

String fmtInt(num n) => _int.format(n.round());
String fmtDA(num n) => '${_money.format(n)} DA';
String dateKey(DateTime d) => _dateKey.format(d);
String fmtDate(DateTime d) => _dateFr.format(d);
String fmtDateLong(DateTime d) => _dateLong.format(d);
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Périodes de filtrage. La semaine commence le samedi (Algérie).
enum Periode { aujourdhui, semaine, mois, moisDernier, tout, personnalisee }

extension PeriodeLabel on Periode {
  String get label => switch (this) {
        Periode.aujourdhui => "Aujourd'hui",
        Periode.semaine => 'Cette semaine',
        Periode.mois => 'Ce mois',
        Periode.moisDernier => 'Mois dernier',
        Periode.tout => 'Tout',
        Periode.personnalisee => 'Personnalisée',
      };
}

DateTimeRange rangeFor(Periode p, DateTimeRange? custom) {
  final now = dayOnly(DateTime.now());
  switch (p) {
    case Periode.aujourdhui:
      return DateTimeRange(start: now, end: now);
    case Periode.semaine:
      final diff = (now.weekday - DateTime.saturday + 7) % 7;
      return DateTimeRange(start: now.subtract(Duration(days: diff)), end: now);
    case Periode.mois:
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    case Periode.moisDernier:
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0);
      return DateTimeRange(start: start, end: end);
    case Periode.tout:
      return DateTimeRange(start: DateTime(2000, 1, 1), end: DateTime(2100, 12, 31));
    case Periode.personnalisee:
      return custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? cs.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Transforme une erreur technique en message compréhensible.
String errorMessage(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23503') {
      return 'Impossible : cet élément est utilisé dans des saisies de production. Désactivez-le plutôt.';
    }
    if (e.code == '23514') return 'Valeur invalide (vérifiez les nombres saisis).';
    return e.message;
  }
  if (e is AuthException) return e.message;
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
    return 'Pas de connexion Internet.';
  }
  return s;
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String action = 'Supprimer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));
int? parseInt(String s) => int.tryParse(s.trim().replaceAll(' ', '').replaceAll(' ', '').replaceAll(' ', ''));
