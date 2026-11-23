lundi
Exercice 3 — Vous le refaites
Trois questions dans votre cahier : 1. Combien de temps a pris
l’exécution ? 2. Qu’est-ce qui apparaît à l’écran, et qu’est-ce qui n’apparaît
pas ? 3. Si vous retirez la ligne connexion.autocommit = True , que se passe-til
? (Essayez, puis remettez-la.)

l'execution n'a pris de quelques secondes. ce qui apparait à l'écran c'est les message qui ont été inscrit dans le script pour signaler la fin des tâches. Si on retire le lignes autocommit alors le script s'execute mais les tables ne sont pas crées dans la base de données 

Exercice 4 — Du JSON au tableau
Les questions, et elles comptent plus que le code : 1. meteo.shape
donne deux nombres. Lequel est le nombre de lignes ?
le premier correspond au nombre lignes  21930, et le nombre second au nombre colonnes 8.

 Vérifiez-le, ne le
devinez pas.
cela correspond au resultat trouvé dans le brief 10 
 2 Vous attendiez-vous à ce nombre ? 30 villes × combien de
jours ?
cela correspond au produit du nombres de villes (30) par le nombre de jour le la période d'observation 731 jours (2 ans)
 Qu’est-ce que morceaux.append(tableau) fait exactement ? 
 le morceaux.append permet de relier la longitude et latitude aux tables 'Daily'
 Et
pourquoi morceaux est-il créé avant la boucle ?
Il est créé avant la boucle pour avoir des données complètes 

Mardi
Exercice 1 — Ranger et numéroter 
La question, et elle n’est pas technique : pourquoi 04_rattachement.sql
ne peut-il pas tourner avant que la météo soit chargée ? Écrivez votre
réponse.

l'étape 04_rattachment ne peut pas tourner avant le chargement de la météo parce que les données météo doivent être rattachés avant  de faire les jointures

Exercice 2 — La liste et la boucle
l'ajoute de la quatrieme étapes ne necessite l'ajout que d'une seule ligne

Et celle-ci : qu’est-ce qui se passerait si on lançait 02_clean.sql avant
01_init.sql ? Essayez. Lisez l’erreur. C’est une bonne erreur à avoir vue une
fois.
on ne peut pas lancer l'étapes 02_clean avant 01_init car cette derniere contient les requêtes pour vla crétion de toutes les tables et pas seulement celle qui contiennent des anomalies comme c'est le cas pour le script contenu dans 02_clean

Exercice 4 — Le journal : chaque étape dit ce qu’elle fait 


 exercise 1 jeudi

 après l'import la table contient 21930 lignes comme prévu.
 le fichier comporte 31 lignes car il contient une ligne inconnu NULL
 La ligne de trop n'est donc pas nécessaire 
  Exercice 2

  Ce que doit faire le cript avant d'appeler l'API test de créer les tables de la base de donnée.
  les tables de dimension et la table de faits en version brute et en version clean. 
  il doit créer 3 autres tables 
  - meteo_assurrisk_ville
  - meteo_assurrisk, qui contient les données météo extraite du fichier json ( chargé dans une variable meteo_brute  extraite de fichier meteo_30_villes.json qu'il va chercher dans le dossier données). le script dois injecter ces données dans le table grace à un tampon  

  - villes_coordonnees_meteo, qui contient les données extraitent du fichier CSV villes_coodonnees_meteo. Le script permet de chercher dans le dossier Données et les injecter dans la table dans Dbeaver 

  La garde 

  la garde est inséerée dans le script pour lui signaler de ne lancer un appel vers l'API que si le fichier n'est pas présent car si toute la classe execute le script en même temps le nombre d'appel maximun vers l'API sera atteint.

  exercice 3
  Dans ce cas on est dans l'obligation de couper la boucle en deux car l'etape 3 table meteo intervient avant l'inr=troduction des données météo notre première étape, dois doinc se terminer à la fin de cette phase 



