# M1 — Tranche verticale : plan

**Objectif (brief §17) :** l'acte 1 (~45 min) se joue de bout en bout sans bug bloquant ;
tests verts ; release `v0.1.0` (Windows + Web).

**Spec :** `docs/BRIEF.md` (§6, §9, §10, §12, §13, §14) et `docs/GDD.md` (§5, §7, §8).
Consigne du 2026-11-11 : autorisation complète, on enchaîne les jalons sans attendre.

## Architecture retenue

- **`GameState` (autoload)** porte l'état d'une partie et ses systèmes, écrits comme des
  classes de logique pure testables sans nœud : `GameClock`, `Vitals` (santé, endurance),
  `Needs` (faim, soif), `Inventory`, `QuestLog`, `Territory`, `Surveillance` (Vigilance,
  statut citoyen), `Progression` (XP ; arbres en M2), `flags`. Il est sauvegardable.
- **Données** dans `data/` (JSON + schémas) : `items/`, `quests/`, `characters/`,
  `zones/`, `interiors/`. Tout est chargé par `DataRegistry`.
- **Zones extérieures** : `tools/osm_import/` (extrait OSM mis en cache → données
  dérivées ODbL dans `tools/osm_import/data/`) puis `tools/bake_zones.gd` (Godot
  headless) → `scenes/zones/generated/<zone>.scn` : maillages fusionnés, collisions,
  grille de navigation. Le contenu de jeu d'une zone (PNJ, caméras, patrouilles, portes,
  objets) vient de `data/zones/<zone>.json` et est posé au chargement par `Zone`.
- **Intérieurs** : plans en texte dans `data/interiors/*.json`, construits au chargement
  par `InteriorBuilder` (murs bas, vue en coupe).
- **Navigation** : `AStarGrid2D` par zone (cases d'un mètre), pas de navmesh.
- **Personnages et objets** : `tools/build_voxels.py` (modèles texte → `.glb` + icône) et
  `tools/voxel_characters.py` (personnages générés depuis une fiche d'apparence).
- **Dialogues** : Dialogue Manager 4.2.0, fichiers `dialogue/*.dialogue`, bulle maison.
- **Vision à travers les murs** : un cercle tramé autour du joueur dans le shader des
  bâtiments (pas de transparence alpha).
- **Monde plat** en M1 : le relief (plateau, coteau) viendra plus tard s'il sert le jeu.

## Tâches

| # | Tâche | Livrable vérifiable |
|---|---|---|
| 1 | Pipeline voxel | `tools/build_voxels.py`, `tools/voxel_characters.py`, tests Python ; `assets/voxel/*.glb`, `assets/icons/*.png` |
| 2 | Import OSM | `tools/osm_import/` + tests ; `tools/osm_import/data/grigny2.json` (ODbL) |
| 3 | Zone jouable | `ZoneGeometryBuilder`, `tools/bake_zones.gd`, shader de façades, vision à travers les murs ; on marche dans Grigny 2 (capture) |
| 4 | Socle de partie | `GameState`, `DataRegistry`, chargement de zones et d'intérieurs, transitions, sauvegarde complète |
| 5 | Joueur | endurance, accroupi, interactions, modèle voxel animé |
| 6 | Besoins, inventaire, objets | `Needs`, `Inventory`, objets en JSON, HUD, écran d'inventaire |
| 7 | Dialogues et PNJ | addon, bulle, PNJ, `dialogue/*.dialogue` |
| 8 | Quêtes | `QuestLog`, schéma, journal ; quêtes 1 à 3 jouables |
| 9 | Temps | cycle jour/nuit, éclairage, couvre-feu |
| 10 | Surveillance | cônes de vision, caméras, Vigilance, statut ; quêtes 4 et 5 (tag) |
| 11 | IA et combat | Vigiles (machine à états, chemins), mêlée, neutralisation, lance-pierre ; quêtes 6 et 7 |
| 12 | Territoire | Contrôle/Soutien, « zone libérée » (couleurs, vrais noms) ; quête 8 |
| 13 | Audio | sons et musiques générés, `AudioManager` |
| 14 | Menus | écran titre, pause, sauvegarde/chargement, fin de partie |
| 15 | Parcours de test | un robot joue l'acte 1 de bout en bout en headless |
| 16 | Release | `release.yml`, presets Windows/Linux/macOS, `v0.1.0` |

Chaque tâche : tests d'abord pour la logique, `tools/check.sh all`, capture regardée pour
le visuel, un commit (ou plus) poussé.

## Risques

| Risque | Parade |
|---|---|
| Overpass est injoignable depuis l'environnement cloud | API principale d'OSM (`/api/0.6/map`), un petit extrait par zone, mis en cache |
| Les tours cachent le joueur en vue isométrique | Cercle tramé de vision à travers les murs + rotation de la caméra |
| Noms de rues portant le nom de personnes réelles | Le jeu n'affiche que des noms de lieux choisis à la main dans `data/zones/` |
| Marques dans les données OSM (commerces, bailleurs) | Le convertisseur retire ces noms |
| Volume de contenu (dialogues, modèles) | Générateurs (personnages, façades) et données compactes |
| Régressions sur le parcours complet | Robot de parcours (tâche 15) lancé par `tools/check.sh test` |

## Terminé quand

- Le robot de parcours termine l'acte 1 (les 8 quêtes) en headless.
- `tools/check.sh all` et la CI sont verts ; le build web tourne dans Chromium.
- La première zone se libère : couleurs, vrais noms.
- La release `v0.1.0` est publiée avec ses builds.
