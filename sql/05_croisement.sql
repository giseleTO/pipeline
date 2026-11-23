-- =====================================================================
-- 05 — Croisement sinistres x meteo  ->  fact_sinistre_meteo
-- =====================================================================
DROP TABLE IF EXISTS fact_sinistre_meteo;

CREATE TABLE fact_sinistre_meteo AS
SELECT
    s.sinistre_id,
    s.contrat_id,
    s.agence_id,
    s.garantie_id,
    s.date_survenance,
    s.date_declaration,
    s.type_sinistre,
    s.statut_sinistre,
    s.montant_estime,
    s.franchise,
    s.ville_sinistre,
    s.departement_sinistre,
    s.region_sinistre,
    m.weather_code,
    m.temperature_2m_max,
    m.temperature_2m_min,
    m.precipitation_sum,
    m.wind_gusts_10m_max
FROM clean_fact_sinistre AS s
LEFT JOIN meteo_assurrisk_ville AS m
       ON m.ville = s.ville_sinistre
      AND m.time  = s.date_survenance;
