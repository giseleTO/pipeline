import psycopg2
import json
import pandas as pd
import time
from getpass import getpass
import psycopg2.extras # Indispensable pour l'insertion rapide en mass
import io



mot_de_passe = getpass("Mot de passe PostgreSQL : ")
connexion = psycopg2.connect(host="localhost", port=5432, dbname="ASSURRISKP",
user="postgres", password=mot_de_passe)

connexion.autocommit = True

curseur = connexion.cursor()
print("connexion ouverte")
#requete = open("sql/01_init.sql", encoding="utf-8").read()
#curseur.execute(requete)
#print("base reinitialisee")

meteo_brute = json.load(open("donnees/meteo_30_villes.json", encoding="utf-8"))
print(type(meteo_brute)) # une LISTE
print(len(meteo_brute)) # de combien d'objets ?
print(meteo_brute[0].keys()) # que contient le premier ?

morceaux = []

for localisation in meteo_brute:
   tableau = pd.DataFrame(localisation["daily"])
   tableau["latitude"] = localisation["latitude"]
   tableau["longitude"] = localisation["longitude"]
   morceaux.append(tableau)


# Concaténation de tous les morceaux dans un grand DataFrame propre
meteo = pd.concat(morceaux, ignore_index=True)
print(meteo.shape)

curseur.execute("""
    DROP TABLE IF EXISTS meteo_assurrisk_ville;
    CREATE TABLE meteo_assurrisk_ville (
        time DATE,
        weather_code INT,
        temperature_2m_max FLOAT,
        temperature_2m_min FLOAT,
        latitude FLOAT,
        longitude FLOAT
    );
""")

# 2. Préparation des données sous forme de liste de tuples
colonnes = ["time", "weather_code", "temperature_2m_max", "temperature_2m_min", "latitude", "longitude"]
valeurs = [tuple(x) for x in meteo[colonnes].to_numpy()]

# 3. Insertion groupée ultra-rapide
psycopg2.extras.execute_values(
    curseur,
    """
    INSERT INTO meteo_assurrisk_ville (time, weather_code, temperature_2m_max, temperature_2m_min, latitude, longitude)
    VALUES %s
    """,
    valeurs
)
print(" [SUCCESS] Données météo injectées dans la table PostgreSQL 'meteo_assurrisk_ville' via psycopg2.")


etapes= [
("01_init.sql","Reinitialiser la base"),
("02_clean.sql","Construire la couche propre"),
("03_tables_meteo.sql", "Creer les tables qui attendent la meteo"),
("04_rattachement.sql", "Rattachement des villes au donnees meteo"),
("05_croisement.sql", "Croisement donnees meteo"),

]

journal = []
for fichier, libelle in etapes:
    debut = time.time()
    requete = open("sql/" + fichier, encoding="utf-8").read()
    curseur.execute(requete)
    duree = round(time.time() - debut, 1)
    journal.append([fichier, libelle, "SQL", duree])
    print(" [SQL]", libelle, "-", duree, "s")
    
tampon = io.StringIO()
meteo.to_csv(tampon, index=False, header=False)
tampon.seek(0)
curseur.copy_expert("COPY meteo_assurrisk FROM STDIN WITH (FORMAT csv)", tampon)
print(" [PYTHON]", len(meteo), "lignes de meteo chargees")


suivi = pd.DataFrame(journal, columns=["fichier", "etape", "outil", "secondes"])
suivi.to_csv("sorties/journal_pipeline.csv", sep=";", decimal=",",
index=False, encoding="utf-8-sig")

verification = pd.read_sql("SELECT count(*) AS n FROM clean_fact_sinistre", connexion)
print(" controle : clean_fact_sinistre =", verification["n"][0], "lignes")


