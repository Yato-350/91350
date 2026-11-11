# Cadre légal, licences et attributions

Ce document n'est pas un avis juridique. Il liste ce que le projet utilise, ce qu'il doit
créditer, et ce qui doit être **validé par un juriste avant toute sortie commerciale**.

## Fiction

Le jeu est une œuvre de fiction. Le régime (« la Concorde nationale », nom de travail),
ses dirigeants, ses symboles, ses slogans et l'IA « GRAND FRÈRE » sont inventés. Aucun
parti, dirigeant, élu, artiste, habitant ni célébrité réels n'y figurent. Aucune marque
ni aucun logo réels : ils sont remplacés par des équivalents fictifs.

Les communes, quartiers et lieux publics portent leurs vrais noms (toponymes) et sont
montrés avec respect ; les personnages qui y vivent sont tous imaginaires.

## Licences des composants

| Composant | Licence | Distribué avec le jeu ? | Obligation |
|---|---|---|---|
| Godot Engine 4.7.2 | MIT (+ licences tierces du moteur) | Oui | Reproduire la licence : panneau des crédits (F1), `Engine.get_license_text()` |
| Police Tiny5 | SIL Open Font License 1.1 | Oui | Joindre la licence (`assets/fonts/Tiny5-OFL.txt`) ; ne pas vendre la police seule |
| GUT 9.7.1 | MIT | Non (exclu de l'export) | Licence conservée dans `addons/gut/` |
| Dialogue Manager 4.x (à partir de M1) | MIT | Oui | Créditer et joindre la licence |
| gdtoolkit, jsonschema, pytest | MIT | Non (outils) | — |

Le **code et le contenu du jeu** ne sont pas sous licence libre : en l'absence de fichier
de licence, tous les droits sont réservés, même si le dépôt est public.

## OpenStreetMap (à partir de M1)

- Les données cartographiques viennent d'OpenStreetMap, sous licence **ODbL**.
- Attribution obligatoire, sur l'écran de démarrage et dans les crédits :
  « © les contributeurs d'OpenStreetMap — données sous licence ODbL ».
- Les **données géographiques dérivées** (`tools/osm_import/data/`) restent sous ODbL et
  sont accompagnées de leur fichier de licence. Les scènes et meshes qui en sont tirés
  sont une « œuvre produite » : elle doit créditer OpenStreetMap.
- L'API Overpass a une politique d'usage : cache local, pas de requêtes en boucle.
- Option non utilisée à ce jour : BD TOPO de l'IGN (licence ouverte Etalab 2.0, à créditer).

## Œuvres protégées

- **La Grande Borne** (Émile Aillaud, 1967-1971) : son architecture, ses fresques en
  mosaïque et ses sculptures sont des œuvres protégées. L'exception de panorama française
  exclut tout usage commercial. Règle du projet : **s'inspirer et styliser, ne jamais
  copier à l'identique** une fresque ou une sculpture.
- Même prudence pour toute œuvre visible dans l'espace public des autres zones.

## Respect

- Lieux de culte, écoles et lieux de soins sont des zones neutres : ni combat ni cible.
- Aucune caricature fondée sur l'origine ou la religion ; aucun rôle (trafiquant, indic…)
  n'est lié à une origine ou une religion.
- Tous les personnages impliqués dans la violence, les armes ou les trafics sont majeurs.
- Armes et gadgets sont des objets de jeu avec des statistiques : aucune instruction
  réelle de fabrication.

## Données personnelles

Le jeu ne collecte aucune donnée personnelle. Les sauvegardes restent sur la machine du
joueur (ou dans le stockage local du navigateur pour la version web).

## À faire valider par un juriste avant la sortie commerciale

1. L'usage des vrais noms de communes, de quartiers et de lieux dans une fiction
   politique, et la représentation d'un établissement pénitentiaire existant transformé
   en « Centre de Rééducation ».
2. La représentation stylisée de la Grande Borne (architecture reconnaissable).
3. Les noms d'infrastructures (ligne de train, autoroute, aqueduc) : rester sur des
   désignations génériques là où un nom est une marque déposée.
4. La conformité ODbL de la chaîne « données dérivées → scènes du jeu » et le texte
   exact des attributions.
5. Le titre du jeu (recherche d'antériorité, dépôt de marque éventuel).
6. La classification du contenu (violence, armes) : questionnaire Steam, IARC.
7. Les licences des assets externes ajoutés d'ici la sortie (`assets/ASSETS.md`).
