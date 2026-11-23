-- =============================================================================
-- AssurRisk — Base de données pédagogique — VERSION DÉTERMINISTE v4
-- Fichier  : assurrisk_init_2024_2025.sql
-- Période  : 01/01/2024 → 31/12/2025
-- SGBD     : PostgreSQL 15+
-- Exécution: DBeaver ou psql
--
-- REPRODUCTIBILITÉ GARANTIE
--   Aucun appel à random(). Toutes les valeurs sont dérivées de :
--     • generate_series(i)
--     • i % N                         (distribution cyclique)
--     • abs(hashtext(i::text)) % N    (dispersion pseudo-stable)
--     • calculs arithmétiques sur i
--   Le résultat est identique sur toutes les machines PostgreSQL 15+.
--
-- CHANGEMENTS v4 (par rapport à v3)
--   1. Coordonnées GPS : source de vérité = CSV villes_coordonnees_meteo.csv
--      • dim_agence        : 5 agences corrigées (Rennes, Amiens, Tours, Metz, Rouen)
--      • fact_sinistre     : CTE villes + villes_inondation alignées sur le CSV
--      • Anomalies B/C/E/F : coordonnées remplacées par valeurs exactes du CSV
--      • Suppression du JITTER (± x/100) dans TOUTES les colonnes latitude/longitude
--        → une ville = exactement une paire (lat, lon), en accord avec Open-Meteo
--   2. Anomalie F isolée : bloc explicitement délimité avec avertissement
--      pour éviter l'exécution accidentelle par les apprenants en cours de projet
--   3. Contrôles enrichis : cohérence coordonnées dim_agence vs fact_sinistre,
--      unicité des coordonnées par ville, absence de NULL hors anomalie D
--
-- VOLUMES CIBLES (inchangés par rapport à v3)
--   dim_assure        : 25 040  (25 000 + 40 doublons métier)
--   dim_agence        :     25
--   dim_garantie      :     12
--   dim_contrat       : 32 000
--   contrat_garantie  : ~89 600 (Ess×2, Confort×3, Premium×4 — RC comprise)
--   fact_sinistre     : ~12 490
--   fact_indemnisation: ~13 800–15 000
--
-- ANOMALIES INJECTÉES (toutes dénombrables, inchangées par rapport à v3)
--   A. 100 doublons de lignes sinistres (copie exacte)
--   B.  80 sinistres : date_declaration < date_survenance
--   C. 100 sinistres sur contrats non actifs
--   D.  60 sinistres : localisation NULL / vide / 'inconnu'
--   E.  50 sinistres : montant_estime anormal (15 négatifs / 10 nuls / 10 quasi-nuls / 15 extrêmes)
--   F. 100 sinistres : type_sinistre non normalisé (12 formes)
--   G.  50 indemnisations payées sur sinistres refusés
--   H.  20 paiements antérieurs à la déclaration
--   I.  20 indemnisations : montant_indemnise anormal
-- =============================================================================


-- =============================================================================
-- 1. NETTOYAGE
-- =============================================================================

DROP TABLE IF EXISTS fact_indemnisation  CASCADE;
DROP TABLE IF EXISTS fact_sinistre       CASCADE;
DROP TABLE IF EXISTS contrat_garantie    CASCADE;
DROP TABLE IF EXISTS dim_contrat         CASCADE;
DROP TABLE IF EXISTS dim_garantie        CASCADE;
DROP TABLE IF EXISTS dim_assure          CASCADE;
DROP TABLE IF EXISTS dim_agence          CASCADE;


-- =============================================================================
-- 2. CRÉATION DES TABLES
-- =============================================================================

CREATE TABLE dim_agence (
    agence_id       SERIAL PRIMARY KEY,
    nom_agence      VARCHAR(100) NOT NULL,
    ville           VARCHAR(100) NOT NULL,
    departement     VARCHAR(10)  NOT NULL,
    region          VARCHAR(100) NOT NULL,
    latitude        NUMERIC(9,6) NOT NULL,
    longitude       NUMERIC(9,6) NOT NULL,
    date_ouverture  DATE         NOT NULL,
    statut_agence   VARCHAR(20)  NOT NULL CHECK (statut_agence IN ('active','fermée'))
);

CREATE TABLE dim_assure (
    assure_id       SERIAL PRIMARY KEY,
    nom             VARCHAR(100) NOT NULL,
    prenom          VARCHAR(100) NOT NULL,
    email           VARCHAR(200),
    date_naissance  DATE,
    sexe            VARCHAR(20),
    ville           VARCHAR(100) NOT NULL,
    departement     VARCHAR(10)  NOT NULL,
    region          VARCHAR(100) NOT NULL,
    date_entree     DATE         NOT NULL,
    statut_assure   VARCHAR(20)  NOT NULL CHECK (statut_assure IN ('actif','inactif','résilié'))
);

CREATE TABLE dim_garantie (
    garantie_id             SERIAL PRIMARY KEY,
    nom_garantie            VARCHAR(100)  NOT NULL,
    categorie               VARCHAR(100)  NOT NULL,
    plafond_indemnisation   NUMERIC(12,2) NOT NULL,
    franchise_standard      NUMERIC(10,2) NOT NULL,
    statut_garantie         VARCHAR(20)   NOT NULL CHECK (statut_garantie IN ('active','inactive'))
);

CREATE TABLE dim_contrat (
    contrat_id      SERIAL PRIMARY KEY,
    assure_id       INT           NOT NULL REFERENCES dim_assure(assure_id),
    agence_id       INT           NOT NULL REFERENCES dim_agence(agence_id),
    date_debut      DATE          NOT NULL,
    date_fin        DATE,
    formule         VARCHAR(20)   NOT NULL CHECK (formule IN ('Essentielle','Confort','Premium')),
    type_logement   VARCHAR(20)   NOT NULL CHECK (type_logement IN ('Appartement','Maison')),
    prime_annuelle  NUMERIC(10,2) NOT NULL,
    statut_contrat  VARCHAR(20)   NOT NULL CHECK (statut_contrat IN ('actif','résilié','expiré'))
);

CREATE TABLE contrat_garantie (
    contrat_id              INT  NOT NULL REFERENCES dim_contrat(contrat_id),
    garantie_id             INT  NOT NULL REFERENCES dim_garantie(garantie_id),
    date_debut_couverture   DATE NOT NULL,
    date_fin_couverture     DATE,
    PRIMARY KEY (contrat_id, garantie_id)
);

CREATE TABLE fact_sinistre (
    sinistre_id          SERIAL PRIMARY KEY,
    contrat_id           INT           NOT NULL REFERENCES dim_contrat(contrat_id),
    agence_id            INT           NOT NULL REFERENCES dim_agence(agence_id),
    garantie_id          INT           NOT NULL REFERENCES dim_garantie(garantie_id),
    date_survenance      DATE          NOT NULL,
    date_declaration     DATE          NOT NULL,
    type_sinistre        VARCHAR(100)  NOT NULL,
    cause_sinistre       TEXT,
    statut_sinistre      VARCHAR(20)   NOT NULL,
    montant_estime       NUMERIC(12,2),
    franchise            NUMERIC(10,2),
    ville_sinistre       VARCHAR(100),
    departement_sinistre VARCHAR(10),
    region_sinistre      VARCHAR(100),
    latitude             NUMERIC(9,6),
    longitude            NUMERIC(9,6)
);

CREATE TABLE fact_indemnisation (
    indemnisation_id    SERIAL PRIMARY KEY,
    sinistre_id         INT           NOT NULL REFERENCES fact_sinistre(sinistre_id),
    date_paiement       DATE          NOT NULL,
    montant_indemnise   NUMERIC(12,2) NOT NULL,
    statut_paiement     VARCHAR(20)   NOT NULL CHECK (statut_paiement IN ('prévu','payé','annulé')),
    mode_paiement       VARCHAR(20)   NOT NULL CHECK (mode_paiement IN ('virement','chèque'))
);


-- =============================================================================
-- 3. DONNÉES DE RÉFÉRENCE — GARANTIES (12)
-- =============================================================================

INSERT INTO dim_garantie
    (garantie_id, nom_garantie, categorie, plafond_indemnisation, franchise_standard, statut_garantie)
OVERRIDING SYSTEM VALUE
VALUES
  ( 1, 'Dégât des eaux',       'Dommages matériels',   80000.00,   300.00, 'active'),
  ( 2, 'Incendie',              'Dommages matériels',  200000.00,   500.00, 'active'),
  ( 3, 'Vol et cambriolage',    'Vol',                  30000.00,   150.00, 'active'),
  ( 4, 'Bris de glace',         'Dommages matériels',    5000.00,    80.00, 'active'),
  ( 5, 'Tempête',               'Événements naturels',  60000.00,   300.00, 'active'),
  ( 6, 'Grêle',                 'Événements naturels',  25000.00,   200.00, 'active'),
  ( 7, 'Inondation',            'Événements naturels', 100000.00,   500.00, 'active'),
  ( 8, 'Responsabilité civile', 'Responsabilité',      500000.00,     0.00, 'active'),
  ( 9, 'Dommages électriques',  'Dommages matériels',   10000.00,   150.00, 'active'),
  (10, 'Catastrophe naturelle', 'Événements naturels', 150000.00,   380.00, 'active'),
  (11, 'Vandalisme',            'Vol',                   8000.00,   200.00, 'active'),
  (12, 'Protection juridique',  'Services',             15000.00,     0.00, 'active');

SELECT setval('dim_garantie_garantie_id_seq', 12);


-- =============================================================================
-- 4. AGENCES (25)
--
-- SOURCE DE VÉRITÉ COORDONNÉES : villes_coordonnees_meteo.csv
-- Toutes les agences dont la ville figure dans le CSV utilisent exactement
-- les coordonnées du CSV. Villeurbanne (agence 4) n'est pas dans le CSV :
-- ses coordonnées propres sont conservées.
--
-- CORRECTIONS v4 par rapport à v3 :
--   Agence 11 Rennes        : 48.114600 / -1.679400  →  48.117300 / -1.677800
--   Agence 16 Amiens        : 49.895200 /  2.302100  →  49.894100 /  2.295800
--   Agence 21 Tours         : 47.394100 /  0.688500  →  47.394100 /  0.684800
--   Agence 22 Rouen         : 49.443200 /  1.099700  →  49.443100 /  1.099300
--   Agence 25 Metz (fermée) : 49.119700 /  6.176700  →  49.119300 /  6.175700
-- =============================================================================

INSERT INTO dim_agence
    (agence_id, nom_agence, ville, departement, region, latitude, longitude, date_ouverture, statut_agence)
OVERRIDING SYSTEM VALUE
VALUES
  ( 1,'AssurRisk Paris 1er',        'Paris',           '75','Île-de-France',               48.856600,  2.352200,'2010-03-01','active'),
  ( 2,'AssurRisk Paris 15e',        'Paris',           '75','Île-de-France',               48.842000,  2.296300,'2012-06-15','active'),
  ( 3,'AssurRisk Lyon Centre',      'Lyon',            '69','Auvergne-Rhône-Alpes',        45.764000,  4.835700,'2011-09-01','active'),
  ( 4,'AssurRisk Lyon Nord',        'Villeurbanne',    '69','Auvergne-Rhône-Alpes',        45.771900,  4.886700,'2015-01-10','active'),
  ( 5,'AssurRisk Marseille',        'Marseille',       '13','Provence-Alpes-Côte d''Azur', 43.296500,  5.369800,'2009-05-20','active'),
  ( 6,'AssurRisk Aix-en-Provence',  'Aix-en-Provence','13','Provence-Alpes-Côte d''Azur', 43.529700,  5.447400,'2016-11-01','active'),
  ( 7,'AssurRisk Bordeaux',         'Bordeaux',        '33','Nouvelle-Aquitaine',          44.837800, -0.579200,'2013-04-01','active'),
  ( 8,'AssurRisk Toulouse',         'Toulouse',        '31','Occitanie',                   43.604700,  1.444200,'2012-08-15','active'),
  ( 9,'AssurRisk Montpellier',      'Montpellier',     '34','Occitanie',                   43.610800,  3.876700,'2014-02-01','active'),
  (10,'AssurRisk Nantes',           'Nantes',          '44','Pays de la Loire',            47.218400, -1.553600,'2011-07-01','active'),
  (11,'AssurRisk Rennes',           'Rennes',          '35','Bretagne',                    48.117300, -1.677800,'2015-09-01','active'),
  (12,'AssurRisk Brest',            'Brest',           '29','Bretagne',                    48.390400, -4.486100,'2017-03-01','active'),
  (13,'AssurRisk Strasbourg',       'Strasbourg',      '67','Grand Est',                   48.573400,  7.752100,'2013-10-01','active'),
  (14,'AssurRisk Nancy',            'Nancy',           '54','Grand Est',                   48.692100,  6.184400,'2018-01-15','active'),
  (15,'AssurRisk Lille',            'Lille',           '59','Hauts-de-France',             50.629200,  3.057300,'2010-11-01','active'),
  (16,'AssurRisk Amiens',           'Amiens',          '80','Hauts-de-France',             49.894100,  2.295800,'2019-06-01','active'),
  (17,'AssurRisk Nice',             'Nice',            '06','Provence-Alpes-Côte d''Azur', 43.710200,  7.262000,'2014-05-01','active'),
  (18,'AssurRisk Grenoble',         'Grenoble',        '38','Auvergne-Rhône-Alpes',        45.188500,  5.724500,'2016-03-01','active'),
  (19,'AssurRisk Clermont-Ferrand', 'Clermont-Ferrand','63','Auvergne-Rhône-Alpes',        45.777200,  3.087000,'2015-07-01','active'),
  (20,'AssurRisk Dijon',            'Dijon',           '21','Bourgogne-Franche-Comté',     47.322000,  5.041500,'2017-09-01','active'),
  (21,'AssurRisk Tours',            'Tours',           '37','Centre-Val de Loire',         47.394100,  0.684800,'2016-06-01','active'),
  (22,'AssurRisk Rouen',            'Rouen',           '76','Normandie',                   49.443100,  1.099300,'2018-04-01','active'),
  (23,'AssurRisk Caen',             'Caen',            '14','Normandie',                   49.182900, -0.370700,'2019-10-01','active'),
  (24,'AssurRisk Toulon',           'Toulon',          '83','Provence-Alpes-Côte d''Azur', 43.124200,  5.928000,'2017-01-01','active'),
  (25,'AssurRisk Metz',             'Metz',            '57','Grand Est',                   49.119300,  6.175700,'2020-02-01','fermée');

SELECT setval('dim_agence_agence_id_seq', 25);


-- =============================================================================
-- 5. ASSURÉS (25 000 + 40 doublons métier = 25 040)
-- (section identique à v3 — aucune modification)
--
-- RÈGLE DOUBLON MÉTIER : deux assurés sont doublons si et seulement si
--   nom + prenom + date_naissance + email sont IDENTIQUES
--   et assure_id différent.
-- =============================================================================

INSERT INTO dim_assure
    (nom, prenom, email, date_naissance, sexe,
     ville, departement, region, date_entree, statut_assure)
WITH
noms(rk, n) AS (
  VALUES
   (0,'Martin'),(1,'Bernard'),(2,'Dubois'),(3,'Thomas'),(4,'Robert'),
   (5,'Richard'),(6,'Petit'),(7,'Durand'),(8,'Leroy'),(9,'Moreau'),
   (10,'Simon'),(11,'Laurent'),(12,'Lefebvre'),(13,'Michel'),(14,'Garcia'),
   (15,'David'),(16,'Bertrand'),(17,'Roux'),(18,'Vincent'),(19,'Fournier'),
   (20,'Morel'),(21,'Girard'),(22,'André'),(23,'Mercier'),(24,'Dupont'),
   (25,'Lambert'),(26,'Bonnet'),(27,'François'),(28,'Martinez'),(29,'Legrand'),
   (30,'Garnier'),(31,'Faure'),(32,'Rousseau'),(33,'Blanc'),(34,'Guerin'),
   (35,'Muller'),(36,'Henry'),(37,'Roussel'),(38,'Nicolas'),(39,'Perrin'),
   (40,'Morin'),(41,'Mathieu'),(42,'Clement'),(43,'Gauthier'),(44,'Dumont'),
   (45,'Lopez'),(46,'Fontaine'),(47,'Chevalier'),(48,'Robin'),(49,'Masson'),
   (50,'Sanchez'),(51,'Gerard'),(52,'Nguyen'),(53,'Boyer'),(54,'Denis'),
   (55,'Lemaire'),(56,'Duval'),(57,'Joly'),(58,'Riviere'),(59,'Lucas'),
   (60,'Courtois'),(61,'Lacroix'),(62,'Noel'),(63,'Picard'),(64,'Colin'),
   (65,'Barbe'),(66,'Bourgeois'),(67,'Leclercq'),(68,'Gautier'),(69,'Renard'),
   (70,'Grondin'),(71,'Schmitt'),(72,'Baron'),(73,'Hubert'),(74,'Jacquet'),
   (75,'Renaud'),(76,'Gilles'),(77,'Perrier'),(78,'Vidal'),(79,'Aubert')
),
prenoms_m(rk, p) AS (
  VALUES
   (0,'Alexandre'),(1,'Antoine'),(2,'Baptiste'),(3,'Benjamin'),(4,'Charles'),
   (5,'Christophe'),(6,'Clément'),(7,'Damien'),(8,'David'),(9,'Emmanuel'),
   (10,'Etienne'),(11,'Fabrice'),(12,'François'),(13,'Frédéric'),(14,'Guillaume'),
   (15,'Hugo'),(16,'Jacques'),(17,'Jean'),(18,'Jonathan'),(19,'Julien'),
   (20,'Kevin'),(21,'Laurent'),(22,'Luc'),(23,'Lucas'),(24,'Mathieu'),
   (25,'Maxime'),(26,'Michel'),(27,'Nicolas'),(28,'Olivier'),(29,'Patrick'),
   (30,'Paul'),(31,'Philippe'),(32,'Pierre'),(33,'Raphaël'),(34,'Romain'),
   (35,'Samuel'),(36,'Sébastien'),(37,'Simon'),(38,'Stéphane'),(39,'Thomas'),
   (40,'Thibault'),(41,'Victor'),(42,'Vincent'),(43,'Xavier'),(44,'Yann'),
   (45,'Yoann'),(46,'Mohamed'),(47,'Karim'),(48,'Samir')
),
prenoms_f(rk, p) AS (
  VALUES
   (0,'Alice'),(1,'Amélie'),(2,'Anaïs'),(3,'Aurélie'),(4,'Camille'),
   (5,'Charlotte'),(6,'Chloé'),(7,'Clara'),(8,'Clémence'),(9,'Elise'),
   (10,'Emma'),(11,'Eva'),(12,'Inès'),(13,'Jade'),(14,'Julie'),
   (15,'Juliette'),(16,'Laura'),(17,'Laure'),(18,'Laurie'),(19,'Léa'),
   (20,'Louise'),(21,'Lucie'),(22,'Manon'),(23,'Marie'),(24,'Marion'),
   (25,'Mathilde'),(26,'Mélanie'),(27,'Nathalie'),(28,'Noémie'),(29,'Océane'),
   (30,'Pauline'),(31,'Sarah'),(32,'Séverine'),(33,'Sofia'),(34,'Sophie'),
   (35,'Stéphanie'),(36,'Valentine'),(37,'Valérie'),(38,'Victoria'),(39,'Yasmine'),
   (40,'Fatima'),(41,'Amina'),(42,'Hana'),(43,'Céline'),(44,'Isabelle'),
   (45,'Christine'),(46,'Martine'),(47,'Sylvie'),(48,'Sandrine'),(49,'Brigitte')
),
villes(rk, ville, dep, reg) AS (
  VALUES
   ( 0,'Paris',           '75','Île-de-France'),
   ( 1,'Lyon',            '69','Auvergne-Rhône-Alpes'),
   ( 2,'Marseille',       '13','Provence-Alpes-Côte d''Azur'),
   ( 3,'Toulouse',        '31','Occitanie'),
   ( 4,'Bordeaux',        '33','Nouvelle-Aquitaine'),
   ( 5,'Nantes',          '44','Pays de la Loire'),
   ( 6,'Strasbourg',      '67','Grand Est'),
   ( 7,'Lille',           '59','Hauts-de-France'),
   ( 8,'Rennes',          '35','Bretagne'),
   ( 9,'Montpellier',     '34','Occitanie'),
   (10,'Nice',            '06','Provence-Alpes-Côte d''Azur'),
   (11,'Grenoble',        '38','Auvergne-Rhône-Alpes'),
   (12,'Toulon',          '83','Provence-Alpes-Côte d''Azur'),
   (13,'Dijon',           '21','Bourgogne-Franche-Comté'),
   (14,'Angers',          '49','Pays de la Loire'),
   (15,'Nîmes',           '30','Occitanie'),
   (16,'Aix-en-Provence', '13','Provence-Alpes-Côte d''Azur'),
   (17,'Clermont-Ferrand','63','Auvergne-Rhône-Alpes'),
   (18,'Le Havre',        '76','Normandie'),
   (19,'Reims',           '51','Grand Est'),
   (20,'Rouen',           '76','Normandie'),
   (21,'Caen',            '14','Normandie'),
   (22,'Nancy',           '54','Grand Est'),
   (23,'Metz',            '57','Grand Est'),
   (24,'Tours',           '37','Centre-Val de Loire'),
   (25,'Brest',           '29','Bretagne'),
   (26,'Amiens',          '80','Hauts-de-France'),
   (27,'Limoges',         '87','Nouvelle-Aquitaine'),
   (28,'Perpignan',       '66','Occitanie'),
   (29,'Besançon',        '25','Bourgogne-Franche-Comté')
),
serie AS (SELECT generate_series(1, 25000) AS i),
h AS (
    SELECT i,
           abs(hashtext(i::text))              AS h1,
           abs(hashtext((i * 7 + 3)::text))   AS h2,
           abs(hashtext((i * 13 + 11)::text)) AS h3
    FROM serie
),
assure_raw AS (
    SELECT
        h.i,
        (SELECT n FROM noms WHERE rk = h.h1 % 80)        AS nom_v,
        CASE
            WHEN h.i % 100 < 52 THEN 'M'
            WHEN h.i % 100 < 98 THEN 'F'
            ELSE (ARRAY['Autre','NR','X','non renseigné'])[1 + (h.i % 4)]
        END AS sexe_v,
        (SELECT ville FROM villes WHERE rk = h.h2 % 30)  AS ville_v,
        (SELECT dep  FROM villes WHERE rk = h.h2 % 30)   AS dep_v,
        (SELECT reg  FROM villes WHERE rk = h.h2 % 30)   AS reg_v,
        CASE WHEN h.i % 50 = 0 THEN NULL
             ELSE DATE '1950-01-01' + ((h.h3 % 18250)::int)
        END AS ddn_v,
        DATE '2015-01-01' + ((h.h1 % 3287)::int) AS entree_v,
        CASE
            WHEN h.i % 25 = 0 THEN 'résilié'
            WHEN h.i % 5  = 4 THEN 'inactif'
            ELSE 'actif'
        END AS statut_v,
        h.h1,
        h.h2,
        h.h3
    FROM h
)
SELECT
    nom_v,
    CASE
        WHEN sexe_v = 'M'
            THEN (SELECT p FROM prenoms_m WHERE rk = (h1 % 49))
        ELSE
            (SELECT p FROM prenoms_f WHERE rk = (h2 % 50))
    END                               AS prenom,
    CASE
        WHEN i % 33 = 0 THEN NULL
        WHEN i % 50 = 1 THEN lower(nom_v) || (h3 % 999)::text || '@' ||
            (ARRAY['gmail.com','orange.fr','free.fr','sfr.fr','yahoo.fr','laposte.net'])[1 + (i % 6)]
        ELSE
            lower(nom_v) || '.' || (h1 % 9999)::text || '@' ||
            (ARRAY['gmail.com','orange.fr','free.fr','sfr.fr','yahoo.fr','laposte.net'])[1 + (i % 6)]
    END                               AS email,
    ddn_v                             AS date_naissance,
    sexe_v                            AS sexe,
    CASE WHEN i % 35 = 0 THEN upper(ville_v)
         ELSE ville_v END             AS ville,
    dep_v                             AS departement,
    CASE WHEN i % 35 = 0 THEN upper(reg_v)
         WHEN i % 40 = 0 THEN lower(reg_v)
         ELSE reg_v END               AS region,
    entree_v                          AS date_entree,
    statut_v                          AS statut_assure
FROM assure_raw;

-- ── Doublons métier : exactement 40 assurés copiés
INSERT INTO dim_assure
    (nom, prenom, email, date_naissance, sexe, ville, departement, region, date_entree, statut_assure)
SELECT nom, prenom, email, date_naissance, sexe, ville, departement, region,
       date_entree + INTERVAL '7 days',
       statut_assure
FROM (
    SELECT *
    FROM dim_assure
    WHERE date_naissance IS NOT NULL
      AND email IS NOT NULL
    ORDER BY assure_id
    LIMIT 40
) t;


-- =============================================================================
-- 6. CONTRATS (32 000)
-- (section identique à v3)
-- =============================================================================

INSERT INTO dim_contrat
    (assure_id, agence_id, date_debut, date_fin, formule, type_logement, prime_annuelle, statut_contrat)
WITH
serie AS (SELECT generate_series(1, 32000) AS i),
nb_assures AS (SELECT max(assure_id) AS mx FROM dim_assure),
h AS (
    SELECT i,
           abs(hashtext(i::text))            AS h1,
           abs(hashtext((i*11+7)::text))     AS h2
    FROM serie
),
formule_v AS (
    SELECT i,
           CASE WHEN i % 10 < 4 THEN 'Essentielle'
                WHEN i % 10 < 8 THEN 'Confort'
                ELSE 'Premium' END AS formule
    FROM serie
)
SELECT
    1 + (h.i % (SELECT mx FROM nb_assures))      AS assure_id,
    1 + (h.h1 % 24)                              AS agence_id,
    DATE '2018-01-01' + (h.h2 % 1977)::int       AS date_debut,
    CASE WHEN h.i % 100 < 72 THEN NULL
         ELSE DATE '2020-01-01' + (h.h1 % 1461)::int
    END                                           AS date_fin,
    f.formule,
    CASE WHEN h.i % 5 < 3 THEN 'Appartement' ELSE 'Maison' END AS type_logement,
    ROUND(
        CASE f.formule
            WHEN 'Essentielle' THEN 180 + (h.h2 % 120)
            WHEN 'Confort'     THEN 280 + (h.h2 % 180)
            ELSE                    450 + (h.h2 % 350)
        END
        * CASE WHEN h.i % 5 < 3 THEN 1.0 ELSE 1.2 END
    , 2)                                          AS prime_annuelle,
    CASE WHEN h.i % 100 < 72 THEN 'actif'
         WHEN h.i % 100 < 90 THEN 'résilié'
         ELSE 'expiré' END                        AS statut_contrat
FROM h
JOIN formule_v f USING (i);


-- =============================================================================
-- 7. ASSOCIATIONS CONTRAT-GARANTIE (~89 600 lignes)
-- (section identique à v3)
-- =============================================================================

INSERT INTO contrat_garantie (contrat_id, garantie_id, date_debut_couverture, date_fin_couverture)
SELECT
    c.contrat_id,
    g.garantie_id,
    c.date_debut  AS date_debut_couverture,
    NULL::date    AS date_fin_couverture
FROM dim_contrat c
JOIN (
    VALUES
        ('Essentielle', 1),
        ('Essentielle', 8),
        ('Confort',     1),
        ('Confort',     5),
        ('Confort',     8),
        ('Premium',     1),
        ('Premium',     2),
        ('Premium',     5),
        ('Premium',     8)
) AS g(formule, garantie_id) ON g.formule = c.formule
ON CONFLICT (contrat_id, garantie_id) DO NOTHING;


-- =============================================================================
-- 8. SINISTRES NORMAUX (12 000)
--
-- v4 — Coordonnées alignées sur le CSV villes_coordonnees_meteo.csv
--   SUPPRESSION du jitter (± x/100) sur latitude et longitude.
--   Une ville = exactement une paire (lat, lon), identique au référentiel Open-Meteo.
--
-- Distribution type (inchangée) :
--   Dégât des eaux  : buckets  0-29  (25%) → ~3 000
--   Incendie        : buckets 30-35  ( 5%) → ~  600
--   Inondation      : buckets 36-39  ( 3%) → ~  360
--   Vol             : buckets 40-55  (13%) → ~1 560
--   Bris de glace   : buckets 56-64  ( 8%) → ~  960
--   Tempête         : buckets 65-74  ( 8%) → ~  960
--   Grêle           : buckets 75-84  ( 8%) → ~  960
--   RC              : buckets 85-93  ( 8%) → ~  960
--   Autres          : buckets 94-119 (22%) → ~2 640
-- =============================================================================

INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
WITH
contrats_actifs AS (
    SELECT contrat_id, agence_id,
           row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat
    WHERE statut_contrat = 'actif'
),
nb_actifs AS (SELECT max(rn) AS mx FROM contrats_actifs),
-- ─── Référentiel des 30 villes — coordonnées exactes du CSV ───────────────
villes(rk, ville, dep, reg, lat, lon) AS (
  VALUES
   ( 0,'Paris',           '75','Île-de-France',               48.856600,  2.352200),
   ( 1,'Lyon',            '69','Auvergne-Rhône-Alpes',        45.764000,  4.835700),
   ( 2,'Marseille',       '13','Provence-Alpes-Côte d''Azur', 43.296500,  5.369800),
   ( 3,'Toulouse',        '31','Occitanie',                   43.604700,  1.444200),
   ( 4,'Bordeaux',        '33','Nouvelle-Aquitaine',          44.837800, -0.579200),
   ( 5,'Nantes',          '44','Pays de la Loire',            47.218400, -1.553600),
   ( 6,'Strasbourg',      '67','Grand Est',                   48.573400,  7.752100),
   ( 7,'Lille',           '59','Hauts-de-France',             50.629200,  3.057300),
   ( 8,'Rennes',          '35','Bretagne',                    48.117300, -1.677800),
   ( 9,'Montpellier',     '34','Occitanie',                   43.610800,  3.876700),
   (10,'Nice',            '06','Provence-Alpes-Côte d''Azur', 43.710200,  7.262000),
   (11,'Grenoble',        '38','Auvergne-Rhône-Alpes',        45.188500,  5.724500),
   (12,'Toulon',          '83','Provence-Alpes-Côte d''Azur', 43.124200,  5.928000),
   (13,'Dijon',           '21','Bourgogne-Franche-Comté',     47.322000,  5.041500),
   (14,'Angers',          '49','Pays de la Loire',            47.478400, -0.563200),
   (15,'Nîmes',           '30','Occitanie',                   43.836700,  4.360100),
   (16,'Aix-en-Provence', '13','Provence-Alpes-Côte d''Azur', 43.529700,  5.447400),
   (17,'Clermont-Ferrand','63','Auvergne-Rhône-Alpes',        45.777200,  3.087000),
   (18,'Le Havre',        '76','Normandie',                   49.494400,  0.107900),
   (19,'Reims',           '51','Grand Est',                   49.258300,  4.031700),
   (20,'Rouen',           '76','Normandie',                   49.443100,  1.099300),
   (21,'Caen',            '14','Normandie',                   49.182900, -0.370700),
   (22,'Nancy',           '54','Grand Est',                   48.692100,  6.184400),
   (23,'Metz',            '57','Grand Est',                   49.119300,  6.175700),
   (24,'Tours',           '37','Centre-Val de Loire',         47.394100,  0.684800),
   (25,'Brest',           '29','Bretagne',                    48.390400, -4.486100),
   (26,'Amiens',          '80','Hauts-de-France',             49.894100,  2.295800),
   (27,'Limoges',         '87','Nouvelle-Aquitaine',          45.833600,  1.261100),
   (28,'Perpignan',       '66','Occitanie',                   42.688700,  2.894800),
   (29,'Besançon',        '25','Bourgogne-Franche-Comté',     47.237800,  6.024100)
),
-- ─── Villes à risque inondation (coordonnées exactes du CSV) ─────────────
villes_inondation(rk, ville, dep, reg, lat, lon) AS (
  VALUES
   (0,'Montpellier',     '34','Occitanie',              43.610800,  3.876700),
   (1,'Toulouse',        '31','Occitanie',              43.604700,  1.444200),
   (2,'Perpignan',       '66','Occitanie',              42.688700,  2.894800),
   (3,'Nîmes',           '30','Occitanie',              43.836700,  4.360100),
   (4,'Bordeaux',        '33','Nouvelle-Aquitaine',     44.837800, -0.579200),
   (5,'Limoges',         '87','Nouvelle-Aquitaine',     45.833600,  1.261100),
   (6,'Grenoble',        '38','Auvergne-Rhône-Alpes',   45.188500,  5.724500),
   (7,'Lyon',            '69','Auvergne-Rhône-Alpes',   45.764000,  4.835700)
),
serie AS (SELECT generate_series(1, 12000) AS i),
h AS (
    SELECT i,
           abs(hashtext(i::text))             AS h1,
           abs(hashtext((i*17+5)::text))      AS h2,
           abs(hashtext((i*31+13)::text))     AS h3
    FROM serie
),
type_et_date AS (
    SELECT
        h.*,
        CASE
            WHEN h.i % 120 < 30 THEN 'Dégât des eaux'
            WHEN h.i % 120 < 36 THEN 'Incendie'
            WHEN h.i % 120 < 40 THEN 'Inondation'
            WHEN h.i % 120 < 56 THEN 'Vol'
            WHEN h.i % 120 < 65 THEN 'Bris de glace'
            WHEN h.i % 120 < 75 THEN 'Tempête'
            WHEN h.i % 120 < 85 THEN 'Grêle'
            WHEN h.i % 120 < 94 THEN 'Responsabilité civile'
            ELSE (ARRAY['Dégât des eaux','Vol','Bris de glace','Tempête','Grêle'])[1 + (h.i % 5)]
        END AS type_sin,
        CASE WHEN h.i % 2 = 0 THEN 2024 ELSE 2025 END AS annee,
        CASE
            WHEN h.i % 120 < 30 THEN
                (ARRAY[1,2,3,10,11,12,1,2,10,11,12,3])[1 + (h.i % 12)]
            WHEN h.i % 120 < 36 THEN
                1 + (h.h2 % 12)
            WHEN h.i % 120 < 40 THEN
                (ARRAY[1,2,3,9,10,11,1,2,9,10,11,3])[1 + (h.i % 12)]
            WHEN h.i % 120 < 56 THEN
                1 + (h.h3 % 12)
            WHEN h.i % 120 < 65 THEN
                (ARRAY[1,2,3,11,12,1,2,3,11,12,1,2])[1 + (h.i % 12)]
            WHEN h.i % 120 < 75 THEN
                (ARRAY[10,11,12,1,2,3,10,11,12,1,2,3])[1 + (h.i % 12)]
            WHEN h.i % 120 < 85 THEN
                (ARRAY[4,5,6,7,4,5,6,7,4,5,6,7])[1 + (h.i % 12)]
            ELSE
                1 + (h.h1 % 12)
        END AS mois_raw,
        (h.h3 % 28) + 1 AS jour
    FROM h
),
date_bounded AS (
    SELECT t.*,
           make_date(
               t.annee,
               CASE WHEN t.annee = 2025 AND t.mois_raw > 10 THEN 10
                    ELSE t.mois_raw END,
               t.jour
           ) AS date_surv
    FROM type_et_date t
),
garantie_calc AS (
    SELECT d.*,
        CASE d.type_sin
            WHEN 'Dégât des eaux'        THEN 1
            WHEN 'Incendie'              THEN 2
            WHEN 'Vol'                   THEN 3
            WHEN 'Bris de glace'         THEN 4
            WHEN 'Tempête'               THEN 5
            WHEN 'Grêle'                 THEN 6
            WHEN 'Inondation'            THEN 7
            WHEN 'Responsabilité civile' THEN 8
            ELSE 1
        END AS gid
    FROM date_bounded d
)
SELECT
    (SELECT contrat_id FROM contrats_actifs
     WHERE rn = 1 + (g.h1 % (SELECT mx FROM nb_actifs)))   AS contrat_id,
    1 + (g.i % 24)                                         AS agence_id,
    g.gid                                                  AS garantie_id,
    g.date_surv                                            AS date_survenance,
    LEAST(g.date_surv + (g.h2 % 27 + 1)::int, DATE '2025-12-31') AS date_declaration,
    g.type_sin                                             AS type_sinistre,
    CASE g.type_sin
        WHEN 'Dégât des eaux' THEN
            (ARRAY['Fuite canalisation','Débordement lave-vaisselle','Infiltration toiture','Rupture tuyauterie'])[1+(g.i%4)]
        WHEN 'Incendie' THEN
            (ARRAY['Court-circuit','Accident de cuisine','Défaut électrique','Cheminée'])[1+(g.i%4)]
        WHEN 'Vol' THEN
            (ARRAY['Effraction','Vol sans effraction','Cambriolage de nuit','Vol par ruse'])[1+(g.i%4)]
        WHEN 'Tempête' THEN
            (ARRAY['Vent violent','Chute arbre','Toiture arrachée'])[1+(g.i%3)]
        WHEN 'Inondation' THEN
            (ARRAY['Crue rivière','Montée nappe phréatique','Ruissellement pluvial'])[1+(g.i%3)]
        WHEN 'Grêle' THEN 'Grêle sévère'
        WHEN 'Bris de glace' THEN
            (ARRAY['Impact projection','Choc thermique','Accident'])[1+(g.i%3)]
        WHEN 'Responsabilité civile' THEN
            (ARRAY['Dommages tiers','Accident corporel','Trouble de jouissance'])[1+(g.i%3)]
        ELSE 'Cause indéterminée'
    END                                                    AS cause_sinistre,
    CASE
        WHEN g.i % 20 = 0  THEN 'déclaré'
        WHEN g.i % 20 < 5  THEN 'en cours'
        WHEN g.i % 20 < 9  THEN 'expertisé'
        WHEN g.i % 20 < 17 THEN 'clôturé'
        ELSE 'refusé'
    END                                                    AS statut_sinistre,
    GREATEST(1.00,
        ROUND(
            CASE g.type_sin
                WHEN 'Incendie'       THEN 5000  + (g.h2 % 45000)
                WHEN 'Inondation'     THEN 3000  + (g.h2 % 30000)
                WHEN 'Tempête'        THEN 1500  + (g.h2 % 20000)
                WHEN 'Dégât des eaux' THEN  500  + (g.h2 %  8000)
                WHEN 'Vol'            THEN  300  + (g.h2 % 15000)
                WHEN 'Grêle'          THEN  400  + (g.h2 %  6000)
                WHEN 'Bris de glace'  THEN   80  + (g.h2 %  1200)
                ELSE                         200 + (g.h2 %  5000)
            END::numeric
        , 2)
    )                                                      AS montant_estime,
    (SELECT franchise_standard FROM dim_garantie WHERE garantie_id = g.gid) AS franchise,
    -- Inondation : ville à risque ; autres : ville standard
    CASE WHEN g.type_sin = 'Inondation'
         THEN (SELECT ville FROM villes_inondation WHERE rk = g.h3 % 8)
         ELSE (SELECT ville FROM villes          WHERE rk = g.h3 % 30)
    END                                                    AS ville_sinistre,
    CASE WHEN g.type_sin = 'Inondation'
         THEN (SELECT dep  FROM villes_inondation WHERE rk = g.h3 % 8)
         ELSE (SELECT dep  FROM villes          WHERE rk = g.h3 % 30)
    END                                                    AS departement_sinistre,
    CASE WHEN g.type_sin = 'Inondation'
         THEN (SELECT reg  FROM villes_inondation WHERE rk = g.h3 % 8)
         ELSE (SELECT reg  FROM villes          WHERE rk = g.h3 % 30)
    END                                                    AS region_sinistre,
    -- ── v4 : coordonnées EXACTES du CSV, sans jitter ──────────────────────
    CASE WHEN g.type_sin = 'Inondation'
         THEN (SELECT lat  FROM villes_inondation WHERE rk = g.h3 % 8)
         ELSE (SELECT lat  FROM villes          WHERE rk = g.h3 % 30)
    END                                                    AS latitude,
    CASE WHEN g.type_sin = 'Inondation'
         THEN (SELECT lon  FROM villes_inondation WHERE rk = g.h3 % 8)
         ELSE (SELECT lon  FROM villes          WHERE rk = g.h3 % 30)
    END                                                    AS longitude
FROM garantie_calc g;


-- =============================================================================
-- 9. INDEMNISATIONS NORMALES (~13 800 lignes)
-- (section identique à v3)
-- =============================================================================

INSERT INTO fact_indemnisation
    (sinistre_id, date_paiement, montant_indemnise, statut_paiement, mode_paiement)
WITH
base_normaux AS (
    SELECT sinistre_id, date_declaration, montant_estime, franchise, statut_sinistre
    FROM fact_sinistre
    WHERE sinistre_id <= 12000
      AND statut_sinistre IN ('clôturé','expertisé','en cours','déclaré')
),
h AS (
    SELECT *,
           abs(hashtext(sinistre_id::text)) AS hv
    FROM base_normaux
),
premiere AS (
    SELECT
        sinistre_id,
        date_declaration + ((hv % 28) + 5)::int   AS date_paie,
        GREATEST(0.01,
            ROUND((COALESCE(montant_estime,0) - COALESCE(franchise,300))
                  * (0.60 + CAST(hv % 31 AS numeric)/100.0)
            , 2))                                  AS montant,
        CASE
            WHEN statut_sinistre IN ('en cours','déclaré') THEN 'prévu'
            WHEN sinistre_id % 20 = 0              THEN 'annulé'
            WHEN sinistre_id % 15 = 0              THEN 'prévu'
            ELSE 'payé'
        END                                        AS statut_p,
        CASE WHEN sinistre_id % 3 = 0 THEN 'chèque' ELSE 'virement' END AS mode_p
    FROM h
),
deuxieme AS (
    SELECT
        sinistre_id,
        date_declaration + ((hv % 28) + 33)::int  AS date_paie,
        ROUND(COALESCE(montant_estime,0) * (CAST(5 + (hv % 20) AS numeric)/100.0), 2) AS montant,
        CASE WHEN sinistre_id % 30 = 0 THEN 'annulé' ELSE 'payé' END AS statut_p,
        CASE WHEN sinistre_id % 4 = 0 THEN 'chèque' ELSE 'virement' END AS mode_p
    FROM h
    WHERE (statut_sinistre = 'expertisé')
       OR (statut_sinistre = 'clôturé' AND sinistre_id % 4 = 0)
)
SELECT sinistre_id, date_paie, montant, statut_p, mode_p FROM premiere
UNION ALL
SELECT sinistre_id, date_paie, montant, statut_p, mode_p FROM deuxieme;


-- =============================================================================
-- 10. ANOMALIES PÉDAGOGIQUES
-- Toutes les dates des anomalies sont bornées à [2024-01-01, 2025-12-31].
-- =============================================================================

-- ── A. Doublons de sinistres : 100 lignes (copie exacte des sinistres normaux)
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
SELECT
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
FROM fact_sinistre
WHERE sinistre_id % 120 = 0
  AND sinistre_id <= 12000;


-- ── B. date_declaration < date_survenance : exactement 80 lignes
--    Coordonnées v4 : Paris exactes du CSV, sans jitter
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
WITH
contrats_actifs_b AS (
    SELECT contrat_id, row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat WHERE statut_contrat = 'actif'
),
nb_b AS (SELECT max(rn) AS mx FROM contrats_actifs_b)
SELECT
    (SELECT contrat_id FROM contrats_actifs_b
     WHERE rn = 1 + (abs(hashtext(gs.i::text)) % (SELECT mx FROM nb_b))),
    1 + (gs.i % 24),
    1 + (gs.i % 8),
    DATE '2024-04-01' + (gs.i * 3)::int,
    DATE '2024-04-01' + (gs.i * 3)::int - (gs.i % 14 + 1)::int,
    (ARRAY['Dégât des eaux','Incendie','Vol','Tempête'])[1 + (gs.i % 4)],
    'Anomalie B — déclaration antérieure à la survenance',
    'déclaré',
    500 + (gs.i * 37 % 5000),
    300,
    'Paris', '75', 'Île-de-France',
    48.856600,  -- Paris CSV exact, sans jitter
    2.352200
FROM generate_series(1, 80) AS gs(i);


-- ── C. Sinistres sur contrats NON ACTIFS : exactement 100 lignes
--    Coordonnées v4 : Lyon exactes du CSV, sans jitter
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
SELECT
    c.contrat_id,
    c.agence_id,
    1 + (c.rn % 12),
    DATE '2024-06-01' + c.rn::int,
    DATE '2024-06-03' + c.rn::int,
    'Dégât des eaux',
    'Anomalie C — contrat non actif au moment du sinistre',
    'déclaré',
    300 + (c.rn * 29 % 3000),
    300,
    'Lyon', '69', 'Auvergne-Rhône-Alpes',
    45.764000,  -- Lyon CSV exact, sans jitter
    4.835700
FROM (
    SELECT contrat_id, agence_id,
           row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat
    WHERE statut_contrat IN ('résilié','expiré')
    ORDER BY contrat_id
    LIMIT 100
) c;


-- ── D. Localisations manquantes ou inexploitables : exactement 60 lignes
--    (inchangé — latitude et longitude sont NULL par construction de l'anomalie)
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
WITH
contrats_actifs_d AS (
    SELECT contrat_id, row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat WHERE statut_contrat = 'actif'
),
nb_d AS (SELECT max(rn) AS mx FROM contrats_actifs_d)
SELECT
    (SELECT contrat_id FROM contrats_actifs_d
     WHERE rn = 1 + (abs(hashtext((gs.i + 10000)::text)) % (SELECT mx FROM nb_d))),
    1 + (gs.i % 24),
    3,
    DATE '2024-03-01' + (gs.i * 5)::int,
    DATE '2024-03-03' + (gs.i * 5)::int,
    'Vol',
    'Anomalie D — localisation manquante ou inexploitable',
    'en cours',
    200 + (gs.i * 41 % 2000),
    150,
    CASE gs.i % 3 WHEN 0 THEN NULL WHEN 1 THEN '' ELSE 'inconnu' END,
    CASE gs.i % 2 WHEN 0 THEN NULL ELSE '00' END,
    NULL,
    NULL,  -- latitude NULL : anomalie D intentionnelle
    NULL   -- longitude NULL : anomalie D intentionnelle
FROM generate_series(1, 60) AS gs(i);


-- ── E. Montants incohérents : exactement 50 lignes
--    Coordonnées v4 : Marseille exactes du CSV, sans jitter
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
WITH
contrats_actifs_e AS (
    SELECT contrat_id, row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat WHERE statut_contrat = 'actif'
),
nb_e AS (SELECT max(rn) AS mx FROM contrats_actifs_e)
SELECT
    (SELECT contrat_id FROM contrats_actifs_e
     WHERE rn = 1 + (abs(hashtext((gs.i + 20000)::text)) % (SELECT mx FROM nb_e))),
    1 + (gs.i % 24),
    4,
    DATE '2024-05-01' + (gs.i * 4)::int,
    DATE '2024-05-03' + (gs.i * 4)::int,
    'Bris de glace',
    'Anomalie E — montant incohérent',
    'clôturé',
    CASE
        WHEN gs.i <= 15 THEN CAST(-(gs.i * 333) AS numeric)
        WHEN gs.i <= 25 THEN 0
        WHEN gs.i <= 35 THEN CAST((gs.i - 25) AS numeric) / 100.0
        ELSE CAST(500000 + gs.i * 17000 AS numeric)
    END,
    80,
    'Marseille', '13', 'Provence-Alpes-Côte d''Azur',
    43.296500,  -- Marseille CSV exact, sans jitter
    5.369800
FROM generate_series(1, 50) AS gs(i);


-- =============================================================================
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  ANOMALIE F — BLOC EXERCICE PÉDAGOGIQUE                                 │
-- │                                                                         │
-- │  ⚠  CE BLOC EST UN EXERCICE SÉPARÉ — NE PAS RÉEXÉCUTER                  │
-- │                                                                         │
-- │  Ce bloc est conçu pour être exécuté UNE SEULE FOIS, séparément,        │
-- │  dans le cadre de l'exercice sur la standardisation des libellés.       │
-- │                                                                         │
-- │  Si ce fichier est réexécuté pour réinitialiser la base (bloc 1         │
-- │  NETTOYAGE inclus), les tables sont vidées et ce bloc peut être         │
-- │  réexécuté sans risque.                                                 │
-- │                                                                         │
-- │  En revanche, si les apprenants exécutent uniquement ce bloc            │
-- │  sur une base déjà peuplée, ils obtiendront 100 lignes supplémentaires  │
-- │  et leurs volumes seront incorrects (12 590 au lieu de 12 490).         │
-- │                                                                         │
-- │  Règle : exécuter ce bloc UNIQUEMENT dans le cadre de l'exercice dédié, │
-- │  jamais isolément sur une base déjà initialisée.                        │
-- └─────────────────────────────────────────────────────────────────────────┘
-- =============================================================================

-- ── F. Libellés type_sinistre non normalisés : exactement 100 lignes
--    Coordonnées v4 : Toulouse exactes du CSV, sans jitter
INSERT INTO fact_sinistre (
    contrat_id, agence_id, garantie_id,
    date_survenance, date_declaration,
    type_sinistre, cause_sinistre, statut_sinistre,
    montant_estime, franchise,
    ville_sinistre, departement_sinistre, region_sinistre,
    latitude, longitude
)
WITH
contrats_actifs_f AS (
    SELECT contrat_id, row_number() OVER (ORDER BY contrat_id) AS rn
    FROM dim_contrat WHERE statut_contrat = 'actif'
),
nb_f AS (SELECT max(rn) AS mx FROM contrats_actifs_f)
SELECT
    (SELECT contrat_id FROM contrats_actifs_f
     WHERE rn = 1 + (abs(hashtext((gs.i + 30000)::text)) % (SELECT mx FROM nb_f))),
    1 + (gs.i % 24),
    CASE gs.i % 12
        WHEN 0 THEN 5 WHEN 1 THEN 5 WHEN 2 THEN 5
        WHEN 3 THEN 1 WHEN 4 THEN 1 WHEN 5 THEN 1
        WHEN 6 THEN 3 WHEN 7 THEN 3
        WHEN 8 THEN 4 WHEN 9 THEN 4
        WHEN 10 THEN 2
        ELSE 6
    END,
    DATE '2024-02-01' + (gs.i * 3)::int,
    DATE '2024-02-04' + (gs.i * 3)::int,
    CASE gs.i % 12
        WHEN 0  THEN 'Tempete'
        WHEN 1  THEN 'TEMPÊTE'
        WHEN 2  THEN 'tempête'
        WHEN 3  THEN 'Dégât des Eaux'
        WHEN 4  THEN 'Degat des eaux'
        WHEN 5  THEN 'DÉGÂT DES EAUX'
        WHEN 6  THEN 'Vol '
        WHEN 7  THEN ' Vol'
        WHEN 8  THEN 'bris de glace'
        WHEN 9  THEN 'BRIS DE GLACE'
        WHEN 10 THEN 'Incendie '
        ELSE         'grêle'
    END,
    'Anomalie F — libellé non standardisé',
    'déclaré',
    200 + (gs.i * 53 % 3000),
    200,
    'Toulouse', '31', 'Occitanie',
    43.604700,  -- Toulouse CSV exact, sans jitter
    1.444200
FROM generate_series(1, 100) AS gs(i);

-- ── FIN ANOMALIE F ────────────────────────────────────────────────────────


-- ── G. Indemnisations payées sur sinistres refusés : exactement 50 lignes
INSERT INTO fact_indemnisation
    (sinistre_id, date_paiement, montant_indemnise, statut_paiement, mode_paiement)
SELECT
    s.sinistre_id,
    s.date_declaration + 10,
    500 + (s.sinistre_id * 43 % 2000),
    'payé',
    CASE WHEN s.sinistre_id % 2 = 0 THEN 'virement' ELSE 'chèque' END
FROM (
    SELECT sinistre_id, date_declaration
    FROM fact_sinistre
    WHERE statut_sinistre = 'refusé'
      AND sinistre_id <= 12000
    ORDER BY sinistre_id
    LIMIT 50
) s;


-- ── H. Paiements antérieurs à la date de déclaration : exactement 20 lignes
INSERT INTO fact_indemnisation
    (sinistre_id, date_paiement, montant_indemnise, statut_paiement, mode_paiement)
SELECT
    s.sinistre_id,
    s.date_survenance - (1 + (s.sinistre_id % 7))::int,
    100 + (s.sinistre_id * 51 % 1000),
    'payé',
    'virement'
FROM (
    SELECT sinistre_id, date_survenance, date_declaration
    FROM fact_sinistre
    WHERE statut_sinistre = 'clôturé'
      AND sinistre_id <= 12000
    ORDER BY sinistre_id
    LIMIT 20
) s;


-- ── I. Montants indemnisés anormaux : exactement 20 lignes
INSERT INTO fact_indemnisation
    (sinistre_id, date_paiement, montant_indemnise, statut_paiement, mode_paiement)
SELECT
    s.sinistre_id,
    s.date_declaration + 7,
    CASE
        WHEN gs.i <= 5  THEN CAST(-(gs.i * 100) AS numeric)
        WHEN gs.i <= 10 THEN 0
        WHEN gs.i <= 15 THEN CAST(gs.i % 10 AS numeric) / 100.0
        ELSE CAST(300000 + gs.i * 10000 AS numeric)
    END,
    CASE WHEN gs.i <= 15 THEN 'annulé' ELSE 'payé' END,
    'virement'
FROM generate_series(1, 20) AS gs(i)
JOIN (
    SELECT sinistre_id, date_declaration,
           row_number() OVER (ORDER BY sinistre_id) AS rn
    FROM fact_sinistre
    WHERE statut_sinistre = 'expertisé'
      AND sinistre_id <= 12000
    ORDER BY sinistre_id
    LIMIT 20
) s ON s.rn = gs.i;


-- =============================================================================
-- 11. CONTRÔLES FINAUX
-- =============================================================================

-- ── 11.1 Volumes ─────────────────────────────────────────────────────────────
SELECT 'dim_assure'        AS table_name, COUNT(*) AS nb_lignes FROM dim_assure       UNION ALL
SELECT 'dim_agence',                      COUNT(*) FROM dim_agence                    UNION ALL
SELECT 'dim_garantie',                    COUNT(*) FROM dim_garantie                  UNION ALL
SELECT 'dim_contrat',                     COUNT(*) FROM dim_contrat                   UNION ALL
SELECT 'contrat_garantie',                COUNT(*) FROM contrat_garantie              UNION ALL
SELECT 'fact_sinistre',                   COUNT(*) FROM fact_sinistre                 UNION ALL
SELECT 'fact_indemnisation',              COUNT(*) FROM fact_indemnisation
ORDER BY table_name;

-- ── 11.2 Coordonnées : 30 villes distinctes dans fact_sinistre ───────────────
-- Attendu : 30 villes avec coordonnées (+ quelques lignes NULL pour anomalie D)
SELECT ville_sinistre, latitude, longitude, COUNT(*) AS nb
FROM fact_sinistre
WHERE ville_sinistre IS NOT NULL
  AND TRIM(ville_sinistre) <> ''
  AND ville_sinistre <> 'inconnu'
GROUP BY ville_sinistre, latitude, longitude
ORDER BY ville_sinistre;

-- ── 11.3 Unicité des coordonnées par ville (fact_sinistre) ───────────────────
-- Attendu : 0 ville avec plusieurs paires de coordonnées différentes
-- Si ce résultat est > 0, une ville a des coordonnées incohérentes.
SELECT ville_sinistre, COUNT(DISTINCT (latitude, longitude)) AS nb_paires_coords
FROM fact_sinistre
WHERE ville_sinistre IS NOT NULL
  AND TRIM(ville_sinistre) <> ''
  AND ville_sinistre <> 'inconnu'
  AND latitude IS NOT NULL
GROUP BY ville_sinistre
HAVING COUNT(DISTINCT (latitude, longitude)) > 1
ORDER BY ville_sinistre;

-- ── 11.4 Cohérence coordonnées dim_agence vs fact_sinistre ───────────────────
-- Pour les villes présentes dans les deux tables, les coordonnées doivent correspondre.
-- Attendu : 0 ligne (aucun écart entre dim_agence et fact_sinistre pour les mêmes villes)
SELECT
    a.ville       AS ville_agence,
    a.latitude    AS lat_agence,
    a.longitude   AS lon_agence,
    s.ville_sinistre,
    s.latitude    AS lat_sinistre,
    s.longitude   AS lon_sinistre
FROM dim_agence a
JOIN (
    SELECT DISTINCT ville_sinistre, latitude, longitude
    FROM fact_sinistre
    WHERE latitude IS NOT NULL
) s ON s.ville_sinistre = a.ville
WHERE a.latitude <> s.latitude
   OR a.longitude <> s.longitude;

-- ── 11.5 Absence de NULL latitude/longitude hors anomalie D ──────────────────
-- Attendu : 0 (seuls les sinistres D ont latitude NULL)
SELECT COUNT(*) AS coords_null_hors_anomalie_D
FROM fact_sinistre
WHERE (latitude IS NULL OR longitude IS NULL)
  AND (cause_sinistre IS NULL
       OR cause_sinistre NOT LIKE '%Anomalie D%');

-- ── 11.6 Période sinistres — AUCUNE date en 2026 ─────────────────────────────
SELECT
    MIN(date_survenance)  AS date_surv_min,
    MAX(date_survenance)  AS date_surv_max,
    MIN(date_declaration) AS date_decl_min,
    MAX(date_declaration) AS date_decl_max,
    COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM date_survenance)  = 2026) AS sinistres_2026,
    COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM date_declaration) = 2026) AS declarations_2026
FROM fact_sinistre;

-- ── 11.7 Anomalie B : date_declaration < date_survenance
-- Attendu : exactement 80
SELECT COUNT(*) AS B_decl_avant_survenance
FROM fact_sinistre
WHERE date_declaration < date_survenance;

-- ── 11.8a Anomalie E : montant_estime ≤ 0
-- Attendu : exactement 25
SELECT COUNT(*) AS E_montants_negatifs_ou_nuls
FROM fact_sinistre
WHERE montant_estime <= 0;

-- ── 11.8b Anomalie E : montant anormal positif
-- Attendu : 10 quasi-nuls + 15 extrêmes = 25
SELECT
    COUNT(*) FILTER (WHERE montant_estime > 0 AND montant_estime < 1)      AS E_quasi_nuls,
    COUNT(*) FILTER (WHERE montant_estime > 400000)                         AS E_extremes,
    COUNT(*) FILTER (WHERE montant_estime > 0 AND montant_estime < 1)
           + COUNT(*) FILTER (WHERE montant_estime > 400000)                AS E_anormaux_positifs
FROM fact_sinistre;

-- ── 11.9 Anomalie D : localisation manquante
-- Attendu : exactement 60
SELECT COUNT(*) AS D_localisation_manquante
FROM fact_sinistre
WHERE ville_sinistre IS NULL
   OR TRIM(ville_sinistre) = ''
   OR ville_sinistre = 'inconnu'
   OR latitude IS NULL;

-- ── 11.10 Anomalie C : sinistres sur contrat non actif
-- Attendu : ≥ 100
SELECT COUNT(*) AS C_sinistres_contrat_non_actif
FROM fact_sinistre s
JOIN dim_contrat c ON s.contrat_id = c.contrat_id
WHERE c.statut_contrat IN ('résilié','expiré');

-- ── 11.11 Anomalie G : indemnisations payées sur sinistres refusés
-- Attendu : exactement 50
SELECT COUNT(*) AS G_indem_sur_sinistre_refuse
FROM fact_indemnisation i
JOIN fact_sinistre s ON i.sinistre_id = s.sinistre_id
WHERE s.statut_sinistre = 'refusé'
  AND i.statut_paiement = 'payé';

-- ── 11.12 Anomalie H : paiements antérieurs à la date de déclaration
-- Attendu : exactement 20
SELECT COUNT(*) AS H_paiements_avant_declaration
FROM fact_indemnisation i
JOIN fact_sinistre s ON i.sinistre_id = s.sinistre_id
WHERE i.date_paiement < s.date_declaration;

-- ── 11.13 Anomalie F : libellés non normalisés
-- Attendu : 100 lignes, 12 formes distinctes
SELECT type_sinistre, COUNT(*) AS nb
FROM fact_sinistre
WHERE type_sinistre NOT IN (
    'Dégât des eaux','Incendie','Vol','Bris de glace',
    'Tempête','Grêle','Inondation','Responsabilité civile','Dommages électriques'
)
GROUP BY type_sinistre
ORDER BY nb DESC;

-- ── 11.14 Anomalie A : doublons sinistres
-- Attendu : ≥ 100 groupes
SELECT COUNT(*) AS A_nb_groupes_en_doublon
FROM (
    SELECT contrat_id, date_survenance, type_sinistre, COUNT(*) AS nb
    FROM fact_sinistre
    GROUP BY contrat_id, date_survenance, type_sinistre
    HAVING COUNT(*) > 1
) t;

-- ── 11.15 Doublons métier dim_assure
-- Attendu : exactement 40 groupes
SELECT COUNT(*) AS doublons_metier_assures
FROM (
    SELECT nom, prenom, date_naissance, email, COUNT(*) AS nb
    FROM dim_assure
    WHERE date_naissance IS NOT NULL
      AND email IS NOT NULL
    GROUP BY nom, prenom, date_naissance, email
    HAVING COUNT(*) > 1
) t;

-- ── 11.16 Montants normaux : aucun sinistre normal avec montant ≤ 0
-- Attendu : 0
SELECT COUNT(*) AS montants_zero_ou_negatif_dans_normaux
FROM fact_sinistre
WHERE sinistre_id <= 12000
  AND montant_estime <= 0;

-- ── 11.17 Distribution sinistres normaux par type
SELECT
    type_sinistre,
    COUNT(*)                                AS nb_sinistres,
    ROUND(COUNT(*) * 100.0 / 12000, 1)     AS pct,
    ROUND(AVG(montant_estime)::numeric, 2)  AS montant_moyen
FROM fact_sinistre
WHERE sinistre_id <= 12000
GROUP BY type_sinistre
ORDER BY nb_sinistres DESC;

-- ── 11.18 Répartition par année
SELECT
    EXTRACT(YEAR FROM date_survenance)::int AS annee,
    COUNT(*)                                AS nb_sinistres
FROM fact_sinistre
WHERE sinistre_id <= 12000
GROUP BY annee
ORDER BY annee;

-- ── 11.19 Distribution contrat_garantie par formule
-- Attendu : Essentielle=25600, Confort=38400, Premium=25600, TOTAL=89600
SELECT
    c.formule,
    COUNT(*)                     AS nb_lignes_cg,
    COUNT(DISTINCT c.contrat_id) AS nb_contrats,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT c.contrat_id), 1) AS garanties_par_contrat
FROM contrat_garantie cg
JOIN dim_contrat c ON cg.contrat_id = c.contrat_id
GROUP BY c.formule
ORDER BY c.formule;

-- ── 11.20 Inondations par région
SELECT region_sinistre, COUNT(*) AS nb
FROM fact_sinistre
WHERE type_sinistre = 'Inondation'
  AND sinistre_id <= 12000
GROUP BY region_sinistre
ORDER BY nb DESC;

-- =============================================================================
-- FIN — assurrisk_init_2024_2025.sql  v4
-- AssurRisk — Jeu de données pédagogique 2024-2025
-- VERSION DÉTERMINISTE v4 — résultats identiques sur toutes les machines PostgreSQL 15+
-- Pour réinitialiser : relancer le fichier entier depuis le bloc 1 (NETTOYAGE)
-- Coordonnées GPS : source de vérité = villes_coordonnees_meteo.csv
-- =============================================================================
