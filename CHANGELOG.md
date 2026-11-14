# Journal des modifications

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet
suit le [versionnage sémantique](https://semver.org/lang/fr/) (`0.x` pendant toute la
phase de test).

## [Non publié]

### Ajouté

- Les paliers de la tour suivent le plan d'évacuation d'un étage des Sablons : long
  couloir, escalier en colimaçon dans sa cage, ascenseur en face, gaines techniques en
  bois, cinq logements, fenêtre au bout du couloir.
- L'appartement d'Akan devient un F4 : entrée, cuisine avec banquette d'angle, séjour
  double, deux chambres, WC, salle de bain carrelée de bleu, cellier ; 22 meubles voxel.
- Les intérieurs peuvent avoir un sol et des murs par pièce, des fenêtres, et des meubles
  collés aux murs.

## [0.1.0] — M1 « La tour » (acte 1 jouable)

### Ajouté

- Grigny 2 depuis OpenStreetMap, rendue fidèle : trottoirs, parkings et voitures, 264
  arbres, lampadaires allumés la nuit, clôtures, entrées réelles des immeubles, façades
  détaillées (loggias, linge, paraboles, tags).
- La tour d'Akan : appartement, paliers du 11e et du 7e, hall, local à vélos, toit ; la
  salle de boxe de la maison de quartier.
- 43 personnages générés depuis leur fiche d'apparence ; dialogues avec tons (Calme,
  Cash, Malin).
- Les huit quêtes de l'acte 1, de « Ascenseur en panne » à « La tour se lève » :
  infiltration (contrebande, caméras), tag de nuit (trois fresques au choix), épreuves de
  confiance, choix moral du « contact », enquête sur l'indic, défense du hall par vagues.
- La couleur, c'est la liberté : gris du régime, couleurs chez soi, libération de
  Grigny 2 (couleurs, vrai nom, musique, planque), le régime quitte la zone.
- Jour et nuit, couvre-feu annoncé, lit pour dormir, horaires du point de ration.
- Grigny 2 d'après des photos du terrain : tours à pilastres crème et damier bordeaux,
  gare de Grigny-Centre (verrière, bardage brique, enseigne), hall en travertin, paliers
  en crépi, potelets, bornes incendie, lampadaires « soucoupe », arbres d'automne.
- Vigiles (patrouille, soupçon, alerte, recherche), caméras qui balaient, combat au
  corps à corps et neutralisation, arrestation.
- Besoins, endurance, inventaire en grille, journal des quêtes, guidage vers l'objectif.
- Son : bruitages, musiques (régime, maison, quartier libre) et ambiance, synthétisés.
- Écran titre, pause, fin de l'acte 1 ; sauvegarde à la planque.
- Builds Windows, Linux, macOS et web publiés sur une GitHub Release à chaque étiquette.

## [0.0.1] — M0 « Fondations »

### Ajouté

- Projet Godot 4.7.2 (renderer Compatibility, GDScript typé, Jolt, interpolation physique).
- Rendu « pixel 2.5D » : monde en basse résolution agrandi à l'échelle entière, caméra
  orthographique isométrique calée sur la grille de pixels, contours par profondeur,
  palette de 32 couleurs avec tramage, saturation pilotable (gris du régime ↔ couleur).
- Caméra isométrique tournant par pas de 90°.
- Contrôleur du joueur au clavier et à la manette (marche, course).
- EventBus et sauvegarde JSON versionnée avec migrations.
- Mode capture d'écran (`-- --screenshot <scène>`).
- Zone de test « la dalle ».
- Interface minimale traduisible, police pixel, panneau des crédits.
- Outillage : installation de Godot épinglé, `tools/check.sh`, validation des données.
- CI GitHub Actions et build web mono-thread publié sur GitHub Pages.
- Documentation : brief, GDD, guide de ton, feuille de route, décisions, cadre légal.
