# Décisions techniques

Choix datés et justifiés. Une décision réversible se prend, se note ici, et on continue.

| # | Date | Décision | Pourquoi | Réversible ? |
|---|---|---|---|---|
| 1 | 2026-11-11 | **Godot 4.7.2-stable**, épinglé dans `.godot-version` | Dernière version stable ; la 4.8 est en bêta (« jamais une bêta ») | Oui : passer à la 4.8 quand elle est stable *et* que GUT et Dialogue Manager l'annoncent compatible |
| 2 | 2026-11-11 | **Contours par texture de profondeur**, pas d'*inverted hull* | Essai concluant en Compatibility, sur OpenGL bureau et WebGL 2 ; le laplacien de la profondeur ne crée pas de faux trait sur les pentes en orthographique | Oui (un shader) |
| 3 | 2026-11-11 | La **palette est la dernière passe**, en shader `canvas_item` dans le SubViewport | Une passe écran en shader spatial décale les couleurs (≤ 6/255) ; en `canvas_item`, 0 pixel hors palette | Oui |
| 4 | 2026-11-11 | **`SubViewportContainer` + `PixelView`** plutôt que l'étirement `viewport` du projet | Seul moyen de compenser le reste sous-pixel de la caméra (défilement fluide sans scintillement) | Oui |
| 5 | 2026-11-11 | **Tangage de la caméra : 30° exactement** | Avec un lacet de 45°, les arêtes au sol tombent sur des lignes de pixels 2:1 nettes | Oui (une constante) |
| 6 | 2026-11-12 | **Vue étendue plutôt que bandes noires** : échelle `max(1, arrondi(min(l / 640, h / 360)))`, rendu `ceil(fenêtre / échelle)` | Aucun bord vide sur les fenêtres non multiples de 640×360. L'arrondi au plus proche (et non vers le bas) garde un agrandissement de 2 dans un navigateur de portable (1366×650) au lieu de tout afficher en minuscule | Oui |
| 7 | 2026-11-11 | **Jolt Physics** et **interpolation physique** | Jolt marche aussi en web mono-thread (essayé) ; l'interpolation garde un mouvement fluide au-delà de 60 Hz | Oui (réglages du projet) |
| 8 | 2026-11-11 | **Sauvegarde par groupe `saveable`** (`save_id`, `save_state`, `load_state`), pas d'autoload `GameState` | Aucun état global à porter en M0 ; chaque système possède son état | Oui |
| 9 | 2026-11-11 | **Installation de Godot par script** (`tools/install_godot.sh`, SHA-512 vérifié) plutôt qu'une action tierce | Même chemin en CI, en session cloud et sous Linux ; une seule source de version | Oui |
| 10 | 2026-11-11 | Dossiers **`shaders/`** et **`locale/`** ajoutés à l'arborescence du brief | Shaders écrits à la main et traductions CSV n'avaient pas de place prévue | Oui |
| 11 | 2026-11-11 | **Pas de transparence par mélange alpha dans le monde** | Les contours lisent l'écran : un objet transparent serait dessiné hors contours et hors profondeur. *Alpha scissor* ou tramage | Oui |
| 12 | 2026-11-11 | **Police Tiny5** (SIL OFL 1.1) à 8 px | Nette à 8 px, tous les glyphes français. monogram (CC0) ne se télécharge pas en automatique. L'OFL impose de joindre sa licence (fait) | Oui (un fichier, une ligne du thème) |
| 13 | 2026-11-11 | **Traductions en CSV** (`locale/strings.csv`), fichiers `.translation` générés et ignorés par Git | Le plus simple pour un développeur seul ; l'import les régénère | Oui (passage à gettext) |
| 14 | 2026-11-11 | **Thème d'interface central** (`assets/ui/theme.tres`) | Un seul endroit pour la police, les couleurs et les panneaux | Oui |
| 15 | 2026-11-11 | **Avertissement `unused_signal` désactivé** | Un bus de signaux déclare des signaux qu'il n'émet pas lui-même | Oui |
| 16 | 2026-11-11 | **Déclaration non typée = erreur** (`untyped_declaration=2`) | Le brief exige du GDScript typé partout ; le moteur le fait respecter | Oui |
| 17 | 2026-11-11 | La CI **ne lit pas le journal de l'import** : elle charge ensuite chaque script, scène, ressource et shader | Sur un clone neuf, le premier import signale des fichiers qu'il est en train de créer ; et l'import ne compile pas le GDScript | Oui |
| 18 | 2026-11-11 | **Hébergement web : GitHub Pages**, déployé depuis `main` | Dépôt public : gratuit, aucun secret à gérer. itch.io (butler) viendra plus tard | Oui |
| 19 | 2026-11-11 | **Branche de jalon = branche de la session cloud** (`claude/…`) au lieu de `m0-fondations` | Contrainte de l'environnement d'exécution ; PR vers `main` comme prévu | Oui |
| 20 | 2026-11-11 | **Dialogue Manager 4.2.0** (et non la v3), installé en M1 | La v4 est sortie officiellement en août 2026, pour Godot 4.7 | Oui |
| 21 | 2026-11-11 | `release.yml`, pipeline voxel/pixel, `GameState`, `AudioManager` **reportés à M1** | Pas de système « pour plus tard » : ils arrivent avec ce qui les utilise | — |
| 22 | 2026-11-11 | **L'essai web dans Chromium** (`tools/web_smoke.cjs`) est un script Node hors CI | Playwright est préinstallé dans les sessions cloud ; l'ajouter à la CI coûterait une installation de navigateur à chaque exécution | Oui |
| 23 | 2026-11-12 | Les événements d'entrée valent pour **tous les périphériques** (`device = -1`) | Une manette n'est pas toujours la numéro 0 (revue de M0) | Oui |
| 24 | 2026-11-12 | La CI tourne sur `push` **et** sur `pull_request`, sans job sauté | Un job sauté compte comme réussi : il pouvait masquer un échec et laisser passer une fusion (revue de M0) | Oui |
| 25 | 2026-11-12 | `SaveManager` **refuse** un `save_id` vide ou en double | Sans cela, deux nœuds s'écrasent en silence dans la sauvegarde (revue de M0) | Oui |
| 26 | 2026-11-12 | Le shader de contours **ne trace rien sur le cadre** de l'image | Le voisin manquant faussait le laplacien : un trait clignotait en haut et en bas de l'écran (revue de M0) | Oui |
| 27 | 2026-11-12 | `physics_jitter_fix = 0` | Recommandé quand l'interpolation physique est active | Oui |
| 28 | 2026-11-12 | Import OSM par l'**API principale** (`/api/0.6/map`), extrait mis en cache hors dépôt | Overpass est injoignable depuis l'environnement cloud ; un petit extrait par zone suffit | Oui |
| 29 | 2026-11-12 | Zones **cuites** par `tools/bake_zones.gd` : maillages fusionnés par carrés de 64 m, collisions, grille de navigation d'un mètre | Chargement rapide ; pas de navmesh à maintenir | Oui |
| 30 | 2026-11-12 | **Monde plat** en M1 | Le relief (plateau, coteau) n'apporte rien à la tranche verticale | Oui |
| 31 | 2026-11-12 | **Vue à travers les bâtiments** : disque tramé autour d'Akan dans le shader des façades (uniformes globaux) | Les tours cachent le joueur en vue isométrique ; pas de transparence alpha | Oui |
| 32 | 2026-11-12 | Caméra reculée à **150 m**, plan lointain à 400 m | Une tour proche ne passe jamais derrière une caméra orthographique aussi loin | Oui |
| 33 | 2026-11-12 | Voxels : faces fusionnées (*greedy meshing*), couleurs sRGB par sommet, matériau `vertex_color_is_srgb` | Dix fois moins de triangles ; un seul matériau pour tous les modèles | Oui |
| 34 | 2026-11-12 | Personnages **générés** depuis une fiche d'apparence (six parties rigides) | 35 personnages sans dessiner un seul modèle à la main | Oui |
| 35 | 2026-11-13 | Systèmes de jeu en **logique pure** (`RefCounted`), portés par l'autoload `GameState`, relayés sur l'`EventBus` | Testables sans nœud ; l'interface ne connaît que le bus | Oui |
| 36 | 2026-11-13 | `GameState` est le **seul** nœud sauvegardé d'une partie ; le joueur ne l'est plus à part | Charger une partie = relire l'état puis recharger le lieu | Oui |
| 37 | 2026-11-13 | Table des commandes **générée** depuis `assets_src/input_map.json` | La section `[input]` de `project.godot` est illisible à la main | Oui |
| 38 | 2026-11-13 | Interagir : **F** / A (manette) ; la caméra garde A / E | E est pris par la rotation de la caméra depuis M0 | Oui |
| 39 | 2026-11-13 | Intérieurs en **plans de texte**, construits au chargement : murs fins et bas, vue rapprochée ×2 | Un appartement se lit d'un coup d'œil ; un plan se corrige dans un éditeur de texte | Oui |
| 40 | 2026-11-13 | Objectif de quête **`USE`** ajouté à la liste du brief ; **`COLLECT`** = avoir l'objet dans le sac | Le tutoriel fait manger et boire ; un objet ramassé trop tôt ne bloque pas la quête | Oui |
| 41 | 2026-11-13 | Un objet qui ne tient pas dans le sac **tombe au sol** ; rien n'est jamais perdu | Un sac plein ne doit pas bloquer une quête | Oui |
| 42 | 2026-11-13 | Éclairage : l'**ambiance et le soleil s'additionnent en sRGB** ; énergies réglées pour qu'un sol reçoive juste sa couleur | En Compatibility, une lumière à ombres est dessinée dans une passe ajoutée après la conversion sRGB (mesuré) ; dehors, à reprendre avec le cycle jour/nuit | Oui |
| 43 | 2026-11-13 | **Gris du régime à 0,6** de saturation (pas 0) ; libérée : 1,0, en 4 s | À 0,4, la palette ramène tout au gris béton : on ne voit plus la vie du quartier (linge, vêtements, rideaux). À 0,6 les pelouses grisent et la libération reste une récompense visible | Oui |
| 44 | 2026-11-13 | Un **logement garde ses couleurs** (`"home": true`) | Chez soi, le régime n'entre pas : le contraste avec le palier gris enseigne « couleur = liberté » sans un mot | Oui |
| 45 | 2026-11-13 | **Points d'action** (`spots`) en données : un geste = un dialogue | Lit, mur à taguer, boîtier à saboter : la même brique, et c'est le dialogue qui décide (choix, effets, objectifs) | Oui |
| 46 | 2026-11-13 | Vocabulaire des dialogues en **deux objets** : `Story` (récit) et `Neighbourhood` (quartier) | Un seul objet dépassait vingt fonctions publiques ; Dialogue Manager cherche dans les deux sans que l'auteur ait à le savoir | Oui |
| 47 | 2026-11-13 | **Présence sous condition gérée par le lieu** (portes, décor, personnages, caméras, Vigiles), relue à chaque drapeau, quête, libération, et chaque seconde | Une seule règle pour « Paul est emmené », « le toit s'ouvre », « le régime quitte une zone libérée » | Oui |
| 48 | 2026-11-13 | **Infiltration = contrebande** : un objet `contraband` dans le sac rend Akan suspect aux yeux des caméras ; repéré, il reste « grillé » 20 s | Plus simple qu'un mode « mission » : c'est ce qu'il transporte qui le trahit ; les guetteurs refusent un livreur grillé | Oui |
| 49 | 2026-11-13 | **DEFEND par vagues** de Vigiles (taille de chaque vague dans l'étape), reprise à la vague en cours | La descente du hall se rejoue sans repartir de zéro après une arrestation | Oui |

## À surveiller

- **Ondulation du personnage** : la caméra est calée sur la grille, pas le joueur ; son
  contour peut bouger d'un pixel en marchant. Parade possible : caler sa position visuelle.
- **Contours sur un vrai GPU** : validés ici en rendu logiciel seulement ; le seuil
  `threshold` de `outline.gdshader` est ajustable.
- **F5 dans le navigateur** : Godot intercepte les touches quand le canvas a le focus ;
  à vérifier à la main sur le build en ligne (repli : F6 / F8).
