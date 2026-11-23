#ce script permet la creation des tables dans la base de données ASSURR et l'ajoute des données meteo

import psycopg2
import json
import pandas as pd
import time
from getpass import getpass
import io
import os

mot_de_passe = getpass("Mot de passe PostgreSQL : ")
connexion = psycopg2.connect(host="localhost", port=5432, dbname="ASSURR",
user="postgres", password=mot_de_passe)

connexion.autocommit = True

curseur = connexion.cursor()
print("connexion ouverte")


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

etapes_avant= [
("01_init.sql","Reinitialiser la base"),
("02_clean.sql","Construire la couche propre"),
("03_tables_meteo.sql", "Creer les tables qui attendent la meteo"),

]

journal = []
for fichier, libelle in etapes_avant:
    debut = time.time()
    requete = open("sql/" + fichier, encoding="utf-8").read()
    curseur.execute(requete)
    duree = round(time.time() - debut, 1)
    journal.append([fichier, libelle, "SQL", duree])
    print(" [SQL]", libelle, "-", duree, "s")

# chargement meteo dans table meteo_assurrisk
tampon = io.StringIO()
meteo.to_csv(tampon, index=False, header=False)
tampon.seek(0)
curseur.copy_expert("COPY meteo_assurrisk FROM STDIN WITH (FORMAT csv)", tampon)
print(" [PYTHON]", len(meteo), "lignes de meteo chargees")

#chargement villes_coordonnees_meteo.csv dans table ville coordonnées 

meteo_ville = pd.read_csv("donnees/villes_coordonnees_meteo.csv", encoding="utf-8")
tampon = io.StringIO()
meteo_ville.to_csv(tampon, index=False, header=False)
tampon.seek(0)
curseur.copy_expert("COPY villes_coordonnees_meteo FROM STDIN WITH (FORMAT csv)", tampon)
print(" [PYTHON]", len(meteo_ville), "lignes de meteo chargees")

print(" [SUCCESS] lignes météo injectées dans les tables PostgreSQL 'meteo_assurrisk_ville' et meteo_assurrisk")

etapes_après= [
("04_rattachement.sql", "Rattachement des villes au donnees meteo"),
("05_croisement.sql", "Croisement donnees meteo"),

]

for fichier, libelle in etapes_après:
    debut = time.time()
    requete = open("sql/" + fichier, encoding="utf-8").read()
    curseur.execute(requete)
    duree = round(time.time() - debut, 1)
    journal.append([fichier, libelle, "SQL", duree])
    print(" [SQL]", libelle, "-", duree, "s")

#exporter les données dans un fichier CSV dans le dossier données
os.makedirs("sorties", exist_ok=True)
#controles 
with open("sql/06_controles.sql", encoding="utf-8") as f:
 requete= f.read()
 #2. Exécuter la requête et récupérer directement le résultat dans un DataFrame Pandas
controles= pd.read_sql(requete,connexion)  
controles.to_csv("sorties/controles.csv", sep=";", decimal=",",
index=False, encoding="utf-8-sig")
print(" [SUCCESS] Le fichier de contrôle a été exporté avec succès !")

#journal_pipeline
suivi = pd.DataFrame(journal, columns=["fichier", "etape", "outil", "secondes"])
suivi.to_csv("sorties/journal_pipeline.csv", sep=";", decimal=",",
index=False, encoding="utf-8-sig")
print(" [SUCCESS] Le fichier de journal_pipeline a été exporté avec succès !")


verification = pd.read_sql("SELECT count(*) AS n FROM clean_fact_sinistre", connexion)
print(" controle : clean_fact_sinistre =", verification["n"][0], "lignes")




