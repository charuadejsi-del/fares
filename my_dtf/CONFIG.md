# Configuration d'une installation My DTF

Chaque atelier a sa propre installation (son projet Supabase, ses sites, ses applications).
Aucune valeur n'est à modifier dans le code : tout passe par les réglages ci-dessous.
Sans réglage, les valeurs de l'atelier d'origine sont utilisées.

## Sites web (admin `my_dtf_admin_v2`, client `my_dtf_client_web`)

Fichier `.env` (ou variables d'environnement au moment du build) :

| Variable | Rôle |
|---|---|
| `VITE_SUPABASE_URL` | Adresse du projet Supabase |
| `VITE_SUPABASE_ANON_KEY` | Clé publique « anon » du projet |
| `VITE_APP_NAME` | Nom affiché (titre, en-tête) |
| `VITE_ADMIN_URL` | Adresse du site d'administration |
| `VITE_CLIENT_URL` | Adresse du site client |

Lu par `src/config.js`.

## Applications Android (`my_dtf_android`)

Propriétés Gradle `-Pmydtf.<clé>=…` ou variables d'environnement `MYDTF_<CLÉ>` :

| Clé | Rôle |
|---|---|
| `supabaseUrl` | Adresse du projet Supabase |
| `anonKey` | Clé publique « anon » |
| `appName` | Nom des applications (« X », « X Pro », « X Admin ») |
| `appId` | Préfixe d'identifiant Android (`<appId>.client`, `.pro`, `.admin`) |
| `adminUrl` | Adresse du site d'administration |

Signature : secrets `MYDTF_KEYSTORE`, `MYDTF_KEYSTORE_PASSWORD`… — une clé propre à chaque atelier.

## Application Windows (`my_dtf_admin_desktop`)

`package.json` → `"mydtf": { "adminUrl": "https://…/" }`, plus `productName` et `build.appId`.

## Base de données et fonctions serveur (`my_dtf/supabase`)

1. Exécuter les migrations dans l'ordre (`schema.sql`, puis `00x_*.sql`).
2. Renseigner l'adresse des fonctions :
   `update dtf_ship_config set functions_url = 'https://<projet>.supabase.co/functions/v1' where id = 1;`
3. Déployer les fonctions `dtf-admin` et `dtf-dhd`.
4. Secrets des fonctions (Supabase → Edge Functions → Secrets) :
   `EXPEDIA_TOKEN`, `DHD_TOKEN` (clés des sociétés de livraison, une par société utilisée).
5. Dans le site admin → الإعدادات → التوصيل : choisir la société par défaut puis « مزامنة ».
