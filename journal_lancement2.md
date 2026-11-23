second lancement

 <class 'list'>
30
dict_keys(['latitude', 'longitude', 'daily'])
(21930, 8)
 [SQL] Reinitialiser la base - 54.5 s
 [SQL] Construire la couche propre - 12.3 s
 [SQL] Creer les tables qui attendent la meteo - 0.0 s
 [PYTHON] 21930 lignes de meteo chargees
 [PYTHON] 21930 lignes de meteo chargees
 [SUCCESS] lignes météo injectées dans les tables PostgreSQL 'meteo_assurrisk_ville' et meteo_assurrisk
 [SQL] Rattachement des villes au donnees meteo - 0.1 s
 [SQL] Croisement donnees meteo - 0.1 s
c:\Users\tshog\OneDrive\Documents\BRIEF 12 PYTHON\demarrage-6af0e5274cfbd513684456\pipeline.py:92: UserWarning: pandas only supports SQLAlchemy connectable (engine/connection) or database string URI or sqlite3 DBAPI2 connection. Other DBAPI2 objects are not tested. Please consider using SQLAlchemy.
  controles= pd.read_sql(requete,connexion)
 [SUCCESS] Le fichier de contrôle a été exporté avec succès !
 [SUCCESS] Le fichier de journal_pipeline a été exporté avec succès !
c:\Users\tshog\OneDrive\Documents\BRIEF 12 PYTHON\demarrage-6af0e5274cfbd513684456\pipeline.py:104: UserWarning: pandas only supports SQLAlchemy connectable (engine/connection) or database string URI or sqlite3 DBAPI2 connection. Other DBAPI2 objects are not tested. Please consider using SQLAlchemy.
  verification = pd.read_sql("SELECT count(*) AS n FROM clean_fact_sinistre", connexion)
 controle : clean_fact_sinistre = 12098 lignes