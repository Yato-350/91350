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

## À surveiller

- **Ondulation du personnage** : la caméra est calée sur la grille, pas le joueur ; son
  contour peut bouger d'un pixel en marchant. Parade possible : caler sa position visuelle.
- **Contours sur un vrai GPU** : validés ici en rendu logiciel seulement ; le seuil
  `threshold` de `outline.gdshader` est ajustable.
- **F5 dans le navigateur** : Godot intercepte les touches quand le canvas a le focus ;
  à vérifier à la main sur le build en ligne (repli : F6 / F8).
