# Atelier Broderie

Application native (Flutter) pour **PC Windows** et **Android** qui suit la production des machines à broder :
points brodés par ouvrier, nombre de robes, points par dessin et montant à payer.
Les données sont dans **Supabase** : le PC de l'atelier et les téléphones partagent les mêmes chiffres.

## Fonctions
- **Tableau de bord** : total des points, des robes, du montant à payer et des saisies, par période (aujourd'hui, semaine à partir du samedi, mois, mois dernier, dates au choix) et par ouvrier ; classement des ouvriers ; totaux par dessin ; export CSV pour Excel.
- **Production** : saisie (date, ouvrier, dessin, nombre de robes, machine, remarque) avec calcul automatique `robes × points du dessin` et du montant. Les saisies sont regroupées par jour, et on peut les modifier ou les supprimer.
- **Ouvriers** : nom, téléphone, tarif en DA pour 1000 points, actif/inactif.
- **Dessins** : nom, nombre de points par robe, client, remarque.
- **Machines** (facultatif) : nom, nombre de têtes.

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
