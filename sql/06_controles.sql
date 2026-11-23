-- =====================================================================
-- 06 — Controles finaux (une seule ligne de resultat)
-- =====================================================================
SELECT
    (SELECT count(*) FROM clean_fact_sinistre)                                   AS sinistres_propres,
    (SELECT count(*) FROM meteo_assurrisk_ville)                                 AS lignes_meteo,
    (SELECT count(DISTINCT ville) FROM meteo_assurrisk_ville)                    AS villes_meteo,
    (SELECT count(*) FROM fact_sinistre_meteo)                                   AS lignes_finales,
    (SELECT count(*) FROM fact_sinistre_meteo WHERE weather_code IS NULL)        AS sans_meteo,
    (SELECT count(*) FROM (SELECT ville, time FROM meteo_assurrisk_ville
                           GROUP BY 1,2 HAVING count(*) > 1) z)                  AS meteo_en_double;
