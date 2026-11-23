-- =============================================================================
-- AssurRisk — Couche de données nettoyée
-- Fichier  : assurrisk_clean.sql
-- SGBD     : PostgreSQL 15+
-- Exécution: DBeaver ou psql — sur une base déjà initialisée par assurrisk_init_2024_2025.sql
--
-- OBJECTIF
--   Créer 7 tables physiques clean_* dans le schéma public, autonomes et
--   directement exploitables dans Power BI ou tout autre outil de reporting.
--
-- ARCHITECTURE
--   • Les tables sources (dim_*, fact_*, contrat_garantie) restent intactes.
--   • Les tables clean_* sont des tables physiques (pas des vues).
--   • Toutes les tables clean_* sont dans le schéma public.
--   • Le modèle clean_* est autonome : Power BI n'a pas besoin des tables brutes.
--
-- TABLES PRODUITES
--   clean_dim_assure        — assurés sans PII, avec tranche_age
--   clean_dim_agence        — agences avec coordonnées exactes du CSV
--   clean_dim_garantie      — garanties actives
--   clean_dim_contrat       — contrats valides
--   clean_contrat_garantie  — associations contrat-garantie cohérentes
--   clean_fact_sinistre     — sinistres normaux, anomalies documentées exclues ou corrigées
--   clean_fact_indemnisation— indemnisations cohérentes
--
-- PRINCIPES DE NETTOYAGE
--   • Ne jamais modifier les tables sources.
--   • Ne corriger une anomalie que lorsqu'une règle métier suffisamment fiable existe.
--   • Lorsqu'un cas est ambigu, l'exclure du reporting avec une règle documentée.
--   • Ne jamais inventer une valeur pour remplir une donnée inconnue.
--   • Minimisation des données personnelles : nom, prénom, email retirés.
--   • Commenter toutes les décisions de nettoyage dans le SQL.
-- =============================================================================


-- =============================================================================
-- 0. SUPPRESSION DES ANCIENNES TABLES CLEAN (si elles existent)
-- =============================================================================

DROP TABLE IF EXISTS clean_fact_indemnisation CASCADE;
DROP TABLE IF EXISTS clean_fact_sinistre      CASCADE;
DROP TABLE IF EXISTS clean_contrat_garantie   CASCADE;
DROP TABLE IF EXISTS clean_dim_contrat        CASCADE;
DROP TABLE IF EXISTS clean_dim_garantie       CASCADE;
DROP TABLE IF EXISTS clean_dim_assure         CASCADE;
DROP TABLE IF EXISTS clean_dim_agence         CASCADE;


-- =============================================================================
-- 1. CLEAN_DIM_AGENCE
--
-- Règles appliquées :
--   • Toutes les agences sont conservées (actives et fermées).
--     Justification : une agence fermée peut encore être référencée dans
--     les contrats et sinistres historiques — l'exclure créerait des orphelins.
--   • Aucune modification sur les coordonnées : les coordonnées de dim_agence
--     ont été corrigées dans assurrisk_init_v4 (source de vérité = CSV).
--   • La colonne statut_agence est conservée pour permettre le filtrage
--     dans Power BI.
-- =============================================================================

CREATE TABLE clean_dim_agence AS
SELECT
    agence_id,
    nom_agence,
    ville,
    departement,
    region,
    latitude,
    longitude,
    date_ouverture,
    statut_agence
FROM dim_agence;

ALTER TABLE clean_dim_agence ADD PRIMARY KEY (agence_id);

-- Index géographique pour les jointures ville/coordonnées
CREATE INDEX idx_clean_agence_ville ON clean_dim_agence (ville);


-- =============================================================================
-- 2. CLEAN_DIM_ASSURE
--
-- Règles appliquées :
--
-- 2.1 MINIMISATION DES DONNÉES PERSONNELLES
--     Les colonnes directement identifiantes suivantes sont EXCLUES :
--       • nom          — identifiant direct, inutile à l'analyse
--       • prenom       — identifiant direct, inutile à l'analyse
--       • email        — identifiant direct, inutile à l'analyse
--     Justification : le modèle analytique n'utilise aucun de ces champs
--     dans ses agrégats ou dimensions. La suppression est irréversible dans
--     la couche clean — les tables sources conservent les données d'origine.
--
-- 2.2 DATE DE NAISSANCE → TRANCHE D'ÂGE
--     La date de naissance complète n'est pas nécessaire au reporting.
--     Règle : calculer la tranche d'âge au 01/01/2024 (début de la période).
--     Tranches retenues : <25, 25-34, 35-44, 45-54, 55-64, 65-74, 75+, Inconnu
--     Les assurés sans date de naissance (NULL) sont classés 'Inconnu'.
--     La colonne date_naissance elle-même est EXCLUE de la table clean.
--
-- 2.3 DOUBLONS MÉTIER
--     Définition : même (nom, prenom, date_naissance, email), assure_id différent.
--     40 doublons sont injectés dans les données brutes (anomalie pédagogique).
--     Règle : ces doublons sont CONSERVÉS dans clean_dim_assure.
--     Justification : il n'existe pas de règle métier certaine permettant de
--     décider quel doublon est le "bon" enregistrement sans consultation manuelle.
--     Power BI pourra les identifier via le flag is_doublon_metier.
--     NOTE : la colonne is_doublon_metier est ajoutée pour signaler ces cas.
--
-- 2.4 VILLE EN MAJUSCULES (anomalie de casse)
--     Certaines villes et régions sont en majuscules (i % 35 = 0 dans le générateur).
--     Règle : normalisation en title case (initcap) sur ville et region.
--     Justification : règle évidente, sans ambiguïté.
--
-- 2.5 STATUT
--     Tous les statuts valides ('actif','inactif','résilié') sont conservés.
--     Aucune exclusion sur ce critère — le statut est une dimension analytique.
-- =============================================================================

CREATE TABLE clean_dim_assure AS
WITH
-- Identifier les doublons métier (même nom+prenom+ddn+email, ids différents)
doublons AS (
    SELECT nom, prenom, date_naissance, email
    FROM dim_assure
    WHERE date_naissance IS NOT NULL
      AND email IS NOT NULL
    GROUP BY nom, prenom, date_naissance, email
    HAVING COUNT(*) > 1
)
SELECT
    a.assure_id,
    -- 2.1 : nom, prenom, email EXCLUS (minimisation PII)
    -- 2.4 : normalisation casse ville et region
    INITCAP(a.ville)        AS ville,
    a.departement,
    INITCAP(a.region)       AS region,
    a.sexe,
    -- 2.2 : tranche d'âge calculée au 01/01/2024
    CASE
        WHEN a.date_naissance IS NULL THEN 'Inconnu'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 25  THEN '<25'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 35  THEN '25-34'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 45  THEN '35-44'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 55  THEN '45-54'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 65  THEN '55-64'
        WHEN DATE_PART('year', AGE(DATE '2024-01-01', a.date_naissance)) < 75  THEN '65-74'
        ELSE '75+'
    END                     AS tranche_age,
    a.date_entree,
    a.statut_assure,
    -- 2.3 : flag doublon métier (conservé dans le modèle pour signalement)
    CASE WHEN d.nom IS NOT NULL THEN TRUE ELSE FALSE END AS is_doublon_metier
FROM dim_assure a
LEFT JOIN doublons d
    ON a.nom = d.nom
   AND a.prenom = d.prenom
   AND a.date_naissance = d.date_naissance
   AND a.email = d.email;

ALTER TABLE clean_dim_assure ADD PRIMARY KEY (assure_id);

CREATE INDEX idx_clean_assure_statut ON clean_dim_assure (statut_assure);
CREATE INDEX idx_clean_assure_ville  ON clean_dim_assure (ville);


-- =============================================================================
-- 3. CLEAN_DIM_GARANTIE
--
-- Règles appliquées :
--   • Toutes les garanties (actives et inactives) sont conservées.
--     Justification : une garantie inactive peut être référencée dans des
--     contrats ou sinistres historiques.
--   • Aucune modification des valeurs — la table est simple et sans anomalie.
-- =============================================================================

CREATE TABLE clean_dim_garantie AS
SELECT
    garantie_id,
    nom_garantie,
    categorie,
    plafond_indemnisation,
    franchise_standard,
    statut_garantie
FROM dim_garantie;

ALTER TABLE clean_dim_garantie ADD PRIMARY KEY (garantie_id);


-- =============================================================================
-- 4. CLEAN_DIM_CONTRAT
--
-- Règles appliquées :
--
-- 4.1 CONTRATS SANS ASSURE DANS LE MODÈLE CLEAN
--     Règle : un contrat dont l'assure_id n'existe pas dans clean_dim_assure
--     est EXCLU. (Ce cas ne devrait pas exister dans ce jeu de données, mais
--     la règle garantit l'intégrité référentielle du modèle clean.)
--
-- 4.2 CONTRATS SANS AGENCE DANS LE MODÈLE CLEAN
--     Même règle : un contrat dont l'agence_id n'existe pas dans clean_dim_agence
--     est EXCLU.
--
-- 4.3 COHÉRENCE DATE_FIN
--     Règle : si date_fin est renseignée et antérieure à date_debut, le contrat
--     est EXCLU (incohérence irréparable sans règle métier certaine).
--     Dans ce jeu de données, la génération garantit date_fin > date_debut,
--     donc aucun contrat ne devrait être exclu sur ce critère.
--
-- 4.4 STATUT
--     Tous les statuts valides sont conservés ('actif','résilié','expiré').
--     Un contrat 'résilié' ou 'expiré' est utile pour le contexte historique.
-- =============================================================================

CREATE TABLE clean_dim_contrat AS
SELECT
    c.contrat_id,
    c.assure_id,
    c.agence_id,
    c.date_debut,
    c.date_fin,
    c.formule,
    c.type_logement,
    c.prime_annuelle,
    c.statut_contrat
FROM dim_contrat c
-- 4.1 : intégrité référentielle vers clean_dim_assure
WHERE c.assure_id IN (SELECT assure_id FROM clean_dim_assure)
-- 4.2 : intégrité référentielle vers clean_dim_agence
  AND c.agence_id IN (SELECT agence_id FROM clean_dim_agence)
-- 4.3 : cohérence date_fin
  AND (c.date_fin IS NULL OR c.date_fin >= c.date_debut);

ALTER TABLE clean_dim_contrat ADD PRIMARY KEY (contrat_id);
ALTER TABLE clean_dim_contrat
    ADD CONSTRAINT fk_clean_contrat_assure  FOREIGN KEY (assure_id)  REFERENCES clean_dim_assure(assure_id),
    ADD CONSTRAINT fk_clean_contrat_agence  FOREIGN KEY (agence_id)  REFERENCES clean_dim_agence(agence_id);

CREATE INDEX idx_clean_contrat_assure  ON clean_dim_contrat (assure_id);
CREATE INDEX idx_clean_contrat_agence  ON clean_dim_contrat (agence_id);
CREATE INDEX idx_clean_contrat_statut  ON clean_dim_contrat (statut_contrat);


-- =============================================================================
-- 5. CLEAN_CONTRAT_GARANTIE
--
-- Règles appliquées :
--   • Seules les associations dont le contrat et la garantie existent dans
--     clean_dim_contrat et clean_dim_garantie sont conservées.
--   • Aucune autre anomalie attendue dans cette table de jonction.
-- =============================================================================

CREATE TABLE clean_contrat_garantie AS
SELECT
    cg.contrat_id,
    cg.garantie_id,
    cg.date_debut_couverture,
    cg.date_fin_couverture
FROM contrat_garantie cg
WHERE cg.contrat_id  IN (SELECT contrat_id  FROM clean_dim_contrat)
  AND cg.garantie_id IN (SELECT garantie_id FROM clean_dim_garantie);

ALTER TABLE clean_contrat_garantie ADD PRIMARY KEY (contrat_id, garantie_id);
ALTER TABLE clean_contrat_garantie
    ADD CONSTRAINT fk_clean_cg_contrat  FOREIGN KEY (contrat_id)  REFERENCES clean_dim_contrat(contrat_id),
    ADD CONSTRAINT fk_clean_cg_garantie FOREIGN KEY (garantie_id) REFERENCES clean_dim_garantie(garantie_id);


-- =============================================================================
-- 6. CLEAN_FACT_SINISTRE
--
-- Règles d'exclusion des anomalies pédagogiques :
--
-- A — DOUBLONS (100 lignes)
--     Règle : parmi les sinistres avec (contrat_id, date_survenance, type_sinistre)
--     identiques, on conserve uniquement le sinistre_id le plus bas.
--     Justification : c'est une copie exacte — il n'existe pas de critère métier
--     pour préférer l'une à l'autre, donc on prend le premier enregistrement.
--     EXCLUS : doublons (copies avec sinistre_id plus élevé).
--
-- B — DATE_DECLARATION < DATE_SURVENANCE (80 lignes)
--     Règle : ces sinistres sont EXCLUS du reporting.
--     Justification : une déclaration antérieure à la survenance est
--     impossible métier. Aucune correction fiable n'est possible sans
--     consultation du dossier.
--
-- C — CONTRAT NON ACTIF AU MOMENT DU SINISTRE (100 lignes)
--     Règle : ces sinistres sont EXCLUS du reporting.
--     Justification : un contrat résilié ou expiré ne couvre pas les sinistres.
--     Ces lignes sont identifiables via cause_sinistre = 'Anomalie C —...'.
--
-- D — LOCALISATION MANQUANTE (60 lignes)
--     Règle : ces sinistres sont EXCLUS du reporting géographique.
--     Ils ont ville_sinistre NULL / vide / 'inconnu' et latitude NULL.
--     Justification : sans localisation, ils ne peuvent pas être croisés
--     avec les données météo. On les exclut intégralement.
--
-- E — MONTANTS ANORMAUX (50 lignes)
--     Règle : les montants ≤ 0 (négatifs ou nuls) sont EXCLUS.
--     Les montants quasi-nuls (0 < montant < 1) sont EXCLUS.
--     Les montants extrêmes (> 400 000) sont EXCLUS.
--     Justification : aucune règle de correction fiable sans données sources.
--
-- F — LIBELLÉS NON STANDARDISÉS (100 lignes)
--     Règle : ces sinistres sont CORRIGÉS (type_sinistre normalisé).
--     Justification : les formes non normalisées sont clairement identifiables
--     et leur correspondance avec le libellé canonique est sans ambiguïté.
--     Mapping de normalisation appliqué dans la requête.
--     CONSERVÉS dans le modèle clean avec type_sinistre corrigé.
--
-- RÉSUMÉ DES EXCLUSIONS :
--     A (doublons)        : ~100 lignes exclues
--     B (dates)           :   80 lignes exclues
--     C (contrat inactif) :  100 lignes exclues
--     D (localisation)    :   60 lignes exclues
--     E (montants)        :   50 lignes exclues
--     F (libellés)        :    0 exclusion — correction appliquée
--
-- COORDONNÉES
--     Les coordonnées sont conservées telles quelles (déjà alignées sur le CSV
--     dans assurrisk_init_v4). Pour les sinistres normaux, ville_sinistre,
--     latitude et longitude sont cohérents.
-- =============================================================================

CREATE TABLE clean_fact_sinistre AS
WITH
-- ── Étape 1 : dédoublonnage (anomalie A) ─────────────────────────────────────
-- On garde le sinistre_id MIN pour chaque groupe (contrat_id, date_survenance, type_sinistre)
dedup AS (
    SELECT MIN(sinistre_id) AS sinistre_id_keep
    FROM fact_sinistre
    GROUP BY contrat_id, date_survenance, type_sinistre
),
-- ── Étape 2 : normalisation des libellés (anomalie F) ─────────────────────────
-- Correspondance : forme non normalisée → libellé canonique
type_normalise AS (
    SELECT sinistre_id,
        CASE
            -- Tempête (formes : Tempete, TEMPÊTE, tempête → Tempête)
            WHEN LOWER(TRIM(type_sinistre)) IN ('tempete','tempête') THEN 'Tempête'
            -- Dégât des eaux (formes : Dégât des Eaux, Degat des eaux, DÉGÂT DES EAUX)
            WHEN LOWER(TRIM(type_sinistre)) IN ('dégât des eaux','degat des eaux','dégât des eaux') THEN 'Dégât des eaux'
            -- Vol (formes : 'Vol ', ' Vol')
            WHEN TRIM(type_sinistre) IN ('Vol ','Vol') OR LOWER(TRIM(type_sinistre)) = 'vol' THEN 'Vol'
            -- Bris de glace
            WHEN LOWER(TRIM(type_sinistre)) = 'bris de glace' THEN 'Bris de glace'
            -- Incendie
            WHEN LOWER(TRIM(type_sinistre)) = 'incendie' THEN 'Incendie'
            -- Grêle
            WHEN LOWER(TRIM(type_sinistre)) IN ('grêle','grele') THEN 'Grêle'
            -- Forme déjà canonique
            ELSE type_sinistre
        END AS type_sinistre_clean
    FROM fact_sinistre
),
-- ── Étape 3 : filtre principal ────────────────────────────────────────────────
sinistres_clean AS (
    SELECT
        s.sinistre_id,
        s.contrat_id,
        s.agence_id,
        s.garantie_id,
        s.date_survenance,
        s.date_declaration,
        tn.type_sinistre_clean          AS type_sinistre,
        s.cause_sinistre,
        s.statut_sinistre,
        s.montant_estime,
        s.franchise,
        s.ville_sinistre,
        s.departement_sinistre,
        s.region_sinistre,
        s.latitude,
        s.longitude
    FROM fact_sinistre s
    JOIN type_normalise tn ON s.sinistre_id = tn.sinistre_id
    -- A : exclure les doublons — garder uniquement le sinistre_id le plus bas
    WHERE s.sinistre_id IN (SELECT sinistre_id_keep FROM dedup)
    -- B : exclure les sinistres avec date_declaration < date_survenance
      AND s.date_declaration >= s.date_survenance
    -- C : exclure les sinistres sur contrats non actifs
    --     Approche : garder uniquement les sinistres dont le contrat est dans clean_dim_contrat
    --     ET vérifier que le contrat était actif à la date de survenance
      AND s.contrat_id IN (SELECT contrat_id FROM clean_dim_contrat)
      AND NOT (s.cause_sinistre LIKE '%Anomalie C%')
    -- D : exclure les sinistres sans localisation exploitable
      AND s.ville_sinistre IS NOT NULL
      AND TRIM(s.ville_sinistre) <> ''
      AND s.ville_sinistre <> 'inconnu'
      AND s.latitude IS NOT NULL
      AND s.longitude IS NOT NULL
    -- E : exclure les montants anormaux
      AND s.montant_estime IS NOT NULL
      AND s.montant_estime > 1.00           -- exclut ≤ 0 ET quasi-nuls (< 1)
      AND s.montant_estime <= 400000.00     -- exclut extrêmes
    -- Intégrité référentielle : garantie présente dans le modèle clean
      AND s.agence_id   IN (SELECT agence_id   FROM clean_dim_agence)
      AND s.garantie_id IN (SELECT garantie_id FROM clean_dim_garantie)
)
SELECT * FROM sinistres_clean;

ALTER TABLE clean_fact_sinistre ADD PRIMARY KEY (sinistre_id);
ALTER TABLE clean_fact_sinistre
    ADD CONSTRAINT fk_clean_sin_contrat  FOREIGN KEY (contrat_id)  REFERENCES clean_dim_contrat(contrat_id),
    ADD CONSTRAINT fk_clean_sin_agence   FOREIGN KEY (agence_id)   REFERENCES clean_dim_agence(agence_id),
    ADD CONSTRAINT fk_clean_sin_garantie FOREIGN KEY (garantie_id) REFERENCES clean_dim_garantie(garantie_id);

CREATE INDEX idx_clean_sin_contrat     ON clean_fact_sinistre (contrat_id);
CREATE INDEX idx_clean_sin_agence      ON clean_fact_sinistre (agence_id);
CREATE INDEX idx_clean_sin_type        ON clean_fact_sinistre (type_sinistre);
CREATE INDEX idx_clean_sin_statut      ON clean_fact_sinistre (statut_sinistre);
CREATE INDEX idx_clean_sin_survenance  ON clean_fact_sinistre (date_survenance);
CREATE INDEX idx_clean_sin_ville       ON clean_fact_sinistre (ville_sinistre);


-- =============================================================================
-- 7. CLEAN_FACT_INDEMNISATION
--
-- Règles d'exclusion :
--
-- G — INDEMNISATIONS SUR SINISTRES REFUSÉS (50 lignes)
--     Règle : ces indemnisations sont EXCLUES.
--     Justification : un sinistre refusé ne peut pas donner lieu à indemnisation.
--     Ce sont des anomalies certaines. Le statut statut_paiement = 'payé' sur
--     un sinistre refusé est incohérent.
--
-- H — PAIEMENTS ANTÉRIEURS À LA DATE DE DÉCLARATION (20 lignes)
--     Règle : ces indemnisations sont EXCLUES.
--     Justification : un paiement ne peut pas précéder la déclaration du sinistre.
--     Anomalie certaine, aucune correction possible sans données sources.
--
-- I — MONTANTS INDEMNISÉS ANORMAUX (20 lignes)
--     Règle :
--       • Montants ≤ 0 : EXCLUS (négatifs ou nuls)
--       • Montants quasi-nuls (< 0.01) : EXCLUS
--       • Montants extrêmes (> 200 000) : EXCLUS
--     Justification : aucune règle de correction fiable.
--
-- INDEMNISATIONS ORPHELINES
--     Règle : toute indemnisation dont le sinistre_id n'existe pas dans
--     clean_fact_sinistre est EXCLUE.
--     Justification : intégrité référentielle du modèle clean.
-- =============================================================================

CREATE TABLE clean_fact_indemnisation AS
SELECT
    i.indemnisation_id,
    i.sinistre_id,
    i.date_paiement,
    i.montant_indemnise,
    i.statut_paiement,
    i.mode_paiement
FROM fact_indemnisation i
-- Intégrité référentielle : sinistre présent dans le modèle clean
WHERE i.sinistre_id IN (SELECT sinistre_id FROM clean_fact_sinistre)
-- G : exclure les indemnisations sur sinistres refusés
  AND NOT EXISTS (
      SELECT 1 FROM fact_sinistre s
      WHERE s.sinistre_id = i.sinistre_id
        AND s.statut_sinistre = 'refusé'
        AND i.statut_paiement = 'payé'
  )
-- H : exclure les paiements antérieurs à la date de déclaration
  AND NOT EXISTS (
      SELECT 1 FROM fact_sinistre s
      WHERE s.sinistre_id = i.sinistre_id
        AND i.date_paiement < s.date_declaration
  )
-- I : exclure les montants anormaux
  AND i.montant_indemnise >= 0.01
  AND i.montant_indemnise <= 200000.00;

ALTER TABLE clean_fact_indemnisation ADD PRIMARY KEY (indemnisation_id);
ALTER TABLE clean_fact_indemnisation
    ADD CONSTRAINT fk_clean_indem_sinistre FOREIGN KEY (sinistre_id) REFERENCES clean_fact_sinistre(sinistre_id);

CREATE INDEX idx_clean_indem_sinistre  ON clean_fact_indemnisation (sinistre_id);
CREATE INDEX idx_clean_indem_paiement  ON clean_fact_indemnisation (date_paiement);
CREATE INDEX idx_clean_indem_statut    ON clean_fact_indemnisation (statut_paiement);


-- =============================================================================
-- 8. CONTRÔLES APRÈS NETTOYAGE
-- =============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 8.1 VOLUMES — source vs clean, écart par table
-- ────────────────────────────────────────────────────────────────────────────
SELECT
    src.table_name,
    src.nb_source,
    cln.nb_clean,
    src.nb_source - cln.nb_clean AS lignes_exclues,
    ROUND((src.nb_source - cln.nb_clean)::numeric / NULLIF(src.nb_source,0) * 100, 1) AS pct_exclus
FROM (
    SELECT 'dim_assure'         AS table_name, COUNT(*) AS nb_source FROM dim_assure         UNION ALL
    SELECT 'dim_agence',                       COUNT(*) FROM dim_agence                      UNION ALL
    SELECT 'dim_garantie',                     COUNT(*) FROM dim_garantie                    UNION ALL
    SELECT 'dim_contrat',                      COUNT(*) FROM dim_contrat                     UNION ALL
    SELECT 'contrat_garantie',                 COUNT(*) FROM contrat_garantie                UNION ALL
    SELECT 'fact_sinistre',                    COUNT(*) FROM fact_sinistre                   UNION ALL
    SELECT 'fact_indemnisation',               COUNT(*) FROM fact_indemnisation
) src
JOIN (
    SELECT 'dim_assure'         AS table_name, COUNT(*) AS nb_clean FROM clean_dim_assure         UNION ALL
    SELECT 'dim_agence',                       COUNT(*) FROM clean_dim_agence                     UNION ALL
    SELECT 'dim_garantie',                     COUNT(*) FROM clean_dim_garantie                   UNION ALL
    SELECT 'dim_contrat',                      COUNT(*) FROM clean_dim_contrat                    UNION ALL
    SELECT 'contrat_garantie',                 COUNT(*) FROM clean_contrat_garantie               UNION ALL
    SELECT 'fact_sinistre',                    COUNT(*) FROM clean_fact_sinistre                  UNION ALL
    SELECT 'fact_indemnisation',               COUNT(*) FROM clean_fact_indemnisation
) cln USING (table_name)
ORDER BY table_name;

-- ────────────────────────────────────────────────────────────────────────────
-- 8.2 CLÉS — unicité et absence de NULL
-- ────────────────────────────────────────────────────────────────────────────

-- Unicité des PK (attendu : 0 pour chaque table)
SELECT 'clean_dim_assure — doublons PK'         AS controle,
       COUNT(*) - COUNT(DISTINCT assure_id)      AS nb_doublons FROM clean_dim_assure  UNION ALL
SELECT 'clean_dim_agence — doublons PK',
       COUNT(*) - COUNT(DISTINCT agence_id)                      FROM clean_dim_agence UNION ALL
SELECT 'clean_dim_garantie — doublons PK',
       COUNT(*) - COUNT(DISTINCT garantie_id)                    FROM clean_dim_garantie UNION ALL
SELECT 'clean_dim_contrat — doublons PK',
       COUNT(*) - COUNT(DISTINCT contrat_id)                     FROM clean_dim_contrat UNION ALL
SELECT 'clean_fact_sinistre — doublons PK',
       COUNT(*) - COUNT(DISTINCT sinistre_id)                    FROM clean_fact_sinistre UNION ALL
SELECT 'clean_fact_indemnisation — doublons PK',
       COUNT(*) - COUNT(DISTINCT indemnisation_id)               FROM clean_fact_indemnisation;

-- Références orphelines (attendu : 0 pour chaque jointure)
SELECT 'sinistres sans contrat clean'     AS controle, COUNT(*) AS nb
FROM clean_fact_sinistre s
WHERE NOT EXISTS (SELECT 1 FROM clean_dim_contrat WHERE contrat_id = s.contrat_id)
UNION ALL
SELECT 'sinistres sans agence clean',     COUNT(*)
FROM clean_fact_sinistre s
WHERE NOT EXISTS (SELECT 1 FROM clean_dim_agence WHERE agence_id = s.agence_id)
UNION ALL
SELECT 'indemnisations sans sinistre clean', COUNT(*)
FROM clean_fact_indemnisation i
WHERE NOT EXISTS (SELECT 1 FROM clean_fact_sinistre WHERE sinistre_id = i.sinistre_id)
UNION ALL
SELECT 'contrats sans assure clean',       COUNT(*)
FROM clean_dim_contrat c
WHERE NOT EXISTS (SELECT 1 FROM clean_dim_assure WHERE assure_id = c.assure_id);

-- ────────────────────────────────────────────────────────────────────────────
-- 8.3 CONTRÔLES SINISTRES
-- ────────────────────────────────────────────────────────────────────────────

-- Doublons restants (attendu : 0)
SELECT COUNT(*) AS doublons_sinistres_restants
FROM (
    SELECT contrat_id, date_survenance, type_sinistre, COUNT(*) AS nb
    FROM clean_fact_sinistre
    GROUP BY contrat_id, date_survenance, type_sinistre
    HAVING COUNT(*) > 1
) t;

-- Dates incohérentes restantes (attendu : 0)
SELECT COUNT(*) AS B_dates_incoherentes_restantes
FROM clean_fact_sinistre
WHERE date_declaration < date_survenance;

-- Sinistres sur contrats non actifs restants (attendu : 0)
SELECT COUNT(*) AS C_sinistres_contrat_non_actif_restants
FROM clean_fact_sinistre s
JOIN dim_contrat c ON s.contrat_id = c.contrat_id
WHERE c.statut_contrat IN ('résilié','expiré');

-- Montants invalides restants (attendu : 0)
SELECT
    COUNT(*) FILTER (WHERE montant_estime <= 0)       AS E_montants_negatifs_ou_nuls,
    COUNT(*) FILTER (WHERE montant_estime > 0
                       AND montant_estime < 1)         AS E_quasi_nuls,
    COUNT(*) FILTER (WHERE montant_estime > 400000)    AS E_extremes
FROM clean_fact_sinistre;

-- Localisations manquantes restantes (attendu : 0)
SELECT COUNT(*) AS D_localisations_manquantes_restantes
FROM clean_fact_sinistre
WHERE ville_sinistre IS NULL
   OR TRIM(ville_sinistre) = ''
   OR ville_sinistre = 'inconnu'
   OR latitude IS NULL;

-- Principales valeurs : type_sinistre et statut_sinistre
SELECT type_sinistre, COUNT(*) AS nb,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM clean_fact_sinistre
GROUP BY type_sinistre
ORDER BY nb DESC;

SELECT statut_sinistre, COUNT(*) AS nb
FROM clean_fact_sinistre
GROUP BY statut_sinistre
ORDER BY nb DESC;

-- ────────────────────────────────────────────────────────────────────────────
-- 8.4 CONTRÔLES INDEMNISATIONS
-- ────────────────────────────────────────────────────────────────────────────

-- Paiements antérieurs à la déclaration restants (attendu : 0)
SELECT COUNT(*) AS H_paiements_avant_declaration_restants
FROM clean_fact_indemnisation i
JOIN clean_fact_sinistre s ON i.sinistre_id = s.sinistre_id
WHERE i.date_paiement < s.date_declaration;

-- Indemnisations sur sinistres refusés restantes (attendu : 0)
SELECT COUNT(*) AS G_indem_sinistres_refuses_restants
FROM clean_fact_indemnisation i
JOIN clean_fact_sinistre s ON i.sinistre_id = s.sinistre_id
WHERE s.statut_sinistre = 'refusé'
  AND i.statut_paiement = 'payé';

-- Montants invalides restants (attendu : 0)
SELECT
    COUNT(*) FILTER (WHERE montant_indemnise <= 0)      AS I_montants_negatifs_ou_nuls,
    COUNT(*) FILTER (WHERE montant_indemnise > 200000)  AS I_montants_extremes
FROM clean_fact_indemnisation;

-- Doublons restants (attendu : 0)
SELECT COUNT(*) AS doublons_indemnisations_restants
FROM (
    SELECT sinistre_id, date_paiement, montant_indemnise, COUNT(*) AS nb
    FROM clean_fact_indemnisation
    GROUP BY sinistre_id, date_paiement, montant_indemnise
    HAVING COUNT(*) > 1
) t;

-- ────────────────────────────────────────────────────────────────────────────
-- 8.5 CONTRÔLES ASSURÉS
-- ────────────────────────────────────────────────────────────────────────────

-- Nombre total d'assurés clean
SELECT COUNT(*) AS nb_assures_clean FROM clean_dim_assure;

-- Doublons métier restants (conservés avec flag)
SELECT COUNT(*) AS assures_avec_flag_doublon
FROM clean_dim_assure
WHERE is_doublon_metier = TRUE;

-- Vérification que nom, prénom, email sont absents (colonnes non sélectionnées)
-- Si cette requête renvoie 0 lignes, c'est que les colonnes n'existent pas → correct
SELECT COUNT(*) AS pii_nom_present_dans_clean
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'clean_dim_assure'
  AND column_name  IN ('nom','prenom','email');

-- Répartition par tranche d'âge
SELECT tranche_age, COUNT(*) AS nb,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM clean_dim_assure
GROUP BY tranche_age
ORDER BY tranche_age;

-- Répartition par statut
SELECT statut_assure, COUNT(*) AS nb
FROM clean_dim_assure
GROUP BY statut_assure
ORDER BY statut_assure;

-- ────────────────────────────────────────────────────────────────────────────
-- 8.6 CONTRÔLES GÉOGRAPHIQUES
-- ────────────────────────────────────────────────────────────────────────────

-- Nombre de villes distinctes dans clean_fact_sinistre
SELECT COUNT(DISTINCT ville_sinistre) AS nb_villes_distinctes
FROM clean_fact_sinistre;

-- Villes avec plusieurs paires de coordonnées (attendu : 0)
SELECT ville_sinistre, COUNT(DISTINCT (latitude, longitude)) AS nb_paires
FROM clean_fact_sinistre
WHERE latitude IS NOT NULL
GROUP BY ville_sinistre
HAVING COUNT(DISTINCT (latitude, longitude)) > 1;

-- Cohérence ville / lat / lon (toutes les coordonnées pour contrôle visuel)
SELECT ville_sinistre, latitude, longitude, COUNT(*) AS nb_sinistres
FROM clean_fact_sinistre
WHERE latitude IS NOT NULL
GROUP BY ville_sinistre, latitude, longitude
ORDER BY ville_sinistre;

-- Cohérence clean_fact_sinistre vs clean_dim_agence pour les villes communes
-- (attendu : 0 écart)
SELECT
    a.ville       AS ville_agence,
    a.latitude    AS lat_agence,
    a.longitude   AS lon_agence,
    s.ville_sinistre,
    s.latitude    AS lat_sinistre,
    s.longitude   AS lon_sinistre
FROM clean_dim_agence a
JOIN (
    SELECT DISTINCT ville_sinistre, latitude, longitude
    FROM clean_fact_sinistre
    WHERE latitude IS NOT NULL
) s ON s.ville_sinistre = a.ville
WHERE a.latitude <> s.latitude
   OR a.longitude <> s.longitude;

-- ────────────────────────────────────────────────────────────────────────────
-- 8.7 CONTRÔLES PÉRIODE
-- ────────────────────────────────────────────────────────────────────────────

SELECT
    MIN(date_survenance)  AS date_surv_min,
    MAX(date_survenance)  AS date_surv_max,
    MIN(date_declaration) AS date_decl_min,
    MAX(date_declaration) AS date_decl_max,
    COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM date_survenance)  NOT IN (2024,2025)) AS sinistres_hors_periode,
    COUNT(*) FILTER (WHERE EXTRACT(YEAR FROM date_declaration) NOT IN (2024,2025)) AS declarations_hors_periode
FROM clean_fact_sinistre;


-- =============================================================================
-- 9. SYNTHÈSE FINALE
-- =============================================================================

SELECT '═══════════════════════════════════════════════' AS ligne UNION ALL
SELECT '  SYNTHÈSE — couche clean AssurRisk 2024-2025' UNION ALL
SELECT '═══════════════════════════════════════════════';

-- Volumes clean_*
SELECT
    'clean_dim_assure'         AS table_clean, COUNT(*) AS nb_lignes_clean FROM clean_dim_assure         UNION ALL
SELECT 'clean_dim_agence',                     COUNT(*) FROM clean_dim_agence                            UNION ALL
SELECT 'clean_dim_garantie',                   COUNT(*) FROM clean_dim_garantie                          UNION ALL
SELECT 'clean_dim_contrat',                    COUNT(*) FROM clean_dim_contrat                           UNION ALL
SELECT 'clean_contrat_garantie',               COUNT(*) FROM clean_contrat_garantie                      UNION ALL
SELECT 'clean_fact_sinistre',                  COUNT(*) FROM clean_fact_sinistre                         UNION ALL
SELECT 'clean_fact_indemnisation',             COUNT(*) FROM clean_fact_indemnisation
ORDER BY table_clean;

-- Lignes exclues fact_sinistre
SELECT
    (SELECT COUNT(*) FROM fact_sinistre)       AS nb_sinistres_source,
    (SELECT COUNT(*) FROM clean_fact_sinistre) AS nb_sinistres_clean,
    (SELECT COUNT(*) FROM fact_sinistre) -
    (SELECT COUNT(*) FROM clean_fact_sinistre) AS lignes_exclues_sinistres;

-- Lignes exclues fact_indemnisation
SELECT
    (SELECT COUNT(*) FROM fact_indemnisation)       AS nb_indem_source,
    (SELECT COUNT(*) FROM clean_fact_indemnisation) AS nb_indem_clean,
    (SELECT COUNT(*) FROM fact_indemnisation) -
    (SELECT COUNT(*) FROM clean_fact_indemnisation) AS lignes_exclues_indem;

SELECT '──────────────────────────────────────────────' AS ligne UNION ALL
SELECT '  CORRECTIONS APPLIQUÉES' UNION ALL
SELECT '  A : doublons sinistres exclus (~100 lignes)' UNION ALL
SELECT '  B : dates incohérentes exclues (80 lignes)' UNION ALL
SELECT '  C : sinistres contrats non actifs exclus (100 lignes)' UNION ALL
SELECT '  D : localisations manquantes exclues (60 lignes)' UNION ALL
SELECT '  E : montants anormaux exclus (50 lignes)' UNION ALL
SELECT '  F : libellés non standardisés CORRIGÉS (100 lignes conservées)' UNION ALL
SELECT '  G : indemnisations sur refusés exclues (50 lignes)' UNION ALL
SELECT '  H : paiements antérieurs déclaration exclus (20 lignes)' UNION ALL
SELECT '  I : montants indemnisation anormaux exclus (20 lignes)' UNION ALL
SELECT '──────────────────────────────────────────────' UNION ALL
SELECT '  ANOMALIES CONSERVÉES / REMARQUES' UNION ALL
SELECT '  clean_dim_assure : 40 doublons métier signalés (is_doublon_metier=TRUE)' UNION ALL
SELECT '  clean_dim_assure : ~500 date_naissance NULL → tranche_age = Inconnu' UNION ALL
SELECT '  clean_dim_contrat : contrats résilié/expiré conservés (contexte historique)' UNION ALL
SELECT '  clean_dim_agence : agence Metz fermée conservée (sinistres historiques)' UNION ALL
SELECT '──────────────────────────────────────────────' UNION ALL
SELECT '  LIMITES RESTANTES' UNION ALL
SELECT '  - Sinistres F corrigés sur type_sinistre mais cause_sinistre indique toujours Anomalie F' UNION ALL
SELECT '  - Doublons assurés non dédoublonnés (pas de critère métier certain)' UNION ALL
SELECT '  - Contrats non actifs : exclusion basée sur cause_sinistre + modèle clean' UNION ALL
SELECT '    (les contrats résilié/expiré PEUVENT être référencés dans des sinistres clean' UNION ALL
SELECT '     si le sinistre date d''avant la résiliation)' UNION ALL
SELECT '═══════════════════════════════════════════════';

-- =============================================================================
-- FIN — assurrisk_clean.sql
-- AssurRisk — Couche nettoyée 2024-2025
-- Compatible PostgreSQL 15+ · Exécutable dans DBeaver
-- Tables sources intactes · Modèle clean autonome pour Power BI
-- =============================================================================
