import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n_ar.dart';

/// Langue de l'interface : « fr » (français) ou « ar » (arabe, de droite à gauche).
class Langue extends ValueNotifier<String> {
  Langue._() : super('fr');
  static final instance = Langue._();
  static const _cle = 'langue';

  bool get ar => value == 'ar';

  /// Locale des dates : arabe d'Algérie (chiffres latins) si disponible.
  String get localeDates {
    if (!ar) return 'fr_FR';
    return DateFormat.localeExists('ar_DZ') ? 'ar_DZ' : 'ar';
  }

  Future<void> load() async {
    try {
      await Future.wait([initializeDateFormatting('fr_FR'), initializeDateFormatting('ar_DZ').catchError((_) {}), initializeDateFormatting('ar')]);
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      value = p.getString(_cle) == 'ar' ? 'ar' : 'fr';
    } catch (_) {}
    Intl.defaultLocale = ar ? localeDates : 'fr_FR';
  }

  Future<void> set(String v) async {
    Intl.defaultLocale = v == 'ar' ? (DateFormat.localeExists('ar_DZ') ? 'ar_DZ' : 'ar') : 'fr_FR';
    value = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_cle, v);
    } catch (_) {}
  }
}

final langue = Langue.instance;

extension TraductionX on String {
  /// Texte traduit dans la langue de l'application (le français sert de clé).
  String get tr => langue.ar ? (arabe[this] ?? this) : this;

  /// Texte avec valeurs : 'Bonjour {0}'.trf([nom]).
  String trf(List<Object?> valeurs) {
    var s = langue.ar ? (arabe[this] ?? this) : this;
    for (var i = 0; i < valeurs.length; i++) {
      s = s.replaceAll('{$i}', '${valeurs[i] ?? ''}');
    }
    return s;
  }
}
