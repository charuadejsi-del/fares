import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/session.dart';
import 'i18n.dart';
import 'theme.dart';
import 'utils.dart';

/// État du verrou par code PIN.
enum EtatPin { inactif, aCreer, verrouille, ouvert }

/// Verrouillage de l'application par code PIN (4 chiffres) :
/// à chaque ouverture, puis après 10 minutes d'inactivité ou en arrière-plan.
class VerrouPin extends ChangeNotifier with WidgetsBindingObserver {
  VerrouPin._();
  static final instance = VerrouPin._();

  static const delai = Duration(minutes: 10);

  EtatPin etat = EtatPin.inactif;
  DateTime _derniereActivite = DateTime.now();
  DateTime? _miseEnPause;
  Timer? _minuteur;
  bool _observe = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// Appelé une fois le compte chargé : vérifie si un PIN existe.
  String? _userId;

  Future<void> demarrer() async {
    final uid = _db.auth.currentUser?.id;
    // Même utilisateur déjà déverrouillé (ex. changement de langue) : rien à redemander
    if (uid != null && uid == _userId && etat == EtatPin.ouvert) return;
    _userId = uid;
    if (!_observe) {
      WidgetsBinding.instance.addObserver(this);
      _observe = true;
    }
    try {
      final r = Map<String, dynamic>.from(await _db.rpc('pin_etat') as Map);
      etat = r['defini'] == true ? EtatPin.verrouille : EtatPin.aCreer;
    } catch (_) {
      // Base pas encore à jour : ne jamais bloquer l'utilisateur
      etat = EtatPin.inactif;
    }
    _derniereActivite = DateTime.now();
    _minuteur?.cancel();
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) => _verifierInactivite());
    notifyListeners();
  }

  void arreter() {
    etat = EtatPin.inactif;
    _userId = null;
    _minuteur?.cancel();
    notifyListeners();
  }

  bool get bloque => etat == EtatPin.aCreer || etat == EtatPin.verrouille;

  /// Toute interaction (clic, touche, défilement) repousse le verrouillage.
  void activite() => _derniereActivite = DateTime.now();

  void _verifierInactivite() {
    if (etat == EtatPin.ouvert && DateTime.now().difference(_derniereActivite) >= delai) verrouiller();
  }

  void verrouiller() {
    if (etat != EtatPin.ouvert) return;
    etat = EtatPin.verrouille;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _miseEnPause ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _miseEnPause;
      _miseEnPause = null;
      if (p != null && DateTime.now().difference(p) >= delai) verrouiller();
      _verifierInactivite();
    }
  }

  /// Vérifie le PIN. Renvoie null si correct, sinon le message d'erreur.
  Future<String?> deverrouiller(String pin) async {
    final r = Map<String, dynamic>.from(await _db.rpc('pin_verifier', params: {'p_pin': pin}) as Map);
    if (r['ok'] == true) {
      etat = EtatPin.ouvert;
      activite();
      notifyListeners();
      return null;
    }
    if (r['defini'] == false) {
      etat = EtatPin.aCreer;
      notifyListeners();
      return 'Créez votre code PIN'.tr;
    }
    final bloque = r['bloque_jusqu'] == null ? null : DateTime.tryParse('${r['bloque_jusqu']}')?.toLocal();
    if (bloque != null && bloque.isAfter(DateTime.now())) {
      final min = bloque.difference(DateTime.now()).inMinutes + 1;
      return 'Trop d\'erreurs. Réessayez dans {0} min.'.trf([min]);
    }
    return 'Code incorrect. Il reste {0} essai(s).'.trf([r['restants'] ?? 0]);
  }

  Future<void> definir(String pin, {String? ancien}) async {
    await _db.rpc('pin_definir', params: {'p_pin': pin, 'p_ancien': ancien});
    etat = EtatPin.ouvert;
    activite();
    notifyListeners();
  }

  Future<void> reinitialiser(String userId) => _db.rpc('pin_reinitialiser', params: {'p_user': userId});
}

final verrou = VerrouPin.instance;

// ====================================================================== écran PIN

/// Mode de l'écran : déverrouiller, créer (2 étapes), ou changer (3 étapes).
enum ModePin { deverrouiller, creer, changer }

class EcranPin extends StatefulWidget {
  final ModePin mode;
  final VoidCallback? onTermine;
  const EcranPin({super.key, required this.mode, this.onTermine});

  @override
  State<EcranPin> createState() => _EcranPinState();
}

class _EcranPinState extends State<EcranPin> with SingleTickerProviderStateMixin {
  String _saisie = '';
  String? _premier; // création : 1re saisie
  String? _ancien; // changement : ancien PIN
  String? _erreur;
  bool _busy = false;
  final _focus = FocusNode();
  late final _secousse = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _focus.dispose();
    _secousse.dispose();
    super.dispose();
  }

  int get _etape {
    if (widget.mode == ModePin.changer) {
      if (_ancien == null) return 0;
      return _premier == null ? 1 : 2;
    }
    if (widget.mode == ModePin.creer) return _premier == null ? 1 : 2;
    return 0;
  }

  String get _titre => switch (widget.mode) {
        ModePin.deverrouiller => 'Entrez votre code PIN'.tr,
        _ => switch (_etape) {
            0 => 'Code PIN actuel'.tr,
            1 => widget.mode == ModePin.creer ? 'Créez votre code PIN'.tr : 'Nouveau code PIN'.tr,
            _ => 'Confirmez le code PIN'.tr,
          },
      };

  String get _sousTitre => switch (widget.mode) {
        ModePin.deverrouiller => '{0}, entrez vos 4 chiffres pour continuer'.trf([session.membre?.nom ?? '']),
        ModePin.creer => _etape == 1
            ? 'Première connexion : choisissez 4 chiffres. Ils vous seront demandés à chaque ouverture.'.tr
            : 'Tapez à nouveau les mêmes 4 chiffres'.tr,
        ModePin.changer => _etape == 0 ? 'Pour confirmer que c\'est bien vous'.tr : (_etape == 1 ? 'Choisissez 4 nouveaux chiffres'.tr : 'Tapez à nouveau les 4 chiffres'.tr),
      };

  void _erreurAnimee(String m) {
    HapticFeedback.heavyImpact();
    setState(() {
      _erreur = m;
      _saisie = '';
    });
    _secousse.forward(from: 0);
  }

  Future<void> _complet() async {
    final pin = _saisie;
    if (widget.mode == ModePin.deverrouiller) {
      setState(() => _busy = true);
      try {
        final e = await verrou.deverrouiller(pin);
        if (!mounted) return;
        setState(() => _busy = false);
        if (e != null) {
          _erreurAnimee(e);
        } else {
          widget.onTermine?.call();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          _erreurAnimee(errorMessage(e));
        }
      }
      return;
    }
    if (_etape == 0) {
      setState(() {
        _ancien = pin;
        _saisie = '';
        _erreur = null;
      });
      return;
    }
    if (_etape == 1) {
      if (RegExp(r'^(\d)\1{3}$').hasMatch(pin) || pin == '1234' || pin == '0123' || pin == '4321') {
        _erreurAnimee('Code trop simple, choisissez-en un autre.'.tr);
        return;
      }
      setState(() {
        _premier = pin;
        _saisie = '';
        _erreur = null;
      });
      return;
    }
    if (pin != _premier) {
      setState(() => _premier = null);
      _erreurAnimee('Les deux codes ne correspondent pas. Recommencez.'.tr);
      return;
    }
    setState(() => _busy = true);
    try {
      await verrou.definir(pin, ancien: _ancien);
      if (!mounted) return;
      widget.onTermine?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _ancien = null;
        _premier = null;
      });
      _erreurAnimee(errorMessage(e));
    }
  }

  void _touche(String c) {
    if (_busy) return;
    verrou.activite();
    if (c == '⌫') {
      if (_saisie.isNotEmpty) setState(() => _saisie = _saisie.substring(0, _saisie.length - 1));
      return;
    }
    if (_saisie.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _saisie += c;
      _erreur = null;
    });
    if (_saisie.length == 4) Future.delayed(const Duration(milliseconds: 120), _complet);
  }

  KeyEventResult _clavier(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _touche(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _touche('⌫');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _bouton(String c) {
    final vide = c.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(7),
      child: SizedBox(
        width: 74,
        height: 74,
        child: vide
            ? null
            : Material(
                color: c == '⌫' ? Colors.transparent : Colors.white.withValues(alpha: 0.07),
                shape: CircleBorder(side: BorderSide(color: c == '⌫' ? Colors.transparent : AppColors.gold.withValues(alpha: 0.35))),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _touche(c),
                  child: Center(
                    child: c == '⌫'
                        ? const Icon(Icons.backspace_outlined, color: Colors.white70)
                        : Text(c, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _clavier,
      child: Material(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF07090E), Color(0xFF141B2E), Color(0xFF3A2C0C)],
              stops: [0, 0.6, 1],
            ),
          ),
          child: SafeArea(
            child: Stack(children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 30)],
                      ),
                      child: Icon(widget.mode == ModePin.deverrouiller ? Icons.lock_rounded : Icons.pin_rounded, size: 34, color: AppColors.ink),
                    ),
                    const SizedBox(height: 22),
                    Text(_titre, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(_sousTitre, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB7BDCB))),
                    ),
                    const SizedBox(height: 26),
                    AnimatedBuilder(
                      animation: _secousse,
                      builder: (context, child) {
                        final t = _secousse.value;
                        final dx = t == 0 ? 0.0 : 14 * (1 - t) * ((t * 10).floor().isEven ? 1 : -1);
                        return Transform.translate(offset: Offset(dx, 0), child: child);
                      },
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 4; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _saisie.length ? (_erreur != null ? AppColors.rose : AppColors.gold) : Colors.transparent,
                                border: Border.all(color: _erreur != null ? AppColors.rose : AppColors.gold, width: 2),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: Center(
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_erreur ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A9E), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Column(children: [
                        for (final ligne in const [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['', '0', '⌫'],
                        ])
                          Row(mainAxisSize: MainAxisSize.min, children: [for (final c in ligne) _bouton(c)]),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    if (widget.mode != ModePin.changer)
                      TextButton.icon(
                        onPressed: () async {
                          verrou.arreter();
                          session.clear();
                          await Supabase.instance.client.auth.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFB7BDCB), size: 18),
                        label: Text(
                          widget.mode == ModePin.deverrouiller ? 'Code oublié ? Se déconnecter'.tr : 'Se déconnecter'.tr,
                          style: const TextStyle(color: Color(0xFFB7BDCB)),
                        ),
                      ),
                    if (widget.mode == ModePin.deverrouiller)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('En cas d\'oubli, l\'administrateur peut réinitialiser votre code.'.tr,
                            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7286), fontSize: 12)),
                      ),
                  ]),
                ),
              ),
              if (widget.mode == ModePin.changer)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: IconButton(
                    tooltip: 'Retour'.tr,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                    color: Colors.white,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Couche posée au-dessus de toute l'application : affiche l'écran PIN quand il faut.
class CouchePin extends StatelessWidget {
  final Widget child;
  const CouchePin({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => verrou.activite(),
        onPointerSignal: (_) => verrou.activite(),
        child: ListenableBuilder(
          listenable: verrou,
          builder: (context, _) => Stack(children: [
            // L'application reste montée dessous (on retrouve sa page en déverrouillant)
            ExcludeFocus(excluding: verrou.bloque, child: child),
            if (verrou.bloque)
              Positioned.fill(
                child: EcranPin(
                  key: ValueKey(verrou.etat),
                  mode: verrou.etat == EtatPin.aCreer ? ModePin.creer : ModePin.deverrouiller,
                ),
              ),
          ]),
        ),
      );
}
