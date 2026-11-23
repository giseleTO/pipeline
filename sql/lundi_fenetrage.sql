-- =========================
-- QUESTION 1
-- =========================
--Afficher, pour chaque région, les trois sinistres dont le montant estimé est le
--plus élevé.
--region_sinistre | rang | sinistre_id | type_sinistre | montant_estime



select count(distinct fsm.region_sinistre)
from fact_sinistre_meteo fsm;

select fsm.region_sinistre, fsm.montant_estime, fsm.type_sinistre, row_number() over (partition by region_sinistre order by montant_estime DESC) as rang
from fact_sinistre_meteo fsm 
group by fsm.region_sinistre, fsm.montant_estime, type_sinistre;


--36 lignes 

--Modifiez votre requête pour afficher les cinq sinistres les plus chers de chaque
--région au lieu de trois.

WITH fsm.region_sinistre, fsm.montant_estime, fsm.type_sinistre,fsm.sinistre_id, row_number() over (partition by region_sinistre order by montant_estime DESC) as rang
from fact_sinistre_meteo fsm 
select region_sinistre, rang, sinistre_id, type_sinistre, montant_estime
from rang_sinistre
where rang<=5;


-- =========================
-- QUESTION 2
-- =========================
--Afficher chaque sinistre avec, à côté, la moyenne des montants de son type, et
--l’écart entre son montant et cette moyenne.
--sinistre_id | type_sinistre | montant_estime | moyenne_du_type | ecart

select fsm.sinistre_id, fsm.type_sinistre, fsm.montant_estime, round(avg(fsm.montant_estime) over (partition by type_sinistre),0) as moyenne_du_type,
round(montant_estime - avg(fsm.montant_estime) over (partition by type_sinistre),0) 	as ecart
from fact_sinistre_meteo fsm
order by sinistre_id;

--Ajoutez une sixième colonne qui affiche le mot au-dessus quand le montant
--dépasse la moyenne de son type, et en-dessous sinon.

with ecart_moyenne as (
select fsm.sinistre_id, fsm.type_sinistre, fsm.montant_estime, round(avg(fsm.montant_estime) over (partition by type_sinistre),0) as moyenne_du_type,
round(montant_estime - avg(fsm.montant_estime) over (partition by type_sinistre),0) 	as ecart
from fact_sinistre_meteo fsm
order by sinistre_id)

select  sinistre_id, type_sinistre, montant_estime, round(avg(montant_estime) over (partition by type_sinistre),0) as moyenne_du_type,
round(montant_estime - avg(montant_estime) over (partition by type_sinistre),0) 	as ecart,
case
	when montant_estime< round(avg(montant_estime) over (partition by type_sinistre),0) then 'en_dessous'
	else 'au_dessus' 
end
from ecart_moyenne; 

-- =========================
-- QUESTION 3
-- =========================

--Afficher, pour chaque région, le nombre de sinistres et le pourcentage que ce
--nombre représente dans le total des 12 098 sinistres.
--region_sinistre | nb | pct


select fsm.region_sinistre, count(*) as nb, round(100*count(*)/sum(count (*)) over (),1) as pct
from fact_sinistre_meteo fsm
group by fsm.region_sinistre;


--Ajoutez une quatrième colonne qui affiche le pourcentage cumulé : la région la
--plus sinistrée affiche son propre pourcentage, la deuxième affiche la somme des
--deux premiers, et ainsi de suite.

with pct_sinistre as (select fsm.region_sinistre, count(*) as nb, round(100*count(*)/sum(count (*)) over (),1) as pct
from fact_sinistre_meteo fsm
group by fsm.region_sinistre)


with pct_sinistre as (select fsm.region_sinistre, count(*) as nb, 100*count(*)/sum(count (*)) over () as pct
from fact_sinistre_meteo fsm
group by fsm.region_sinistre)
select region_sinistre, nb, pct, sum(pct ) over (order by pct desc)
from pct_sinistre;


-- =========================
-- QUESTION 4
-- =========================

--Afficher, pour chaque ville, le type de sinistre qu’on y rencontre le plus
--souvent, et combien de fois on le rencontre.
--ville_sinistre | type_sinistre | nb

select fsm.ville_sinistre, fsm.type_sinistre,count(*) as nb, row_number() over (partition by ville_sinistre order by count(*))
from fact_sinistre_meteo fsm
group by ville_sinistre, type_sinistre;

with rang_sinistre as (select fsm.ville_sinistre, fsm.type_sinistre,count(*) as nb, row_number() over (partition by ville_sinistre order by count(*)) as rang
from fact_sinistre_meteo fsm
group by ville_sinistre, type_sinistre
)
select ville_sinistre, type_sinistre, nb
from rang_sinistre
where rang=1;

-- on constate que les incendie sont en tête des sinistre dans presque toutes les régions


--Affichez le nombre de sinistres par mois, du premier au dernier mois de la table.
--Deux colonnes : le mois au format 2025-10 , et le nombre. Trié du plus grand
-- nombre au plus petit.

select to_char(fsm.date_survenance, 'YYYY-MM'), count(*) as nb
from fact_sinistre_meteo fsm 
group by to_char(fsm.date_survenance, 'YYYY-MM')
order by to_char(fsm.date_survenance, 'YYYY-MM') desc;
--les snistre le plus cher dans toutes les regions sont les incendie
--Dans les 30 villes, le type de sinistre le plus fréquent est systématiquement le même (Dégât des eaux).




