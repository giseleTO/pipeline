import pandas as pd
import psycopg2
import warnings
from getpass import getpass

warnings.filterwarnings("ignore", message="pandas only supports SQLAlchemy")
pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 30)

mot_de_passe = getpass("Mot de passe PostgreSQL : ")
connexion = psycopg2.connect(host="localhost", port=5432, dbname="ASSURR",
user="postgres", password=mot_de_passe)

df = pd.read_sql("SELECT * FROM fact_sinistre_meteo", connexion)
df["montant_estime"] = df["montant_estime"].astype(float)
df["franchise"] = df["franchise"].astype(float)
df["date_survenance"] = pd.to_datetime(df["date_survenance"])
df["date_declaration"] = pd.to_datetime(df["date_declaration"])

#1. Combien de lignes et combien de colonnes compte la table ?
print(df.shape)
#2. Y a-t-il des valeurs manquantes ? Si oui, dans quelles colonne
print(df.isna().sum())
#3. Quel est le montant le plus faible de la table, et le plus élevé ?
print("le montant le plus faible")
print(df["montant_estime"].min())
print("le montant le plus élevé")
print(df["montant_estime"].max())
#4. Combien de types de sinistre différents y a-t-il ?
print("type de sinistre")
print(df["type_sinistre"].value_counts())
#5. Quelle est la moyenne et la médiane de la colonne franchise ?
print("moyenne et mediane colonne franchise")
print(df["franchise"].agg(['median','mean']))
#Faites le même groupby sur la colonne montant_estime au lieu de franchise .
print("moyenne et mediane colonne montant_estime apr type de sinistre")
print(df.groupby("type_sinistre")["montant_estime"].agg(['median','mean']))
#QUESTION2
# dégâts des eaux
#parts des dégats des eaux sur le total
print("repartition  des types de sinistre sur total des sinistre sur toutes les villes")
print(df["type_sinistre"].value_counts(normalize=True).mul(100).round(1))
##ecarts entre les villes 
print("repartition  des types de sinistre à Lille")
lille = df[df["ville_sinistre"] == "Lille"]
print(lille["type_sinistre"].value_counts(normalize=True).mul(100).round(1))

print("repartition  des types de sinistre à Nantes")
Nantes = df[df["ville_sinistre"] == "Nantes"]
print(Nantes["type_sinistre"].value_counts(normalize=True).mul(100).round(1))

print("repartition  des types de sinistre à Paris")
Paris = df[df["ville_sinistre"] == "Paris"]
print(Paris["type_sinistre"].value_counts(normalize=True).mul(100).round(1))

print("repartition  des types de sinistre à Marseille")
Marseille = df[df["ville_sinistre"] == "Marseille"]
print(Marseille["type_sinistre"].value_counts(normalize=True).mul(100).round(1))



print("repartition des sinistres par villes")
part = (df.groupby("ville_sinistre")["type_sinistre"]
.apply(lambda s: s.value_counts(normalize=True).mul(100).round(1)))


print("part")
part = (df.groupby("ville_sinistre")["type_sinistre"]
.apply(lambda s: s.value_counts(normalize=True).mul(100).round(1)))
print(part.xs("Dégât des eaux", level=1).describe())

print(" le minimum et le maximum de la part du dégât des eaux.")
print(part.xs("Dégât des eaux", level=1).agg(['min', 'max']))

#isoler le mois d'octobre 2025
octobre = df[(df["date_survenance"] >= "2025-10-01") &
 (df["date_survenance"] <= "2025-10-31")]
reste = df[~df.index.isin(octobre.index)]
print("nb de sinistre et Octobre 2025 et nombre de sinistre sur le reste")
print(len(octobre), len(reste))
##
##"montant estimé des sinsitres par type de sinistre sur la periode d'octobre 2025
print("moyenne et médiane des montants estimés des sinitres par type de sinistre sur la periode d'octobre 2025")
print(octobre.groupby("type_sinistre")["montant_estime"].agg(['median','mean']))


print("repartition  des types de sinistre sur total des sinistre sur toutes les villes en octobre")
print(octobre["type_sinistre"].value_counts(normalize=True).mul(100).round(1))


print("repartition  des types de sinistre sur total des sinistre sur toutes les villes pour le reste de la periode")
print(reste["type_sinistre"].value_counts(normalize=True).mul(100).round(1))


print("les precipitations en octobre")
print(octobre["precipitation_sum"].agg(["mean","max"]))

print("les precipitations pour le reste")
print(reste["precipitation_sum"].agg(["mean","max"]))

print("les rafales de vent pour octobre")
print(octobre["wind_gusts_10m_max"].agg(["mean","max"]))

print("les rafales de vent pour reste")
print(reste["wind_gusts_10m_max"].agg(["mean","max"]))

print("les temperatures pour octobre")
print(octobre["temperature_2m_min"].agg(["mean","min"]))

print("les temperatures pour reste")
print(reste["temperature_2m_min"].agg(["mean","min"]))
##moyenne et mediane des précipitations 
## compter par jour
print("describe par jour octobre")
par_jour = octobre.groupby(octobre["date_survenance"].dt.day).size()
print(par_jour.describe())

print("date_survenance de debut et fin octobre")
print(octobre["date_survenance"].min(), octobre["date_survenance"].max())
##comparaison par region 
print("repartition octobre")
part_octobre = (octobre.groupby("region_sinistre")["type_sinistre"]
.apply(lambda s: s.value_counts(normalize=True).mul(100).round(1)))
print(part_octobre)

print("repartition reste")
part_reste = (reste.groupby("region_sinistre")["type_sinistre"]
.apply(lambda s: s.value_counts(normalize=True).mul(100).round(1)))
print(part_reste)

#propre enquete
#etape 2 les six commandes 
#region_sinistre 

print("value counts")
print(df["region_sinistre"].value_counts())
print("describe")
print(df["region_sinistre"].describe())
print("colonnes NULL")
print(df["region_sinistre"].isna().sum())
print("size")
print(df.groupby("region_sinistre").size())


print("value counts")
print(df.groupby("region_sinistre")["montant_estime"].value_counts())
print("describe")
print(df.groupby("region_sinistre")["montant_estime"].describe())
print("le montant NULL par region")#2. Y a-t-il des valeurs manquantes ? Si oui, dans quelles colonne
print("le montant le plus faible par region")
print(df.groupby("region_sinistre")["montant_estime"].min())
print("le montant le plus élevé par region")
print(df.groupby("region_sinistre")["montant_estime"].max())
print("colonnes NULL")
print(df.groupby("region_sinistre")["montant_estime"].apply(lambda s: s.isna().sum()))
print("size")
print(df.groupby("region_sinistre")["montant_estime"].size())

print("delai de declaration")
delai = (df["date_declaration"] - df["date_survenance"]).dt.days
print(delai.describe())

