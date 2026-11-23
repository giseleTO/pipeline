# -*- coding: utf-8 -*-
# =====================================================================
# Rappel du 22 octobre — la liste, le dictionnaire, la boucle
#
# Ce fichier ne se connecte a RIEN : ni base, ni internet, ni pandas.
# Il tourne meme si votre installation Python est cassee ce matin.
#
# Lancez-le, lisez la sortie a cote du fichier, puis modifiez-le.
# =====================================================================

print("=" * 58)
print(" 1. LA LISTE — plusieurs valeurs, dans l'ordre")
print("=" * 58)

etapes = ["Reinitialiser la base",
          "Construire la couche propre",
          "Charger la meteo",
          "Croiser sinistres et meteo"]

print("la liste entiere :", etapes)
print("combien          :", len(etapes))
print("la premiere      :", etapes[0])      # on compte a partir de ZERO
print("la derniere      :", etapes[-1])

etapes.append("Controler le resultat")
print("apres append     :", len(etapes), "etapes")


print()
print("=" * 58)
print(" 2. LE DICTIONNAIRE — une cle, une valeur")
print("=" * 58)

fichiers = {"Reinitialiser la base":       "assurrisk_init_2024_2025.sql",
            "Construire la couche propre": "assurrisk_clean.sql",
            "Croiser sinistres et meteo":  "croisement_meteo.sql"}

print("combien de paires :", len(fichiers))
print("fichier pour 'Construire la couche propre' :",
      fichiers["Construire la couche propre"])
print("toutes les cles   :", list(fichiers.keys()))


print()
print("=" * 58)
print(" 3. LA BOUCLE — faire la meme chose pour chaque valeur")
print("=" * 58)

print("\n-- sur une liste --")
for etape in etapes:
    print("   a faire :", etape)

print("\n-- sur un dictionnaire : il faut .items() --")
for etape, fichier in fichiers.items():
    print("  ", etape, "->", fichier)


print()
print("=" * 58)
print(" 4. CE QUE LA BOUCLE REMPLACE")
print("=" * 58)

print("\nSANS boucle, il faudrait ecrire une ligne par etape :")
print("   print(etapes[0])")
print("   print(etapes[1])")
print("   print(etapes[2])   ... et ainsi de suite")

print("\nAVEC la boucle, on ecrit la ligne UNE fois.")
print("-> Ajouter une 6e etape coute UNE ligne dans la liste,")
print("   et rien du tout dans la boucle.")

print()
print("Cette semaine, chaque 'etape' sera un fichier .sql")
print("que Python ira executer. La structure, elle, ne change pas.")
