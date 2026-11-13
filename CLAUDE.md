# CLAUDE.md — projet « 91350 »

**Relis `docs/BRIEF.md` au début de chaque session** : c'est le brief permanent. En cas
de conflit, une demande directe de l'utilisateur l'emporte sur le brief.

Jeu : action-RPG d'infiltration en pixel art 2.5D (Godot), situé à Grigny (91350).
Communication avec l'utilisateur **en français**. Identifiants et noms de fichiers en
anglais ; commentaires et docs en français.

## Où en est-on

- État des jalons : `docs/ROADMAP.md`. Design : `docs/GDD.md`. Ton : `docs/TON.md`.
- Choix techniques datés : `docs/DECISIONS.md` (y ajouter toute décision réversible).
- Plans d'implémentation : `docs/plans/`.

## Version et outils (épinglés)

- **Godot 4.7.2-stable** — source unique : `.godot-version`. Jamais de bêta.
- GUT 9.7.1 (`addons/gut/`), gdtoolkit 4.5.0, Python 3 (`tools/requirements.txt`).
- Renderer **Compatibility** uniquement (export web) ; **GDScript typé partout**, pas de C#.

## Commandes

```bash
tools/install_godot.sh --templates web   # Godot épinglé + modèles d'export web (Linux)
tools/install_godot.sh --templates all   # + Windows, Linux, macOS (exports de release)
python3 tools/build_sounds.py            # régénère les sons (assets/audio/)
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
tools/check.sh all                       # lint, data, import, test, render, web
tools/check.sh test                      # tests GUT sans affichage
tools/check.sh render                    # tests de rendu + capture de la zone de test
tools/check.sh screenshot res://scenes/zones/test_zone.tscn
tools/check.sh screenshot zone:grigny2@mur_tag 22 3   # lieu@repère, heure, quart de tour
tools/check.sh web && node tools/web_smoke.cjs   # build web + essai dans Chromium
.venv/bin/gdformat scripts tests tools   # formate avant le lint
```

Toujours passer par `tools/godot.sh` (il refuse une autre version que celle épinglée).

## Règles de travail

- **Vérifier, toujours** : après chaque changement, `tools/check.sh` (au moins `import`,
  `test`, `lint`) ; après un changement visuel, `render` puis **regarder la capture**
  dans `build/screenshots/`. Ne jamais dire « c'est fait » sans avoir lu la sortie.
- **TDD** : le test d'abord, le voir échouer, puis le code minimal.
- **Tranche verticale** : finir un jalon jouable avant d'élargir. Pas de système
  « pour plus tard », pas de sur-ingénierie.
- **Git** : commits atomiques en Conventional Commits (`feat:`, `fix:`, `content:`,
  `art:`, `chore:`, `docs:`, `ci:`), messages en français, PR vers `main`.
  Jamais de `git push --force` ni de suppression massive sans accord.
- **Contenu narratif = brouillon** rédigé dans les fichiers de données.
- Expliquer brièvement chaque concept Godot important dans les récaps.

## Conventions de code

- Toute déclaration est typée (`debug/gdscript/warnings/untyped_declaration=2` en fait
  une erreur). Classes nommées par `class_name`.
- Logique pure dans des classes statiques testables sans nœud (`PixelSnap`, `SaveCodec`).
- Systèmes découplés par l'autoload `EventBus` (signaux) ; le moins d'autoloads possible.
- Aucun nombre magique : constantes nommées ou valeurs dans `data/`.
- Toute entrée passe par une action `InputMap` (touches **physiques**, zone morte 0,2).
- Toute chaîne affichée passe par une clé de `locale/strings.csv`.
- Données du jeu en JSON sous `data/<type>/`, validées par `data/schemas/<type>.schema.json`.
- Un nœud sauvegardable est dans le groupe `saveable` et fournit `save_id`,
  `save_state()`, `load_state()`.
- Scènes `.tscn` simples écrites à la main ; le reste est construit par code ou par outil.
- Au moins un fichier de test par système dans `tests/` ; les tests qui exigent un vrai
  rendu vont dans `tests/render/` (ignorés en `--headless`).

## Rendu « pixel 2.5D »

- Monde rendu dans un `SubViewport` basse résolution (base 640×360, **16 px par mètre**),
  agrandi à l'échelle entière par `PixelView` (`scripts/systems/rendering/`).
- Caméra orthographique : tangage 30°, lacet 45° + pas de 90° (`CameraRig`). `PixelView`
  la cale sur la grille de pixels ; son propriétaire la replace à chaque image.
- Deux passes : `shaders/outline.gdshader` (contours par profondeur) puis
  `shaders/color_grade.gdshader` (saturation, tramage, palette). La palette est la
  **dernière** passe ; elle se lit dans `assets_src/palette.json` (32 couleurs max).
- Pas de transparence par mélange alpha dans le monde : *alpha scissor* ou tramage.
- Les couleurs des matériaux viennent de la palette.

## Garde-fous (non négociables — brief §16)

- Fiction : aucune personne, marque, parti ni symbole réels.
- Lieux de culte, écoles et lieux de soins sont neutres : ni combat ni cible.
- Aucun rôle lié à une origine ou une religion ; aucun mineur lié à la violence, aux
  armes ou aux trafics. Aucune instruction réelle de fabrication d'arme.
- OpenStreetMap : attribution obligatoire, données dérivées sous ODbL (`docs/LEGAL.md`).
- La Grande Borne : s'inspirer et styliser, ne jamais copier fresques ni sculptures.
- Aucun secret dans le dépôt ; aucune collecte de données personnelles dans le jeu.

## Sessions cloud (Claude Code sur le web)

- Godot n'est pas préinstallé : `tools/install_godot.sh --templates web`.
- Pas d'écran : le rendu passe par Xvfb (`tools/check.sh render` s'en charge).
- Pour récupérer un addon public sur GitHub : `git clone` de son dépôt hors du projet,
  puis copie de `addons/<nom>/`.
- La session impose sa branche de travail (`claude/…`) : elle sert de branche de jalon.
- Committer et pousser souvent : le conteneur est éphémère.
