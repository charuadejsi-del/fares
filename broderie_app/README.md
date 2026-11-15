# Atelier Broderie

Application native (Flutter) pour **PC Windows** et **Android** qui suit la production des machines à broder :
points brodés par ouvrier, nombre de robes, points par dessin et montant à payer.
Les données sont dans **Supabase** : le PC de l'atelier et les téléphones partagent les mêmes chiffres.

## Modèles couleurs × tailles, nouveau design (v7)

- **Modèles** : on choisit les couleurs et les tailles, puis la quantité de chaque combinaison ; chaque variante a sa référence et son QR.
- **Vente / commande** : choix du modèle puis grille couleur × taille avec le disponible ; le stock baisse automatiquement.
- **Espaces séparés** : Robes (stock terminé), Ventes (ventes, commandes, clients), Achats (matières, achats, fournisseurs).
- **Thème noir & or**, documents PDF redessinés (facture, BL sans transport, bon de commande, devis, avoir, relevé) avec QR (ex. page Facebook) en bas à droite.

## Commerce, matières et pilotage (v6)

- **Commandes clients** avec réservation du stock, **devis / proforma** convertibles, livraison → facture automatique.
- **Retours et avoirs** (remise en stock, déduits du solde client), **prix spéciaux par client**.
- **Matières, fournisseurs, achats** : stock des matières au coût moyen, dettes fournisseurs, paiements.
- **Composition des robes** (matières par pièce) → coût de revient réel et marge ; bouton *Fabrication* qui déduit les matières.
- **Tableau de bord** : ventes sur 12 mois, meilleurs clients et robes, marge estimée.
- **Alertes** (cloche) : ruptures, matières basses, impayés > 30 jours, commandes en retard, devis expirés, avances non couvertes.
- **Logo** de l'entreprise sur les factures, BL, devis et avoirs.
- **Installateur Windows** (`AtelierBroderie-Setup-x.y.z.exe`) et **APK signé avec une clé fixe** (`android-signing/`) : les mises à jour s'installent par-dessus.

## Atelier partagé, employés, stock et ventes (v5)
- **Comptes** : l'administrateur crée des comptes employés (Réglages → Employés et accès) avec un identifiant et un mot de passe.
  Chaque compte n'a accès qu'aux espaces cochés : **Broderie**, **Paie & avances**, **Stock & ventes**. L'admin voit tout (Vue d'ensemble).
- **Stock** : produits (robes) avec référence = QR code, stock en temps réel, alertes, inventaire, historique, impression d'étiquettes QR (A4 ou imprimante d'étiquettes).
- **Scan** : appareil photo du téléphone (ou douchette USB sur PC) pour ajouter/retirer du stock ou remplir une vente.
- **Ventes en gros** : panier par scan, prix modifiables, remise, TVA (réglable), versement à la vente ; le stock baisse automatiquement.
  Numérotation automatique **facture F-AAAA-0001** et **bon de livraison BL-AAAA-0001**, PDF prêts à imprimer/partager (montant en lettres).
- **Clients** : total acheté, versé, reste à payer, versements (espèces, chèque, virement, CCP), relevé de compte PDF.
- Base : `supabase/v5a_atelier_droits.sql`, `supabase/v5b_stock_ventes.sql` ; fonction serveur `supabase/functions/atelier-employes`.

## Paie, avances et autres départements (v4)
- Chaque ouvrier a un **département** (Broderie, Couture, Coupe, Repassage, Finition, Emballage… ou libre) et un **mode de paie** :
  **Points** (broderie, compteur), **Au mois** (salaire fixe, bouton « Salaire du mois »), **À la pièce** (quantité × prix).
- **Mouvements d'argent** : avance, paiement, salaire, prime, retenue.
- **Reste à payer = gains (broderie + pièces + salaires + primes) − (avances + paiements + retenues)**.
  Un solde négatif signale une avance non encore couverte par le travail.
- **Fiche ouvrier** : solde global, boutons Avance / Payer / Salaire / Pièces / Prime / Retenue, bilan de la période avec solde reporté, journal complet, fiche de paie PDF.
- Base : tables `broderie_pieces`, `broderie_mouvements`, vue `broderie_soldes`, fonction `broderie_bilan()` (voir `supabase/v4_paie_avances.sql`).

## Principe de calcul (v3)
On relève le **compteur de points** de la machine (ex. machine 15 têtes) à la fin de chaque équipe
(**jour 8 h–20 h** ou **nuit 20 h–8 h**). Le montant dépend du **type de broderie** :
`montant = points du compteur × tarif du type / 1000`.
Par défaut : **passé plat 10 DA / 1000 pts** (300 000 pts = 3 000 DA), **cordon 15 DA / 1000 pts** (300 000 pts = 4 500 DA).
Les tarifs se modifient dans Réglages ; un changement de tarif ne modifie pas les relevés déjà enregistrés.

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
