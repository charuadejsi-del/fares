import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/commerce.dart';
import '../data/session.dart';
import '../data/stock.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'admin_screens.dart';
import 'gestion_screens.dart';
import 'abonnement_screen.dart';
import 'atelier_screen.dart';
import 'suivi_screen.dart';
import 'coupe_screen.dart';
import 'couture_screen.dart';
import '../data/couture.dart';
import 'modules.dart';
import 'ouvrier_detail_screen.dart';
import 'quick_entry_screen.dart';
import 'refs_screens.dart';
import 'settings_screen.dart';
import 'stock/achats_screen.dart' show AchatsModule;
import 'stock/produits_screen.dart' show ProduitsScreen;
import 'travaux_screens.dart';
import '../i18n.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Cle { accueil, suivi, coupe, broderie, decoration, couture, finition, paie, stock, ventes, achats }

class _Dest {
  final _Cle cle;
  final String label;
  final String title;
  final String section;
  final IconData icon;
  final IconData selected;
  const _Dest(this.cle, this.label, this.title, this.section, this.icon, this.selected);
}

/// Un élément de la recherche globale (page, action ou fiche).
class _Cible {
  final IconData icon;
  final String titre;
  final String sous;
  final String groupe;
  final VoidCallback ouvrir;
  final String? raccourci;
  const _Cible(this.icon, this.titre, this.sous, this.groupe, this.ouvrir, {this.raccourci});
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _loading = true;
  String? _error;
  final Set<int> _visitees = {0};
  final List<int> _historique = [];
  DateTime? _dernierRetour;
  List<Alerte> _alertes = [];

  List<_Dest> get _dests => [
        if (session.admin)
          _Dest(_Cle.accueil, 'Accueil'.tr, 'Vue d\'ensemble'.tr, 'Pilotage'.tr, Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
        if (session.admin)
          _Dest(_Cle.suivi, 'Suivi'.tr, 'Suivi de la production'.tr, 'Pilotage'.tr, Icons.timeline_outlined, Icons.timeline_rounded),
        if (session.peut(Espace.coupe))
          _Dest(_Cle.coupe, 'Coupe'.tr, 'Coupe · suivi des paquets'.tr, 'Atelier'.tr, Icons.content_cut_outlined, Icons.content_cut_rounded),
        if (session.peut(Espace.broderie))
          _Dest(_Cle.broderie, 'Broderie'.tr, 'Production broderie'.tr, 'Atelier'.tr, Icons.blur_on_outlined, Icons.blur_on_rounded),
        if (session.peut(Espace.applique))
          _Dest(_Cle.decoration, 'Appliqué'.tr, 'Appliqué'.tr, 'Atelier'.tr, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
        if (session.peut(Espace.paie))
          _Dest(_Cle.couture, 'Couture'.tr, 'Couture · ateliers externes'.tr, 'Atelier'.tr, Icons.design_services_outlined, Icons.design_services_rounded),
        if (session.peut(Espace.finition))
          _Dest(_Cle.finition, 'Finition'.tr, 'Finition · repassage · presse · emballage'.tr, 'Atelier'.tr, Icons.iron_outlined, Icons.iron_rounded),
        if (session.peut(Espace.paie))
          _Dest(_Cle.paie, 'Ouvriers'.tr, 'Ouvriers · salaires & avances'.tr, 'Atelier'.tr, Icons.groups_outlined, Icons.groups_rounded),
        if (session.peut(Espace.stock))
          _Dest(_Cle.stock, 'Robes'.tr, 'Stock des robes terminées'.tr, 'Commerce'.tr, Icons.checkroom_outlined, Icons.checkroom_rounded),
        if (session.peut(Espace.stock))
          _Dest(_Cle.ventes, 'Ventes'.tr, 'Ventes · commandes · clients'.tr, 'Commerce'.tr, Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
        if (session.peut(Espace.stock))
          _Dest(_Cle.achats, 'Achats'.tr, 'Achats · matières · fournisseurs'.tr, 'Commerce'.tr, Icons.shopping_basket_outlined, Icons.shopping_basket_rounded),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait<void>([
        if (session.production) data.loadRefs(),
        if (session.peut(Espace.stock)) stock.load(),
        if (session.peut(Espace.stock)) commerce.load().catchError((_) {}),
        if (session.production) couture.load(complet: session.voitPrix),
      ]);
    } catch (e) {
      _error = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
    _rafraichirAlertes();
  }

  Future<void> _rafraichirAlertes() async {
    try {
      final a = await calculerAlertes();
      if (mounted) setState(() => _alertes = a);
    } catch (_) {}
  }

  void _allerIndex(int i, {bool historique = true}) {
    if (i < 0 || i >= _dests.length || i == _index) return;
    setState(() {
      if (historique) {
        _historique.remove(i);
        _historique.add(_index);
      }
      _index = i;
      _visitees.add(i);
    });
  }

  bool get _peutRevenir => Retours.peutRevenir || _historique.isNotEmpty;

  /// Retour : d'abord dans les onglets de la page, puis vers la page précédente.
  bool _retour() {
    if (Retours.revenir()) return true;
    if (_historique.isNotEmpty) {
      _allerIndex(_historique.removeLast(), historique: false);
      return true;
    }
    return false;
  }

  void _gererRetourSysteme() {
    if (_retour()) return;
    // Rien à défaire : sur téléphone, deux appuis pour quitter
    if (estBureau) return;
    final now = DateTime.now();
    if (_dernierRetour != null && now.difference(_dernierRetour!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _dernierRetour = now;
    showSnack(context, 'Appuyez encore sur retour pour quitter'.tr);
  }

  void _aller(_Cle c) => _allerIndex(_dests.indexWhere((d) => d.cle == c));

  void _pousser(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _ouvrirAlertes() async {
    await _rafraichirAlertes();
    if (!mounted) return;
    _pousser(AlertesScreen(alertes: _alertes));
  }

  // ------------------------------------------------------------------ outils & recherche

  List<_Cible> get _outils => [
        if (session.peut(Espace.broderie))
          _Cible(Icons.bolt_rounded, 'Saisie rapide des points'.tr, 'Relevé du compteur de la machine'.tr, 'Actions'.tr,
              () => _pousser(Scaffold(appBar: AppBar(title: Text('Saisie rapide'.tr)), body: const QuickEntryScreen()))),
        if (session.peut(Espace.paie))
          _Cible(Icons.add_task_rounded, 'Saisie du travail'.tr, 'Pièces, travail au mois et extra'.tr, 'Actions'.tr,
              () => _pousser(Scaffold(appBar: AppBar(title: Text('Saisie du travail'.tr)), body: const TravauxSaisieScreen()))),
        if (session.peut(Espace.paie))
          _Cible(Icons.person_add_alt_1_rounded, 'Ajouter un ouvrier'.tr, 'Nouvelle fiche ouvrier'.tr, 'Actions'.tr,
              () => showDialog<bool>(context: context, builder: (_) => const OuvrierForm(null))),
        if (session.peut(Espace.paie))
          _Cible(Icons.lock_clock_rounded, 'Clôture de la paie'.tr, 'Fiches de paie du mois en un clic'.tr, 'Actions'.tr, () => _pousser(const CloturePaieScreen())),
        if (session.admin) _Cible(Icons.history_rounded, 'Journal des actions'.tr, 'Qui a fait quoi, et quand'.tr, 'Actions'.tr, () => _pousser(const JournalScreen())),
        _Cible(Icons.notifications_active_rounded, 'Alertes'.tr, '{0} alerte(s) en cours'.trf([_alertes.length]), 'Actions'.tr, _ouvrirAlertes),
        _Cible(Icons.settings_rounded, 'Réglages'.tr, 'Thème, comptes, entreprise, tarifs'.tr, 'Actions'.tr, () => _pousser(const SettingsScreen()), raccourci: 'Ctrl ,'.tr),
      ];

  List<_Cible> get _cibles {
    final dests = _dests;
    return [
      for (var i = 0; i < dests.length; i++)
        _Cible(dests[i].selected, dests[i].label, dests[i].title, 'Pages'.tr, () => _allerIndex(i), raccourci: i < 9 ? 'Ctrl {0}'.trf([i + 1]) : null),
      ..._outils,
      _Cible(context.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, context.isDark ? 'Passer en thème clair'.tr : 'Passer en thème sombre'.tr,
          'Apparence'.tr, 'Actions'.tr, () => ThemeController.instance.set(context.isDark ? ThemeMode.light : ThemeMode.dark)),
      if (session.peut(Espace.paie))
        for (final o in data.ouvriers.where((o) => o.actif))
          _Cible(Icons.badge_outlined, o.nom, '{0} · {1} à payer'.trf([o.departement.tr, fmtDA(data.solde(o.id).solde)]), 'Ouvriers'.tr,
              () => _pousser(OuvrierDetailScreen(ouvrierId: o.id))),
    ];
  }

  Future<void> _recherche() => showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => _PaletteRecherche(cibles: _cibles),
      );

  // ------------------------------------------------------------------ pages

  Widget _page(_Dest d) {
    final banniere = _banniereAbonnement();
    final page = _pageModule(d);
    return banniere == null ? page : Column(children: [banniere, Expanded(child: page)]);
  }

  /// Bandeau d'abonnement : expire bientôt, expiré ou suspendu (lecture seule).
  Widget? _banniereAbonnement() {
    final a = session.atelier;
    if (a == null || a.illimite) return a != null && a.suspendu ? _bandeau('Atelier suspendu : lecture seule. Contactez Warchati.'.tr, AppColors.rose) : null;
    final j = a.joursRestants!;
    if (a.suspendu) return _bandeau('Atelier suspendu : lecture seule. Contactez Warchati.'.tr, AppColors.rose);
    if (j < 0) return _bandeau('Abonnement expiré le {0} : lecture seule. Renouvelez auprès de Warchati.'.trf([fmtDate(a.abonnementFin!)]), AppColors.rose);
    if (a.essai) return _bandeau('Essai gratuit : {0} jour(s) restant(s). Choisissez un pack pour continuer.'.trf([j]), AppColors.gold);
    if (j <= 7) return _bandeau('Votre abonnement se termine dans {0} jour(s) ({1}).'.trf([j, fmtDate(a.abonnementFin!)]), AppColors.gold);
    return null;
  }

  Widget _bandeau(String t, Color c) => Material(
        color: c.withValues(alpha: .16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(Icons.info_rounded, color: c),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700))),
            if (session.admin)
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AbonnementScreen())).then((_) => setState(() {})),
                child: Text('Mon abonnement'.tr),
              ),
          ]),
        ),
      );

  Widget _pageModule(_Dest d) {
    return switch (d.cle) {
      _Cle.accueil => VueEnsembleScreen(
          onAller: (i) => _aller(switch (i) {
            1 => _Cle.broderie,
            2 => _Cle.paie,
            _ => _Cle.ventes,
          }),
        ),
      _Cle.coupe => const CoupeModule(),
      _Cle.couture => const CoutureModule(),
      _Cle.suivi => const SuiviScreen(),
      _Cle.decoration => const AtelierInterneModule(etapes: ['applique']),
      _Cle.finition => const AtelierInterneModule(etapes: ['akkach', 'finition']),
      _Cle.broderie => BroderieModule(onGoToOuvriers: session.peut(Espace.paie) ? () => _aller(_Cle.paie) : null),
      _Cle.paie => const OuvriersModule(),
      _Cle.stock => const ProduitsScreen(),
      _Cle.ventes => const VentesModule(),
      _Cle.achats => const AchatsModule(),
    };
  }

  /// Pages gardées en mémoire (on retrouve sa place en revenant), avec un fondu à l'arrivée.
  Widget _contenu(List<_Dest> dests) {
    if (_loading && !data.refsLoaded && !stock.loaded) return const _Chargement();
    if (_error != null && !data.refsLoaded && !stock.loaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text('Réessayer'.tr)),
          ]),
        ),
      );
    }
    return IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < dests.length; i++)
          _visitees.contains(i)
              ? PageActive(
                  actif: i == _index,
                  child: TickerMode(enabled: i == _index, child: _Apparition(actif: i == _index, child: _page(dests[i]))),
                )
              : const SizedBox.shrink(),
      ],
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final dests = _dests;
    if (dests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Atelier'.tr), actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => _pousser(const SettingsScreen())),
        ]),
        body: Center(child: Text('Aucun accès n\'est attribué à ce compte.\nDemandez à l\'administrateur.'.tr, textAlign: TextAlign.center)),
      );
    }
    if (_index >= dests.length) _index = 0;
    final d = dests[_index];
    final w = MediaQuery.sizeOf(context).width;

    final raccourcis = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): _recherche,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _recherche,
      const SingleActivator(LogicalKeyboardKey.f5): _load,
      const SingleActivator(LogicalKeyboardKey.escape): _retour,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _retour,
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _pousser(const SettingsScreen()),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): UiPrefs.instance.basculerSidebar,
      for (var i = 0; i < dests.length && i < 9; i++)
        SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _allerIndex(i),
    };

    final Widget corps;
    if (w >= 640) {
      corps = ListenableBuilder(
        listenable: UiPrefs.instance,
        builder: (context, _) {
          final reduite = w < 1100 || UiPrefs.instance.sidebarReduite;
          return Scaffold(
            body: Row(children: [
              _Sidebar(
                dests: dests,
                index: _index,
                reduite: reduite,
                peutAgrandir: w >= 1100,
                outils: _outils,
                nbAlertes: _alertes.length,
                onSelect: _allerIndex,
              ),
              Expanded(
                child: Column(children: [
                  _BarreHaut(
                    dest: d,
                    onRetour: _retour,
                    nbAlertes: _alertes.length,
                    onRecherche: _recherche,
                    onAlertes: _ouvrirAlertes,
                    onActualiser: _load,
                    chargement: _loading,
                  ),
                  Expanded(child: _contenu(dests)),
                ]),
              ),
            ]),
          );
        },
      );
    } else {
      corps = _Mobile(
        onRetour: _retour,
        dests: dests,
        index: _index,
        contenu: _contenu(dests),
        outils: _outils,
        nbAlertes: _alertes.length,
        onSelect: _allerIndex,
        onRecherche: _recherche,
        onAlertes: _ouvrirAlertes,
        onActualiser: _load,
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _gererRetourSysteme();
      },
      child: CallbackShortcuts(bindings: raccourcis, child: Focus(autofocus: true, child: corps)),
    );
  }
}

// ====================================================================== éléments communs

class _Apparition extends StatefulWidget {
  final bool actif;
  final Widget child;
  const _Apparition({required this.actif, required this.child});

  @override
  State<_Apparition> createState() => _ApparitionState();
}

class _ApparitionState extends State<_Apparition> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: widget.actif ? 0 : 1);
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.actif) _c.forward();
  }

  @override
  void didUpdateWidget(_Apparition old) {
    super.didUpdateWidget(old);
    if (widget.actif && !old.actif) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(_a), child: widget.child),
      );
}

class _Chargement extends StatelessWidget {
  const _Chargement();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Logo(taille: 56),
          const SizedBox(height: 18),
          const SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 3)),
          const SizedBox(height: 12),
          Text('Chargement de l\'atelier…'.tr, style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Logo extends StatelessWidget {
  final double taille;
  const _Logo({this.taille = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(taille * 0.3),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: taille * 0.4)],
        ),
        child: Icon(Icons.diamond_rounded, color: AppColors.ink, size: taille * 0.55),
      );
}

String _role() {
  final m = session.membre;
  if (m == null) return '';
  if (m.admin) return 'Administrateur'.tr;
  return [if (m.broderie) 'Broderie'.tr, if (m.paie) 'Paie'.tr, if (m.stock) 'Stock'].join(' · ');
}

String _bonjour() {
  final h = DateTime.now().hour;
  return h < 5 ? 'Bonne nuit'.tr : (h < 18 ? 'Bonjour'.tr : 'Bonsoir'.tr);
}

// ====================================================================== PC : barre latérale

class _Sidebar extends StatelessWidget {
  final List<_Dest> dests;
  final int index;
  final bool reduite;
  final bool peutAgrandir;
  final List<_Cible> outils;
  final int nbAlertes;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.dests,
    required this.index,
    required this.reduite,
    required this.peutAgrandir,
    required this.outils,
    required this.nbAlertes,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    String? section;
    for (var i = 0; i < dests.length; i++) {
      final d = dests[i];
      if (d.section != section) {
        section = d.section;
        items.add(_TitreSection(section, reduite: reduite));
      }
      items.add(_ItemSidebar(
        icon: i == index ? d.selected : d.icon,
        label: d.label,
        actif: i == index,
        reduite: reduite,
        raccourci: i < 9 ? 'Ctrl+{0}'.trf([i + 1]) : null,
        onTap: () => onSelect(i),
      ));
    }
    items.add(_TitreSection('Outils'.tr, reduite: reduite));
    for (final o in outils.where((o) => o.titre != 'Réglages'.tr)) {
      items.add(_ItemSidebar(
        icon: o.icon,
        label: o.titre,
        reduite: reduite,
        badge: o.titre == 'Alertes'.tr ? nbAlertes : 0,
        onTap: o.ouvrir,
      ));
    }
    final reglages = outils.firstWhere((o) => o.titre == 'Réglages'.tr);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: reduite ? 78 : 262,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: Color(0x40D4AF37), width: 1)),
      ),
      child: SafeArea(
        right: false,
        child: Column(children: [
          // Marque
          Padding(
            padding: EdgeInsets.fromLTRB(reduite ? 0 : 18, 20, reduite ? 0 : 12, 14),
            child: Row(
              mainAxisAlignment: reduite ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const _Logo(taille: 40),
                if (!reduite) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session.atelier?.nom ?? 'Atelier'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: 0.2)),
                      Text('GESTION D\'ATELIER'.tr,
                          style: TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, AppColors.gold.withValues(alpha: 0.5), Colors.transparent]),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10), children: items),
          ),
          // Utilisateur
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: EdgeInsets.all(reduite ? 6 : 10),
            decoration: BoxDecoration(
              color: AppColors.sidebarHover,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF242A39)),
            ),
            child: reduite
                ? Column(children: [
                    Tooltip(message: session.membre?.nom ?? '', child: NameAvatar(session.membre?.nom ?? '?', size: 36)),
                    const SizedBox(height: 6),
                    _BoutonIcone(icon: Icons.settings_rounded, tip: 'Réglages (Ctrl+,)'.tr, onTap: reglages.ouvrir),
                    if (peutAgrandir) _BoutonIcone(icon: Icons.keyboard_double_arrow_right_rounded, tip: 'Agrandir (Ctrl+B)'.tr, onTap: UiPrefs.instance.basculerSidebar),
                  ])
                : Row(children: [
                    NameAvatar(session.membre?.nom ?? '?', size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(session.membre?.nom ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(_role(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8F97AB), fontSize: 11)),
                      ]),
                    ),
                    _BoutonIcone(icon: Icons.settings_rounded, tip: 'Réglages (Ctrl+,)'.tr, onTap: reglages.ouvrir),
                    _BoutonIcone(icon: Icons.keyboard_double_arrow_left_rounded, tip: 'Réduire (Ctrl+B)'.tr, onTap: UiPrefs.instance.basculerSidebar),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String titre;
  final bool reduite;
  const _TitreSection(this.titre, {required this.reduite});

  @override
  Widget build(BuildContext context) => reduite
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
          child: Container(height: 1, color: const Color(0xFF242A39)),
        )
      : Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
          child: Text(titre.toUpperCase(),
              style: const TextStyle(color: Color(0xFF6B7286), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
        );
}

class _ItemSidebar extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool actif;
  final bool reduite;
  final String? raccourci;
  final int badge;
  final VoidCallback onTap;

  const _ItemSidebar({
    required this.icon,
    required this.label,
    required this.reduite,
    required this.onTap,
    this.actif = false,
    this.raccourci,
    this.badge = 0,
  });

  @override
  State<_ItemSidebar> createState() => _ItemSidebarState();
}

class _ItemSidebarState extends State<_ItemSidebar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final couleur = widget.actif ? AppColors.gold : (_hover ? Colors.white : const Color(0xFFB7BDCB));
    Widget icone = Icon(widget.icon, size: 21, color: couleur);
    if (widget.badge > 0) icone = Badge(label: Text('${widget.badge}'), child: icone);
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.reduite ? 0 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: widget.actif
                ? LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.24), AppColors.gold.withValues(alpha: 0.04)])
                : null,
            color: widget.actif ? null : (_hover ? AppColors.sidebarHover : Colors.transparent),
            border: Border.all(color: widget.actif ? AppColors.gold.withValues(alpha: 0.45) : Colors.transparent),
          ),
          child: widget.reduite
              ? Center(child: icone)
              : Row(children: [
                  icone,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: couleur, fontWeight: widget.actif ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
                  ),
                  if (widget.raccourci != null && (_hover || widget.actif))
                    Text(widget.raccourci!, style: const TextStyle(color: Color(0xFF6B7286), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
        ),
      ),
    );
    return widget.reduite
        ? Tooltip(message: widget.raccourci == null ? widget.label : '${widget.label}  (${widget.raccourci})', preferBelow: false, child: item)
        : item;
  }
}

class _BoutonIcone extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  const _BoutonIcone({required this.icon, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 19, color: const Color(0xFFB7BDCB)),
      );
}

// ====================================================================== PC : barre du haut

class _BarreHaut extends StatelessWidget {
  final _Dest dest;
  final bool Function() onRetour;
  final int nbAlertes;
  final VoidCallback onRecherche;
  final VoidCallback onAlertes;
  final VoidCallback onActualiser;
  final bool chargement;

  const _BarreHaut({
    required this.dest,
    required this.onRetour,
    required this.nbAlertes,
    required this.onRecherche,
    required this.onAlertes,
    required this.onActualiser,
    required this.chargement,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      child: Row(children: [
        _BoutonRetour(onRetour: onRetour),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dest.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleLarge),
            const SizedBox(height: 2),
            Text('${_bonjour()} ${session.membre?.nom ?? ''} · ${fmtDateLong(DateTime.now())}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 16),
        // Champ de recherche (ouvre la palette)
        InkWell(
          onTap: onRecherche,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: w >= 1300 ? 340 : 230,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.pal.line),
            ),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 20, color: context.pal.muted),
              const SizedBox(width: 8),
              Expanded(child: Text('Rechercher, ouvrir…'.tr, style: TextStyle(color: context.pal.muted))),
              _Touche('Ctrl K'.tr),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Alertes'.tr,
          onPressed: onAlertes,
          icon: Badge(isLabelVisible: nbAlertes > 0, label: Text('$nbAlertes'), child: const Icon(Icons.notifications_outlined)),
        ),
        IconButton(
          tooltip: 'Actualiser (F5)'.tr,
          onPressed: chargement ? null : onActualiser,
          icon: chargement
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: context.isDark ? 'Thème clair'.tr : 'Thème sombre'.tr,
          onPressed: () => ThemeController.instance.set(context.isDark ? ThemeMode.light : ThemeMode.dark),
          icon: Icon(context.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
      ]),
    );
  }
}

/// Bouton « retour » : visible seulement s'il y a une page ou un onglet précédent.
class _BoutonRetour extends StatelessWidget {
  final bool Function() onRetour;
  final Widget sinon;
  const _BoutonRetour({required this.onRetour, this.sinon = const SizedBox.shrink()});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Retours.version,
        builder: (context, _, __) {
          final shell = context.findAncestorStateOfType<_HomeShellState>();
          final peut = shell?._peutRevenir ?? false;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: peut
                ? Padding(
                    key: const ValueKey('retour'),
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: IconButton.filledTonal(
                      tooltip: estBureau ? 'Retour (Échap)'.tr : 'Retour'.tr,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onRetour();
                      },
                      icon: const BackButtonIcon(),
                    ),
                  )
                : KeyedSubtree(key: const ValueKey('sans'), child: sinon),
          );
        },
      );
}

class _Touche extends StatelessWidget {
  final String texte;
  const _Touche(this.texte);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.pal.line),
        ),
        child: Text(texte, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: context.pal.muted)),
      );
}

// ====================================================================== téléphone

class _Mobile extends StatelessWidget {
  final bool Function() onRetour;
  final List<_Dest> dests;
  final int index;
  final Widget contenu;
  final List<_Cible> outils;
  final int nbAlertes;
  final ValueChanged<int> onSelect;
  final VoidCallback onRecherche;
  final VoidCallback onAlertes;
  final VoidCallback onActualiser;

  const _Mobile({
    required this.onRetour,
    required this.dests,
    required this.index,
    required this.contenu,
    required this.outils,
    required this.nbAlertes,
    required this.onSelect,
    required this.onRecherche,
    required this.onAlertes,
    required this.onActualiser,
  });

  /// 5 onglets maximum : au-delà, les derniers passent dans « Plus ».
  int get _nbOnglets => dests.length <= 5 ? dests.length : 4;

  void _plus(BuildContext context) {
    final reste = [for (var i = _nbOnglets; i < dests.length; i++) i];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              NameAvatar(session.membre?.nom ?? '?', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.membre?.nom ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('${session.atelier?.nom ?? ''} · ${_role()}', style: TextStyle(color: ctx.pal.muted, fontSize: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final i in reste)
                  _TuilePlus(
                    icon: dests[i].selected,
                    label: dests[i].label,
                    actif: i == index,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(i);
                    },
                  ),
                for (final o in outils)
                  _TuilePlus(
                    icon: o.icon,
                    label: o.titre,
                    badge: o.titre == 'Alertes'.tr ? nbAlertes : 0,
                    onTap: () {
                      Navigator.pop(ctx);
                      o.ouvrir();
                    },
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _nbOnglets;
    final avecPlus = dests.length > n;
    final sel = index < n ? index : n; // « Plus » sélectionné si la page y est
    final d = dests[index];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 8,
        automaticallyImplyLeading: false,
        title: Row(children: [
          _BoutonRetour(onRetour: onRetour, sinon: const Padding(padding: EdgeInsetsDirectional.only(start: 8), child: _Logo(taille: 34))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${_bonjour()} ${session.membre?.nom ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.pal.muted, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'Rechercher'.tr, onPressed: onRecherche, icon: const Icon(Icons.search_rounded)),
          IconButton(
            tooltip: 'Alertes'.tr,
            onPressed: onAlertes,
            icon: Badge(isLabelVisible: nbAlertes > 0, label: Text('$nbAlertes'), child: const Icon(Icons.notifications_outlined)),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.transparent, AppColors.gold.withValues(alpha: 0.45), Colors.transparent]),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => onActualiser(),
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: contenu,
      ),
      bottomNavigationBar: dests.length < 2
          ? null
          : NavigationBar(
              selectedIndex: sel,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                if (avecPlus && i == n) {
                  _plus(context);
                } else {
                  onSelect(i);
                }
              },
              destinations: [
                for (var i = 0; i < n; i++)
                  NavigationDestination(icon: Icon(dests[i].icon), selectedIcon: Icon(dests[i].selected), label: dests[i].label),
                if (avecPlus)
                  NavigationDestination(
                    icon: Badge(isLabelVisible: nbAlertes > 0, smallSize: 8, child: const Icon(Icons.grid_view_outlined)),
                    selectedIcon: const Icon(Icons.grid_view_rounded),
                    label: 'Plus'.tr,
                  ),
              ],
            ),
    );
  }
}

class _TuilePlus extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool actif;
  final int badge;
  final VoidCallback onTap;
  const _TuilePlus({required this.icon, required this.label, required this.onTap, this.actif = false, this.badge = 0});

  @override
  Widget build(BuildContext context) => Material(
        color: actif ? AppColors.gold.withValues(alpha: 0.16) : context.pal.surface2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.isDark ? AppColors.gold : AppColors.violetDeep),
                ),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ====================================================================== recherche globale (Ctrl+K)

class _PaletteRecherche extends StatefulWidget {
  final List<_Cible> cibles;
  const _PaletteRecherche({required this.cibles});

  @override
  State<_PaletteRecherche> createState() => _PaletteRechercheState();
}

class _PaletteRechercheState extends State<_PaletteRecherche> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  int _sel = 0;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  List<_Cible> get _resultats {
    final q = _norm(_q.text.trim());
    if (q.isEmpty) return widget.cibles.where((c) => c.groupe != 'Ouvriers'.tr).toList();
    final mots = q.split(RegExp(r'\s+'));
    return widget.cibles.where((c) {
      final t = _norm('${c.titre} ${c.sous} ${c.groupe}');
      return mots.every(t.contains);
    }).take(40).toList();
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ouvrir(_Cible c) {
    Navigator.of(context).pop();
    c.ouvrir();
  }

  void _deplacer(int delta, int n) {
    if (n == 0) return;
    setState(() => _sel = (_sel + delta) % n < 0 ? n - 1 : (_sel + delta) % n);
    final y = _sel * 58.0;
    if (_scroll.hasClients && (y < _scroll.offset || y > _scroll.offset + 380)) {
      _scroll.animateTo((y - 160).clamp(0, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _resultats;
    if (_sel >= res.length) _sel = 0;
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final lignes = <Widget>[];
    String? groupe;
    for (var i = 0; i < res.length; i++) {
      final c = res[i];
      if (c.groupe != groupe) {
        groupe = c.groupe;
        lignes.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(groupe.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: context.pal.muted)),
        ));
      }
      final sel = i == _sel;
      lignes.add(MouseRegion(
        onHover: (_) {
          if (_sel != i) setState(() => _sel = i);
        },
        child: InkWell(
          onTap: () => _ouvrir(c),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sel ? AppColors.gold.withValues(alpha: 0.14) : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppColors.gold.withValues(alpha: 0.45) : Colors.transparent),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(10)),
                child: Icon(c.icon, size: 19, color: sel ? AppColors.gold : context.pal.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.titre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(c.sous, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.pal.muted)),
                ]),
              ),
              if (c.raccourci != null && !mobile) _Touche(c.raccourci!),
              if (sel && !mobile) ...[const SizedBox(width: 8), Icon(Icons.keyboard_return_rounded, size: 16, color: context.pal.muted)],
            ]),
          ),
        ),
      ));
    }

    final champ = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _deplacer(1, res.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _deplacer(-1, res.length),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (res.isNotEmpty) _ouvrir(res[_sel]);
        },
      },
      child: TextField(
        controller: _q,
        autofocus: true,
        onChanged: (_) => setState(() => _sel = 0),
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Rechercher une page, une action, un ouvrier…'.tr,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: mobile ? null : Padding(padding: EdgeInsets.all(12), child: _Touche('Échap'.tr)),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );

    final contenu = Column(mainAxisSize: MainAxisSize.min, children: [
      champ,
      Divider(height: 1, color: context.pal.line),
      Flexible(
        child: res.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(30),
                child: Text('Aucun résultat'.tr, style: TextStyle(color: context.pal.muted)),
              )
            : ListView(controller: _scroll, shrinkWrap: true, padding: const EdgeInsets.only(bottom: 8), children: lignes),
      ),
      if (!mobile)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.pal.line))),
          child: Row(children: [
            const _Touche('↑ ↓'),
            Text('  naviguer    ', style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
            _Touche('Entrée'.tr),
            Text('  ouvrir', style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
            const Spacer(),
            const Icon(Icons.diamond_rounded, size: 14, color: AppColors.gold),
          ]),
        ),
    ]);

    if (mobile) {
      return Dialog.fullscreen(
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
              Text('Recherche'.tr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
            Expanded(child: contenu),
          ]),
        ),
      );
    }
    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: context.cs.surface,
        elevation: 24,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520), child: contenu),
      ),
    );
  }
}
