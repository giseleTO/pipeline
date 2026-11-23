Ce que fait la pipeline :

le but de la pipeline est d'automatiser les différentes étapes qui menent à la création des tables des dimensions et de la fait dans la base de données ASSURRISK et trois tables supplémentaires pour acceuillir les données météo de l'API.
la pipeline permet egalement d'aller chercher les données météo classés dans un fichier json et les données des villes dans un ficher CSV et de les lire et les convertir dans Pandas et les injecter dans les tables de la base situés dans DBeaver  

ce qu'elle produit:
la pipeline produits toutes les tables de la base de données remplies, il génère les fichier de sorties "journal_pipeline" qui repertorie les etapes de lancement  et "controles" qui verifier la qualité de la table des faits consolidées de données météo de l'API. 

ce qu’elle contrôle ;
Elle controle le type et les contenu, des données météo contenu dans le fichier Json (nombres de lignes, colonnes)
elle controle  le nombre de lignes chargées dans DBeaver, le temps d'execution des diffrentes étapes et la qualite des tables importées

ce qui se passe si elle échoue, et comment on le verrait
si la pipeline echoue, il ne se passer rien
la base de données crées est vide, et les fichiers de sortie ne sont pas généres.
on le voit à l'apparution d'un message d'erreur qui indique la ligne defectueuse dans la plupart des cas.