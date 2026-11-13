# Atelier Broderie

Application native (Flutter) pour **PC Windows** et **Android** qui suit la production des machines à broder :
points brodés par ouvrier, nombre de robes, points par dessin et montant à payer.
Les données sont dans **Supabase** : le PC de l'atelier et les téléphones partagent les mêmes chiffres.

## Fonctions (v2)
- **Design pro** : thème **sombre premium** ou **clair** (ou automatique), cartes en dégradé, mise en page adaptée PC (menu latéral) et téléphone (barre du bas).
- **Tableau de bord** : grand total des points avec évolution par rapport à la période précédente, robes, montant à payer, moyenne par jour, **histogramme** des points par jour/mois, **donut** de répartition par ouvrier, **classement** avec médailles, dessins les plus brodés, export CSV.
- **Saisie rapide** en 3 touches : ouvrier → dessin (avec photo) → nombre de robes (boutons −/+, +5, +10, +20, +50), calcul en direct, total du jour.
- **Historique** : saisies regroupées par jour, modification et suppression, saisie détaillée.
- **Fiche ouvrier** : statistiques, graphique, détail par dessin, historique et **fiche de paie PDF** (impression ou partage).
- **Dessins avec photo** (appareil photo ou galerie), stockées dans Supabase Storage (privé par compte).
- **Machines** et **thème** dans Réglages.

Une saisie garde les points du dessin et le tarif de l'ouvrier **au moment où elle est enregistrée** : les modifier plus tard ne fausse pas l'historique.

## Sécurité
- Connexion par email et mot de passe (Supabase Auth).
- RLS : chaque compte ne voit et ne modifie que ses propres données.
- Un trigger empêche une saisie de pointer vers l'ouvrier, le dessin ou la machine d'un autre compte.
- Les ouvriers et dessins déjà utilisés dans des saisies ne peuvent pas être supprimés ; on les désactive.

## Installation
Chaque modification poussée sur la branche `broderie-flutter` lance la compilation automatique
(GitHub → onglet **Actions** → « Atelier Broderie — compilation ») :
- `atelier-broderie-windows` : dossier à décompresser, puis lancer `atelier_broderie.exe`
- `atelier-broderie-android` : `app-release.apk` à installer sur le téléphone (autoriser les sources inconnues)

## Base de données
Le schéma se trouve dans `supabase/schema_broderie.sql`. Il est déjà appliqué au projet Supabase.

## Développement
```bash
cd broderie_app
flutter create --platforms=windows,android --org dz.atelier --project-name atelier_broderie .
flutter pub get
flutter run -d windows
```
