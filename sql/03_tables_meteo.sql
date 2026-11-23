-- =====================================================================
-- 03 — Les deux tables qui vont accueillir les donnees externes
--      (elles sont creees vides ; c'est Python qui les remplit)
-- =====================================================================
DROP TABLE IF EXISTS meteo_assurrisk CASCADE;

CREATE TABLE meteo_assurrisk (
    time                DATE,
    weather_code        INT,
    temperature_2m_max  NUMERIC,
    temperature_2m_min  NUMERIC,
    precipitation_sum   NUMERIC,
    wind_gusts_10m_max  NUMERIC,
    latitude            NUMERIC(12,7),
    longitude           NUMERIC(12,7)
);

DROP TABLE IF EXISTS villes_coordonnees_meteo CASCADE;

CREATE TABLE villes_coordonnees_meteo (
    ville       TEXT,
    latitude    NUMERIC(12,7),
    longitude   NUMERIC(12,7)
);
