import psycopg2
import json
import pandas as pd
import time
from getpass import getpass
import io
import os


def tracer_etape(fichier, libelle, outil, duree):
  journal.append([fichier, libelle, outil, duree, "ok"])
  print(f" [{outil}] {libelle} - {duree} s")  
#1 le nom donné à la fonction tracer etape fait refernce à ce que fait la fonction, elle delimite les etapes informrme sur la
#durée d'execution et donne le nom du fichier crée
#2 les erreurs etaient liés à la position de la fonction dans le script, les variables qu'elle appellent doivent être definis avant l'appel
# de la fonction 
def jouer_sql (fichier,libelle):
    debut = time.time()
    requete = open("sql/" + fichier, encoding="utf-8").read()
    curseur.execute(requete)
    duree = round(time.time() - debut, 1)
    tracer_etape(fichier, libelle, "SQL", duree)
    

def envoi_table(curseur, df, nom_table):
    tampon = io.StringIO()
    df.to_csv(tampon, index=False, header=False)
    tampon.seek(0)
    curseur.copy_expert(f"COPY {nom_table} FROM STDIN WITH (FORMAT csv)", tampon)
    print(" [PYTHON]", len(df), "lignes de meteo chargees")    

def export_csv(df,fichier):
    df.to_csv(
       "sorties/"+ fichier, sep=";", decimal=",",
       index=False, encoding="utf-8-sig"
       )
    print("[SUCCESS] Le fichier", fichier, "a été exporté avec succès !") 

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
    jouer_sql (fichier,libelle)

# chargement meteo dans table meteo_assurrisk

envoi_table(curseur, meteo, "meteo_assurrisk")

#chargement villes_coordonnees_meteo.csv dans table ville coordonnées 
meteo_ville = pd.read_csv("donnees/villes_coordonnees_meteo.csv", encoding="utf-8")
envoi_table(curseur, meteo_ville, "villes_coordonnees_meteo")
print(" [SUCCESS] lignes météo injectées dans les tables PostgreSQL 'meteo_assurrisk_ville' et meteo_assurrisk")

etapes_après= [
("04_rattachement.sql", "Rattachement des villes au donnees meteo"),
("05_croisement.sql", "Croisement donnees meteo"),

]

for fichier, libelle in etapes_après:
    jouer_sql (fichier,libelle)

#exporter les données dans un fichier CSV dans le dossier données
os.makedirs("sorties", exist_ok=True)
#controles 
with open("sql/06_controles.sql", encoding="utf-8") as f:
 requete= f.read()
 #2. Exécuter la requête et récupérer directement le résultat dans un DataFrame Pandas
controles= pd.read_sql(requete,connexion)  
export_csv(controles,"controles.csv")

#journal_pipeline
suivi = pd.DataFrame(journal, columns=["fichier", "etape", "outil", "secondes","statut"])
export_csv(suivi, "journal_pipeline.csv")

verification = pd.read_sql("SELECT count(*) AS n FROM clean_fact_sinistre", connexion)
print(" controle : clean_fact_sinistre =", verification["n"][0], "lignes")
