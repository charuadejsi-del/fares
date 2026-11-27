# My DTF

Logiciel de l'atelier DTF : app client (Android + site web) et logiciel d'administration (Windows), sur Supabase (projet de l'atelier, tables `dtf_*`).

## État

| Phase | Contenu | État |
|---|---|---|
| 1 | Base Supabase : rôles, commandes, images, journal, problèmes, notifications, RLS | installée |
| 2 | Moteur d'imbrication (58 cm, 0,3 cm, rotation) + prix | testé |
| 3 | App client : compte, envoi des images + mesures, aperçu du film, prix, livraison/retrait, suivi en direct, notifications, signalement | code prêt |
| 4 | Logiciel Windows (gérant, designer, imprimeur, admin) | à faire |
| 5 | DHD / Ecotrack : frais de livraison + création du colis | à faire |
| 6 | Statistiques, problèmes par personne | à faire |

## Arborescence

```
my_dtf/
  lib/main.dart                     app client
  lib/config.dart                   URL + clé publique Supabase
  lib/core/nesting/nesting_engine.dart
  lib/core/pricing.dart
  lib/core/labels.dart              statuts, wilayas
  lib/services/api.dart             accès Supabase
  lib/screens/                      connexion, accueil, nouvelle commande, détail, notifications
  lib/widgets/nest_preview.dart     aperçu du film
  supabase/schema.sql
  test/nesting_engine_test.dart
.github/workflows/my_dtf_build.yml  build APK + web → release GitHub
```

## Build

Le workflow GitHub Actions génère les dossiers Android/Web (`flutter create`), lance les tests, construit `My-DTF.apk` et `my_dtf_web.zip`, puis publie une release.
En local : `flutter create --platforms android,web . && flutter run`.

## Mise en route

1. `dtf_settings` : renseigner `price_per_meter`, `min_order_amount`, `workshop_address`.
2. Créer son compte dans l'app, puis mettre `role = admin` sur sa ligne de `dtf_profiles`.
