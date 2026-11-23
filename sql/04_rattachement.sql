-- ============================================================
-- AssurRisk - Rattachement des données météo aux villes
-- Objectif :
-- Associer chaque couple latitude/longitude retourné par Open-Meteo
-- à la ville de référence la plus proche.
-- ============================================================

DROP TABLE IF EXISTS meteo_assurrisk_ville;

CREATE TABLE meteo_assurrisk_ville AS

WITH points_meteo AS (
    SELECT DISTINCT
        latitude,
        longitude
    FROM meteo_assurrisk
),

distances AS (
    SELECT
        m.latitude,
        m.longitude,
        v.ville,

        POWER(m.latitude - v.latitude, 2)
        + POWER(m.longitude - v.longitude, 2) AS distance,

        ROW_NUMBER() OVER (
            PARTITION BY m.latitude, m.longitude
            ORDER BY
                POWER(m.latitude - v.latitude, 2)
                + POWER(m.longitude - v.longitude, 2)
        ) AS rang

    FROM points_meteo AS m
    CROSS JOIN villes_coordonnees_meteo AS v

    WHERE v.latitude IS NOT NULL
      AND v.longitude IS NOT NULL
),

correspondance AS (
    SELECT
        latitude,
        longitude,
        ville
    FROM distances
    WHERE rang = 1
)

SELECT
    m.time,
    m.weather_code,
    m.temperature_2m_max,
    m.temperature_2m_min,
    m.precipitation_sum,
    m.wind_gusts_10m_max,
    m.latitude,
    m.longitude,
    c.ville
FROM meteo_assurrisk AS m
JOIN correspondance AS c
    ON m.latitude = c.latitude
   AND m.longitude = c.longitude;

-- ============================================================
-- Contrôles
-- ============================================================

-- 1. Nombre de lignes attendu : 21 930
SELECT COUNT(*) AS nombre_lignes
FROM meteo_assurrisk_ville;

-- 2. Nombre de villes attendu : 30
SELECT COUNT(DISTINCT ville) AS nombre_villes
FROM meteo_assurrisk_ville;

-- 3. Vérifier les correspondances coordonnées météo -> ville
SELECT DISTINCT
    ville,
    latitude,
    longitude
FROM meteo_assurrisk_ville
ORDER BY ville;
