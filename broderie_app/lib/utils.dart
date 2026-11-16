import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'i18n.dart';

final _int = NumberFormat.decimalPattern('fr_FR');
final _money = NumberFormat('#,##0.00', 'fr_FR');
final _dateKey = DateFormat('yyyy-MM-dd');
DateFormat get _dateFr => DateFormat('dd/MM/yyyy', langue.localeDates);
DateFormat get _dateLong => DateFormat('EEEE d MMMM yyyy', langue.localeDates);
DateFormat get _dateShort => DateFormat('dd/MM', langue.localeDates);
DateFormat get _monthYear => DateFormat('MMMM yyyy', langue.localeDates);
final _compact = NumberFormat.compact(locale: 'fr_FR');
DateFormat get _weekday => DateFormat('E', langue.localeDates);
DateFormat get _shortMonth => DateFormat('MMM', langue.localeDates);

String fmtInt(num n) => _int.format(n.round());
final _dec = NumberFormat('#,##0.##', 'fr_FR');
String fmtNum(num n) => n == n.roundToDouble() ? fmtInt(n) : _dec.format(n);
String fmtDA(num n) => '{0} DA'.trf([_money.format(n)]);
String dateKey(DateTime d) => _dateKey.format(d);
String fmtDate(DateTime d) => _dateFr.format(d);
String fmtDateLong(DateTime d) => _dateLong.format(d);
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String fmtShort(DateTime d) => _dateShort.format(d);
String fmtMonthYear(DateTime d) => _monthYear.format(d);
String fmtCompact(num n) => _compact.format(n);
String fmtWeekday(DateTime d) => _weekday.format(d);
String fmtShortMonth(DateTime d) => _shortMonth.format(d);

/// Périodes de filtrage. La semaine commence le samedi (Algérie).
enum Periode { aujourdhui, semaine, mois, moisDernier, tout, personnalisee }

extension PeriodeLabel on Periode {
  String get label => switch (this) {
        Periode.aujourdhui => "Aujourd'hui".tr,
        Periode.semaine => 'Cette semaine'.tr,
        Periode.mois => 'Ce mois'.tr,
        Periode.moisDernier => 'Mois dernier'.tr,
        Periode.tout => 'Tout'.tr,
        Periode.personnalisee => 'Personnalisée'.tr,
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
      content: Text(msg.tr),
      backgroundColor: error ? cs.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Transforme une erreur technique en message compréhensible.
String errorMessage(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23503') {
      return 'Impossible : cet élément est utilisé dans des saisies de production. Désactivez-le plutôt.'.tr;
    }
    if (e.code == '23514') return 'Valeur invalide (vérifiez les nombres saisis).'.tr;
    return e.message;
  }
  if (e is AuthException) return e.message;
  final s = e.toString().replaceFirst('Exception: ', '');
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
    return 'Pas de connexion Internet.'.tr;
  }
  return s;
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String action = 'Supprimer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title.tr),
      content: Text(message.tr),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: Text(action.tr),
        ),
      ],
    ),
  );
  return r ?? false;
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(' ', '').replaceAll(',', '.'));
int? parseInt(String s) => int.tryParse(s.trim().replaceAll(' ', '').replaceAll(' ', '').replaceAll(' ', ''));
