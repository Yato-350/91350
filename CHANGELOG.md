# Journal des modifications

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet
suit le [versionnage sémantique](https://semver.org/lang/fr/) (`0.x` pendant toute la
phase de test).

## [Non publié]

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
