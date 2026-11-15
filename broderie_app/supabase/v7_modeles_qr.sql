-- v7 : modèles (variantes couleur × taille) et QR personnalisé sur les documents
alter table public.stock_produits add column if not exists modele text;
create index if not exists stock_produits_modele_idx on public.stock_produits (atelier_id, modele);

alter table public.ateliers add column if not exists qr_lien text;
alter table public.ateliers add column if not exists qr_libelle text;

create or replace view public.stock_etat with (security_invoker = true) as
select p.id, p.atelier_id, p.reference, p.designation, p.categorie, p.taille, p.couleur, p.prix_gros, p.prix_detail,
  p.cout_revient, p.seuil_alerte, p.photo_path, p.actif, p.created_at,
  coalesce((select sum(m.quantite) from public.stock_mouvements m where m.produit_id = p.id), 0)::integer as stock,
  coalesce((select sum(l.quantite) from public.stock_vente_lignes l join public.stock_ventes v on v.id = l.vente_id
            where l.produit_id = p.id and v.statut = 'validee'), 0)::integer as vendus,
  coalesce((select sum(cl.quantite) from public.stock_commande_lignes cl join public.stock_commandes c on c.id = cl.commande_id
            where cl.produit_id = p.id and c.type = 'commande' and c.statut in ('en_cours','prete')), 0)::integer as reserve,
  coalesce((select sum(n.quantite * coalesce(mc.cout_moyen, 0)) from public.stock_nomenclature n
            left join lateral (select sum(al.montant) / nullif(sum(al.quantite), 0) as cout_moyen
                               from public.stock_achat_lignes al where al.matiere_id = n.matiere_id) mc on true
            where n.produit_id = p.id), 0)::numeric(14,2) as cout_matieres,
  p.modele
from public.stock_produits p;
