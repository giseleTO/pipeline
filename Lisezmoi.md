Ce pipeline exécute les scripts SQL d'initialisation et de nettoyage sur la base AssurRisk[cite: 28, 32], puis charge les données météo JSON et CSV via Python[cite: 28].
Il croise ensuite les données météorologiques avec les sinistres, lance les contrôles qualité et exporte les résultats ainsi que le journal d'exécution dans `sorties/`[cite: 28, 32].
Pour le lancer, place-toi dans le dossier du projet et active l'environnement virtuel avec `.venv\Scripts\activate`[cite: 68].
Exécute ensuite `python pipeline.py` et saisis ton mot de passe PostgreSQL à l'invite `getpass`[cite: 28, 77].
Le script `explorer.py` permet ensuite d'explorer la table `fact_sinistre_meteo` avec pandas et psycopg2[cite: 54].