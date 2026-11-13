# Assets du jeu

Chaque asset est listé avec sa source, sa licence et son statut. Les assets générés
par code viennent des sources texte de `assets_src/` ; les assets externes sont
uniquement en CC0 ou sous une licence compatible.

| Asset | Source | Licence | Statut |
|---|---|---|---|
| `assets_src/palette.json` | Fait pour le projet | Projet | Final (ajustable) |
| `assets/fonts/Tiny5-Regular.ttf` | [Tiny5](https://fonts.google.com/specimen/Tiny5), The Tiny5 Project Authors | SIL Open Font License 1.1 (`assets/fonts/Tiny5-OFL.txt`) | Provisoire : police de l'interface à 8 px |
| `assets/ui/theme.tres` | Fait pour le projet | Projet | Provisoire |
| Personnages (`assets/voxel/characters/*.glb`, `assets/icons/characters/*.png`) | Générés par `tools/build_voxels.py` depuis `data/characters/characters.json` | Projet | Placeholder généré (35 personnages) |
| Objets (`assets/voxel/items/`, `assets/icons/items/`) | Générés depuis `assets_src/voxel/items/*.txt` | Projet | Placeholder généré (26 objets) |
| Décor (`assets/voxel/props/`, `assets/icons/props/`) | Générés depuis `assets_src/voxel/props/*.txt` | Projet | Placeholder généré (28 éléments) |
| Zones extérieures (`scenes/zones/generated/*.scn`) | Cuites par `tools/bake_zones.gd` depuis `tools/osm_import/data/` | Données dérivées d'OpenStreetMap : ODbL (`docs/LEGAL.md`) | Généré |
| Zone de test (`scenes/zones/test_zone.tscn`) | Boîtes grises écrites à la main | Projet | Placeholder de M0 |
| `addons/dialogue_manager/` | [Dialogue Manager 4.2.0](https://github.com/nathanhoad/godot_dialogue_manager), Nathan Hoad | MIT (`addons/dialogue_manager/LICENSE`) | Addon, distribué avec le jeu (sans ses fichiers C#) |
| `addons/gut/` | [GUT 9.7.1](https://github.com/bitwes/Gut) | MIT | Addon de test, non distribué avec le jeu |
