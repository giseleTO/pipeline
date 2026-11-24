Ce pipeline exécute les scripts SQL d'initialisation et de nettoyage sur la base AssurRisk[cite: 28, 32], puis charge les données météo JSON et CSV via Python[cite: 28].
Il croise ensuite les données météorologiques avec les sinistres, lance les contrôles qualité et exporte les résultats ainsi que le journal d'exécution dans `sorties/`[cite: 28, 32].
Pour le lancer, place-toi dans le dossier du projet et active l'environnement virtuel avec `.venv\Scripts\activate`[cite: 68].
Exécute ensuite `python pipeline.py` et saisis ton mot de passe PostgreSQL à l'invite `getpass`[cite: 28, 77].
Le script `explorer.py` permet ensuite d'explorer la table `fact_sinistre_meteo` avec pandas et psycopg2[cite: 54].



### Première partie : Casser le code sans commiter, puis restaurer

1. Suppression/altération de lignes dans `pipeline.py`, suivie de l'exécution du script, qui a bien planté avec une erreur Python.


2. Contrôle avec Git: `git status` a signalé `pipeline.py` comme modifié (*modified*), et `git diff` a affiché précisément les lignes supprimées ou modifiées par rapport au dernier commit.


3. Restauration : La commande `git restore pipeline.py` a annulé les modifications locales et ramené le fichier à l'état du dernier commit sain.


4. Résultat : Le pipeline s'est relancé normalement avec les six contrôles valides, et `git status` a affiché `nothing to commit, working tree clean`.



Deuxième partie : Casser le code et commiter avant de restaurer

1. Modification et commit : Après avoir volontairement cassé `explorer.py`, la modification a été enregistrée dans l'historique via `git commit -m "version cassee, exercice"` (vérifié avec `git log --oneline`).


2. Tentative de restauration: L'exécution de `git restore explorer.py` n'a rien réparé et le script a continué de planter au lancement.


3. Observation et conclusion : `git restore` ramène toujours un fichier à l'état du **dernier commit** ; comme le code cassé avait été commité, c'est cette version cassée qui est devenue la référence. Il faut donc toujours tester et vérifier que son code fonctionne **avant** de commiter.
