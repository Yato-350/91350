# M0 — Fondations : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Statut :** en attente du feu vert (brief §18.3). Rien n'est implémenté.

**Objectif :** un projet Godot 4.7.2 où l'on se déplace (clavier + manette) dans une scène test au rendu « pixel 2.5D » net et sans scintillement, avec EventBus, sauvegarde, mode capture d'écran, CI verte et build web jouable en ligne.

**Architecture :** le monde 3D est rendu dans un `SubViewport` basse résolution (base 640×360, 16 px/m) par une caméra orthographique isométrique. Un compositeur (`PixelView`) cale la caméra sur la grille de pixels, compense le reste sous-pixel en décalant l'image agrandie, et applique deux passes : contours par profondeur (shader spatial) puis saturation + dithering + palette (shader canvas). La logique pure (maths de calage, encodage des sauvegardes, direction de déplacement) vit dans des classes statiques testées sans nœuds.

**Stack :** Godot 4.7.2-stable, GDScript typé, renderer Compatibility, GUT 9.7.1, gdtoolkit 4.5.0, Python 3 (jsonschema, pytest), GitHub Actions + GitHub Pages.

**Spec :** `docs/BRIEF.md` — §17 (ligne M0), §3, §4, §5, §13, §14, §16, §18. Le fichier est aujourd'hui à la racine (`BRIEF.md`) ; la tâche 1 le déplace.

## Faits vérifiés le 2026-11-11 (essais jetables, hors dépôt)

| Point | Résultat |
|---|---|
| Dernière version stable de Godot | **4.7.2** (18 août 2026). La 4.8 est en bêta 3 → exclue (« jamais une bêta »). |
| Binaire Linux + modèles d'export | Téléchargeables depuis les releases GitHub de `godotengine/godot` ; `--version` → `4.7.2.stable.official.ed1daf0bf`. Le `.tpz` pèse 1,28 Go mais seuls `web_nothreads_{debug,release}.zip` (2 × 9,8 Mo) servent au web. |
| Rendu sans écran | `xvfb-run` + Mesa llvmpipe (OpenGL 4.5) : le renderer Compatibility rend et la capture PNG fonctionne. `--headless` ne rend rien (pilote factice). |
| Texture de profondeur en Compatibility | **Supportée**, en OpenGL bureau *et* en WebGL 2 (Chromium) → contours par profondeur, pas d'*inverted hull*. |
| Passe palette | Shader `canvas_item` dans le SubViewport : 0 pixel hors palette. Une passe écran en shader *spatial* décale les couleurs de ≤ 6/255 → la palette doit être la **dernière** passe. |
| Mise à l'échelle entière | `SubViewportContainer` (`stretch` + `stretch_shrink`) : net en ×2, ×3 et sur fenêtre non multiple (1366×768 → 685×386), y compris avec décalage sous-pixel. |
| Export web mono-thread | `variant/thread_support=false` : tourne dans Chromium sans en-tête COOP/COEP (`crossOriginIsolated = false`) → compatible GitHub Pages. `index.wasm` ≈ 39,5 Mo. |
| Jolt Physics | Fonctionne sur bureau et en web mono-thread. |
| Fichiers `.uid` | Générés par `--headless --import` → à committer. |
| gdtoolkit 4.5.0 | S'installe sous Python 3.13 ; accepte dictionnaires typés et boucles `for` typées. |
| GUT | **9.7.1** pour Godot 4.7.x (pas encore exécuté ici : les archives d'autres dépôts GitHub demandent `add_repo`). |
| Dialogue Manager | La **v4 est sortie officiellement** (v4.0.0 le 15 août 2026 ; v4.2.0 le 30 oct. 2026, « for Godot 4.7 ») → v4.2.0, installée en M1. |
| Dépôt | Public → GitHub Pages disponible gratuitement. |
| Actions GitHub (versions majeures) | `checkout@v7`, `setup-python@v7`, `cache@v6`, `upload-artifact@v7`, `upload-pages-artifact@v5`, `deploy-pages@v5`. |

Commandes validées :

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720
godot --headless --path . --export-release "Web" build/web/index.html
# Chromium sans GPU (Playwright) : --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist
```

## Contraintes globales (brief)

- Godot **4.7.2-stable**, épinglé dans `.godot-version` (source unique), `README.md`, `CLAUDE.md` ; la CI lit `.godot-version`.
- **GDScript typé statiquement partout** ; pas de C#. Renderer **Compatibility** uniquement.
- Rendu **640×360**, agrandissement *nearest* à **échelle entière**, **16 px par mètre**, caméra **orthographique isométrique**, rotation par pas de **90°**, palette **~32 couleurs**.
- Manette + clavier dès M0 ; toute entrée passe par une action `InputMap` (réassignable par construction).
- Valeurs d'équilibrage en constantes nommées ou dans `data/` : jamais de nombres magiques.
- Identifiants et noms de fichiers en anglais ; commentaires et docs en français ; toute chaîne affichée passe par une clé de traduction.
- Commits atomiques en Conventional Commits, messages en français. Jamais de `git push --force`. Aucun secret dans le dépôt.
- Fiction : aucune personne, marque ni symbole réels (s'applique au GDD et à `TON.md`).
- Vérifier après chaque changement : import, tests, lint, capture d'écran si visuel.

## Décisions par défaut (réversibles — à recopier dans `docs/DECISIONS.md`)

1. **Branche** : cette session cloud est rattachée à `claude/zen-ride-bebvan` ; elle sert de branche M0 (le brief prévoyait `m0-fondations`). PR vers `main`.
2. **Tangage de la caméra : 30° exactement** (dans la fourchette 30–40°) : avec un lacet de 45°, les arêtes au sol tombent sur des lignes de pixels 2:1 nettes.
3. **Vue étendue plutôt que bandes noires** : échelle `N = max(1, min(largeur ÷ 640, hauteur ÷ 360))` ; le SubViewport fait `ceil(fenêtre / N)`, donc ≥ 640×360 dès que la fenêtre le permet.
4. **Jolt Physics** + **interpolation physique** activée (mouvement fluide au-delà de 60 Hz).
5. **Sauvegarde** : chaque nœud du groupe `saveable` fournit `save_id`, `save_state()`, `load_state()` ; pas d'autoload `GameState` tant qu'aucun état global n'existe.
6. **Installation de Godot par script** (`tools/install_godot.sh`, SHA-512 vérifié) plutôt qu'une action tierce : même chemin en CI, en session cloud et sous Linux.
7. **Dossiers ajoutés à l'arborescence du brief** : `shaders/` (shaders écrits à la main) et `locale/` (traductions CSV).
8. **Aucune transparence par mélange alpha dans le monde** tant que les contours passent par l'écran : opacité par *alpha scissor* ou tramage.
9. **Police d'interface** : monogram-extended (CC0) ; repli Pixel Operator (CC0) si les glyphes français manquent.
10. **Hébergement web** : GitHub Pages, déployé depuis `main`. itch.io (butler) plus tard.
11. **Mise à niveau vers Godot 4.8** : seulement quand elle est stable *et* que GUT et Dialogue Manager l'annoncent compatible.

## Hors périmètre M0 (pas de « systèmes pour plus tard »)

`release.yml` et presets Windows/Linux/macOS (M1, avec `v0.1.0`) · Dialogue Manager (M1) · `build_voxels.py` / `build_pixels.py` (M1) · import OSM (M1) · autoloads `GameState` et `AudioManager` (M1) · endurance, accroupi, interactions (M1) · écran de remappage et menu d'options (M5 au plus tard) · butler/itch.io · trame des actes 2 à 4 dans le GDD (après l'acte 1, brief §10).

## Points de vigilance (*Review Focus*)

Cas que le brief ne nomme pas mais qu'un joueur rencontrera ; chacun a son test dans la tâche indiquée.

1. **Fenêtre non multiple de 640×360, minuscule, ultra-large, redimensionnée ou en plein écran** → image nette, échelle ≥ 1, pas de bord vide (tâches 4 et 5).
2. **Sauvegarde corrompue, tronquée, vide ou issue d'une version plus récente** → chargement refusé, état du jeu intact, pas de plantage (tâche 3).
3. **Joueur hors de la zone jouable ou tombé sous le sol** → retour au point d'apparition (tâche 7).
4. **Palette absente ou invalide à l'exécution** (ex. JSON oublié à l'export) → le jeu s'affiche sans passe palette et journalise l'erreur, au lieu d'un écran noir (tâches 2, 5 et 11).
5. **Clavier AZERTY/QWERTY, manette absente ou stick qui dérive** → touches par position physique, zone morte de 0,2, aucun mouvement fantôme (tâche 7).

## Arborescence créée par M0

```
.godot-version  .gitignore  .gitattributes  .gutconfig.json  project.godot  export_presets.cfg
README.md  CLAUDE.md  CHANGELOG.md
.github/workflows/ci.yml        .github/ISSUE_TEMPLATE/{bug,playtest}.yml
addons/gut/                     GUT 9.7.1 (MIT), copié tel quel
assets/ASSETS.md                assets/fonts/monogram-extended.ttf
assets_src/palette.json         data/schemas/palette.schema.json
docs/{BRIEF,GDD,TON,ROADMAP,DECISIONS,LEGAL}.md   docs/plans/m0-fondations.md
locale/strings.csv
scenes/main/{main,pixel_view}.tscn   scenes/actors/{player,camera_rig}.tscn   scenes/zones/test_zone.tscn
scripts/autoload/{event_bus,save_manager}.gd
scripts/systems/save/save_codec.gd
scripts/systems/rendering/{palette,pixel_snap,pixel_view}.gd
scripts/actors/{player,camera_rig}.gd   scripts/main/main.gd   scripts/ui/debug_hud.gd
shaders/{outline,color_grade,debug_grid}.gdshader
tests/test_*.gd                 tests/render/test_*.gd   (exigent un vrai rendu, ignorés en --headless)
tools/{godot.sh,godot.ps1,install_godot.sh,check.sh,validate_data.py,web_smoke.mjs,requirements.txt}
tools/tests/test_validate_data.py
```

Les `.uid` et `.import` générés par l'import sont committés avec leur fichier. `.godot/`, `build/`, `.tools/`, `.venv/` et `*.translation` sont ignorés.

---

### Tâche 1 : Squelette, outillage et première barre verte

**Fichiers :**
- Créer : `.godot-version`, `.gitignore`, `.gitattributes`, `project.godot`, `.gutconfig.json`, `tools/install_godot.sh`, `tools/godot.sh`, `tools/godot.ps1`, `tools/check.sh`, `tools/requirements.txt`, `addons/gut/**`, `tests/test_project_setup.gd`
- Déplacer : `BRIEF.md` → `docs/BRIEF.md`

**Interfaces :**
- Produit `tools/install_godot.sh [--templates web]` : lit `.godot-version` (`4.7.2-stable`), télécharge `Godot_v4.7.2-stable_linux.x86_64.zip` depuis `https://github.com/godotengine/godot/releases/download/4.7.2-stable/`, vérifie son SHA-512 contre `SHA512-SUMS.txt` de la même release, l'installe en `.tools/godot/4.7.2-stable/godot`. Avec `--templates web` : extrait du `.tpz` `templates/version.txt` et `templates/web_nothreads_{debug,release}.zip` vers `~/.local/share/godot/export_templates/4.7.2.stable/`, puis supprime le `.tpz`. Idempotent.
- Produit `tools/godot.sh <args…>` : lance, dans l'ordre, `$GODOT`, `.tools/godot/<version>/godot`, `godot` du PATH ; s'arrête avec un message si la version ne commence pas par `4.7.2.stable`. `tools/godot.ps1` : même logique avec `$env:GODOT` (exécutable *console* sous Windows).
- Produit `tools/check.sh <lint|data|import|test|render|web|all>` (`set -euo pipefail`, outils de `.venv/bin` s'ils existent). Cette tâche implémente `lint` (`gdlint scripts tests && gdformat --check scripts tests`), `import` (`tools/godot.sh --headless --path . --import`, **échec si la sortie contient `SCRIPT ERROR` ou `Parse Error`**) et `test` (`tools/godot.sh --headless --path . -s addons/gut/gut_cmdln.gd -gexit`). `data`, `render` et `web` arrivent aux tâches 2, 5/9 et 11. `all` enchaîne `lint`, `data`, `import`, `test`, `render`, `web`.
- Produit les réglages de `project.godot` :
  - `application/config/name="91350"`, `config/version="0.0.1"`, `config/features=PackedStringArray("4.7", "GL Compatibility")`
  - `rendering/renderer/rendering_method="gl_compatibility"` (et `.mobile`), `rendering/textures/canvas_textures/default_texture_filter=0`
  - `display/window/size/viewport_width=1280`, `viewport_height=720`, mode d'étirement désactivé (le compositeur gère l'échelle)
  - `physics/3d/physics_engine="Jolt Physics"`, `physics/common/physics_interpolation=true`
  - `debug/gdscript/warnings/untyped_declaration=2` (une déclaration non typée devient une erreur)
  - `editor_plugins/enabled=PackedStringArray("res://addons/gut/plugin.cfg")`
- Produit `.gutconfig.json` : `dirs = ["res://tests"]`, `include_subdirs = true`, `prefix = "test_"`, `should_exit = true`.
- Produit `tools/requirements.txt` : `gdtoolkit==4.5.0`, `jsonschema==4.26.0`, `pytest` (version épinglée au moment de l'installation).

- [ ] **Étape 1 : installer Godot** — écrire `.godot-version`, `tools/install_godot.sh`, `tools/godot.sh`, `tools/godot.ps1`.
  Lancer : `tools/install_godot.sh --templates web && tools/godot.sh --version` → attendu `4.7.2.stable.official.ed1daf0bf`.
- [ ] **Étape 2 : outils Python** — `python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt` ; `.venv/bin/gdlint --version` → `gdlint 4.5.0`.
- [ ] **Étape 3 : GUT 9.7.1** — ajouter le dépôt `bitwes/Gut` en lecture à la session, cloner le tag `v9.7.1` hors dépôt, copier `addons/gut/` (licence incluse).
- [ ] **Étape 4 : écrire le test qui échoue**

```gdscript
# tests/test_project_setup.gd
extends GutTest


func test_engine_matches_pinned_version() -> void:
	var pinned := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	var info := Engine.get_version_info()
	assert_eq("%d.%d.%d-%s" % [info.major, info.minor, info.patch, info.status], pinned)


func test_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_static_typing_is_enforced() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_physics_is_interpolated() -> void:
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))
```

- [ ] **Étape 5 : vérifier l'échec** — `tools/godot.sh --headless --path . -s addons/gut/gut_cmdln.gd -gexit` → échec (pas de `project.godot`).
- [ ] **Étape 6 : écrire** `project.godot`, `.gutconfig.json`, `.gitignore`, `.gitattributes` (`* text=auto eol=lf` ; binaires `png`, `ttf`), `tools/check.sh`, `tools/requirements.txt`.
- [ ] **Étape 7 : vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint` → 4 tests passent, lint sans erreur.
- [ ] **Étape 8 : committer** — `git mv BRIEF.md docs/BRIEF.md` puis deux commits : `chore: ajoute GUT 9.7.1` et `chore: squelette du projet Godot 4.7.2 et outillage`.

### Tâche 2 : Palette et validation des données

**Fichiers :**
- Créer : `assets_src/palette.json`, `data/schemas/palette.schema.json`, `tools/validate_data.py`, `tools/tests/test_validate_data.py`, `scripts/systems/rendering/palette.gd`, `tests/test_palette.gd`
- Modifier : `tools/check.sh` (sous-commande `data`)

**Interfaces :**
- Produit le format `assets_src/palette.json` : `{"name": "91350", "colors": [{"id": "beton_1", "hex": "#1b1d22", "group": "regime"}, …]}` — 32 couleurs au plus, `id` en `^[a-z][a-z0-9_]*$`, `hex` en `^#[0-9a-f]{6}$`, `group` ∈ `regime | quartier | neutre`.
- Identifiants imposés (le code et les tests s'y réfèrent) : `noir` (contours) et `blanc` en `neutre` ; `beton_1` à `beton_5` (du plus sombre au plus clair), `bleu_nuit`, `orange_sodium`, `rouge_propagande` en `regime` ; au moins 8 couleurs vives en `quartier`. Les valeurs sont un choix artistique fait à l'exécution, à partir de la palette de l'essai.
- Produit `tools/validate_data.py` : `validate(root: Path) -> list[str]` (messages d'erreur, vide = valide) et CLI (`python tools/validate_data.py`, code 0/1). Règles : `assets_src/palette.json` contre `data/schemas/palette.schema.json` ; tout `data/<type>/*.json` contre `data/schemas/<type>.schema.json` (schéma manquant = erreur) ; dans tout document validé, un tableau d'objets portant `id` a des `id` uniques ; les `hex` de la palette sont uniques.
- Produit `Palette` : `const PATH := "res://assets_src/palette.json"`, `const MAX_COLORS := 32`, `static func load_colors(path: String = PATH) -> Dictionary` (id → `Color`, dans l'ordre du fichier ; `{}` et `push_error` si le fichier manque, est invalide ou dépasse 32 couleurs).

- [ ] **Étape 1 : tests Python qui échouent** — `tools/tests/test_validate_data.py` : `test_repo_data_is_valid` (`validate(REPO) == []`) ; sur une copie dans `tmp_path` : `test_rejects_bad_hex` (`"#12345g"`), `test_rejects_duplicate_ids`, `test_rejects_duplicate_hex`, `test_rejects_more_than_32_colors` (33 couleurs), `test_data_file_without_schema_is_an_error` (`data/items/x.json` sans schéma). Chaque test de rejet vérifie `len(errors) == 1` et que le message nomme le fichier fautif.
- [ ] **Étape 2 : vérifier l'échec** — `.venv/bin/python -m pytest -q tools/tests` → `ModuleNotFoundError`.
- [ ] **Étape 3 : écrire** le schéma, la palette, `validate_data.py`, la sous-commande `data` (`python tools/validate_data.py && python -m pytest -q tools/tests`).
- [ ] **Étape 4 : vérifier** — `tools/check.sh data` → 6 tests passent, `Données valides.`
- [ ] **Étape 5 : test GDScript qui échoue**

```gdscript
# tests/test_palette.gd
extends GutTest

const REQUIRED: Array[String] = [
	"noir", "blanc", "beton_1", "beton_2", "beton_3", "beton_4", "beton_5",
	"bleu_nuit", "orange_sodium", "rouge_propagande",
]


func test_palette_fits_in_32_colors() -> void:
	assert_between(Palette.load_colors().size(), REQUIRED.size() + 8, Palette.MAX_COLORS)


func test_required_colors_exist() -> void:
	var colors := Palette.load_colors()
	for id: String in REQUIRED:
		assert_has(colors, id)


func test_concrete_ramp_goes_from_dark_to_light() -> void:
	var colors := Palette.load_colors()
	for step: int in range(1, 5):
		var darker: Color = colors["beton_%d" % step]
		var lighter: Color = colors["beton_%d" % (step + 1)]
		assert_lt(darker.get_luminance(), lighter.get_luminance())


func test_missing_file_gives_empty_palette() -> void:
	assert_eq(Palette.load_colors("res://absent.json"), {})
	assert_push_error("absent.json")
```

- [ ] **Étape 6 : vérifier l'échec, écrire `palette.gd`, vérifier** — `tools/check.sh import && tools/check.sh test` → tout passe. (Si GUT 9.7.1 nomme autrement l'assertion d'erreur attendue, l'adapter après lecture de `addons/gut/test.gd`.)
- [ ] **Étape 7 : committer** — `feat: palette partagée de 32 couleurs et validation des données`.

### Tâche 3 : EventBus et sauvegarde

**Fichiers :**
- Créer : `scripts/autoload/event_bus.gd`, `scripts/systems/save/save_codec.gd`, `scripts/autoload/save_manager.gd`, `tests/test_save_codec.gd`, `tests/test_save_manager.gd`
- Modifier : `project.godot` (section `[autoload]` : `EventBus`, `SaveManager`)

**Interfaces :**
- Produit `EventBus` (autoload, signaux seulement) : `signal game_saved(slot: int)`, `signal game_loaded(slot: int)`, `signal saturation_change_requested(target: float, duration: float)`.
- Produit `SaveCodec` (logique pure) :
  - `const CURRENT_VERSION := 1`
  - `static func encode(systems: Dictionary, saved_at: String) -> String` → JSON `{"save_version": 1, "saved_at": …, "systems": {…}}`
  - `static func decode(text: String) -> Dictionary` → données migrées vers `CURRENT_VERSION` (avec `save_version` rendu en `int` : le JSON de Godot lit tous les nombres en `float`), ou `{}` si le texte n'est pas une sauvegarde lisible
  - `static func migrate(data: Dictionary, migrations: Dictionary, target_version: int) -> Dictionary` → applique `migrations[v]` (un `Callable(Dictionary) -> Dictionary`) pour `v` de la version des données à `target_version - 1` ; `{}` si une étape manque ou si la version des données dépasse la cible
- Produit `SaveManager` (autoload) : `const SAVEABLE_GROUP := &"saveable"`, `var save_dir: String = "user://saves"`, `func slot_path(slot: int) -> String` (`<save_dir>/slot_<n>.json`), `func has_save(slot: int = 0) -> bool`, `func save_game(slot: int = 0) -> bool`, `func load_game(slot: int = 0) -> bool`.
- Contrat d'un nœud sauvegardable : membre du groupe `saveable` ; propriété `save_id: StringName` ; `save_state() -> Dictionary` (valeurs compatibles JSON) ; `load_state(state: Dictionary) -> void`.
- Comportement : `save_game` écrit dans un fichier temporaire puis le renomme (jamais de sauvegarde à moitié écrite) et émet `game_saved`. `load_game` ne touche à **rien** si le fichier manque ou si `decode` rend `{}` ; sinon il appelle `load_state` pour chaque nœud présent dans la sauvegarde (un nœud absent de la sauvegarde garde son état) et émet `game_loaded`.

- [ ] **Étape 1 : tests qui échouent** — `tests/test_save_codec.gd` :

```gdscript
extends GutTest


func test_round_trip_keeps_systems() -> void:
	var text := SaveCodec.encode({"player": {"position": [1.5, 0.0, -2.0]}}, "2026-11-11T12:00:00")
	var data := SaveCodec.decode(text)
	assert_eq(data["save_version"], SaveCodec.CURRENT_VERSION)
	assert_eq(data["saved_at"], "2026-11-11T12:00:00")
	assert_eq(data["systems"]["player"]["position"], [1.5, 0.0, -2.0])


func test_decode_rejects_unreadable_text() -> void:
	for text: String in ["", "pas du json", "[1, 2]", "{}", '{"save_version": "x"}', '{"save_version": 1}']:
		assert_eq(SaveCodec.decode(text), {}, text)


func test_decode_rejects_a_newer_version() -> void:
	var text := JSON.stringify({"save_version": SaveCodec.CURRENT_VERSION + 1, "systems": {}})
	assert_eq(SaveCodec.decode(text), {})


func test_migrate_applies_each_step_in_order() -> void:
	var migrations := {1: _rename_hero, 2: _add_water}
	var data := SaveCodec.migrate({"save_version": 1, "systems": {"hero": {}}}, migrations, 3)
	assert_eq(data["save_version"], 3)
	assert_eq(data["systems"], {"player": {"water": 100}})


func test_migrate_fails_when_a_step_is_missing() -> void:
	assert_eq(SaveCodec.migrate({"save_version": 1, "systems": {}}, {}, 2), {})


func _rename_hero(data: Dictionary) -> Dictionary:
	data["systems"]["player"] = data["systems"]["hero"]
	data["systems"].erase("hero")
	return data


func _add_water(data: Dictionary) -> Dictionary:
	data["systems"]["player"]["water"] = 100
	return data
```

  `tests/test_save_manager.gd` (une classe interne `FakeSaveable extends Node` avec `save_id` et `state`, `save_dir = "user://test_saves"` vidé dans `after_each`) : `test_save_then_load_restores_state` ; `test_load_without_file_returns_false` ; `test_corrupted_file_is_refused_and_state_is_kept` (fichier contenant `{"save_version": 1, "sys`) ; `test_node_missing_from_the_save_keeps_its_state` ; `test_signals_carry_the_slot` (`watch_signals(EventBus)` puis `assert_signal_emitted_with_parameters(EventBus, "game_saved", [2])`) ; `test_no_temporary_file_is_left` (le dossier ne contient que `slot_0.json`).
- [ ] **Étape 2 : vérifier l'échec** — `tools/check.sh test` → `SaveCodec` introuvable.
- [ ] **Étape 3 : écrire** `event_bus.gd`, `save_codec.gd`, `save_manager.gd`, les deux autoloads.
- [ ] **Étape 4 : vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint` → tout passe.
- [ ] **Étape 5 : committer** — `feat: EventBus et sauvegarde JSON versionnée avec migrations`.

### Tâche 4 : PixelSnap — les maths du pixel parfait

**Fichiers :**
- Créer : `scripts/systems/rendering/pixel_snap.gd`, `tests/test_pixel_snap.gd`

**Interfaces :**
- Produit `PixelSnap` (logique pure) :
  - `const BASE_SIZE := Vector2i(640, 360)`, `const PIXELS_PER_METER := 16.0`, `const TEXEL := 1.0 / PIXELS_PER_METER`, `const MARGIN := 1` (pixels basse résolution de marge autour de la vue)
  - `static func integer_scale(window_size: Vector2i) -> int` → `max(1, min(window.x / 640, window.y / 360))` en division entière
  - `static func low_res_size(window_size: Vector2i, scale: int) -> Vector2i` → `ceil(window / scale)` par axe, **sans** la marge
  - `static func snap_position(position: Vector3, camera_basis: Basis, texel: float) -> Vector3` → cale sur la grille les composantes selon la droite et le haut de la caméra, laisse la profondeur intacte
  - `static func display_offset(position: Vector3, snapped: Vector3, camera_basis: Basis, texel: float) -> Vector2` → décalage à appliquer à l'image, en pixels basse résolution, repère écran (x à droite, y vers le bas), pour qu'elle paraisse rendue depuis `position`

Algorithme (vérifié numériquement) :

```gdscript
var local := position * camera_basis  # coordonnées dans les axes de la caméra
var snapped_local := Vector3(snappedf(local.x, texel), snappedf(local.y, texel), local.z)
var snapped := camera_basis * snapped_local
var error := (position - snapped) * camera_basis / texel  # dans [-0.5, 0.5]
var offset := Vector2(-error.x, error.y)
```

- [ ] **Étape 1 : tests qui échouent** — `tests/test_pixel_snap.gd`, avec `ISO := Basis.from_euler(Vector3(deg_to_rad(-30.0), deg_to_rad(45.0), 0.0))` :

| Test | Assertion |
|---|---|
| `test_integer_scale` (paramétré) | 1280×720 → 2 ; 1920×1080 → 3 ; 3840×2160 → 6 ; 1366×768 → 2 ; 640×360 → 1 ; 320×200 → 1 ; 2560×1080 → 3 ; 1080×1920 → 1 |
| `test_low_res_size` | (1920×1080, 3) → 640×360 ; (1366×768, 2) → 683×384 ; (2560×1080, 3) → 854×360 ; (320×200, 1) → 320×200 |
| `test_snapped_position_lies_on_the_grid` | pour `Vector3(3.37, 12.11, -7.93)` : `local := snapped * ISO` a `x` et `y` multiples de `TEXEL` à 1e-4 près et `z` égal à celui de la position |
| `test_offset_stays_within_half_a_pixel` | 50 positions pseudo-aléatoires (graine fixe) : `abs(offset.x) <= 0.5` et `abs(offset.y) <= 0.5` |
| `test_position_on_the_grid_has_no_offset` | `display_offset(snapped, snapped, …)` vaut `Vector2.ZERO` |
| `test_offset_signs` | `snapped + ISO.x * 0.25 * TEXEL` → `offset.x ≈ -0.25` ; `snapped + ISO.y * 0.25 * TEXEL` → `offset.y ≈ +0.25` |
| `test_moving_one_texel_moves_the_snap_not_the_offset` | décaler la position de `ISO.x * TEXEL` décale `snapped` d'autant et laisse `offset` inchangé à 1e-4 près |

- [ ] **Étape 2 : vérifier l'échec** — `tools/check.sh test` → `PixelSnap` introuvable.
- [ ] **Étape 3 : écrire** `pixel_snap.gd`.
- [ ] **Étape 4 : vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint`.
- [ ] **Étape 5 : committer** — `feat: calcul d'échelle entière et calage de la caméra sur la grille de pixels`.

### Tâche 5 : PixelView — compositeur, contours et palette

**Fichiers :**
- Créer : `shaders/outline.gdshader`, `shaders/color_grade.gdshader`, `scripts/systems/rendering/pixel_view.gd`, `scenes/main/pixel_view.tscn`, `tests/test_pixel_view.gd`, `tests/render/test_pixel_render.gd`
- Modifier : `tools/check.sh` (sous-commande `render`)

**Interfaces :**
- Consomme : `PixelSnap` (tâche 4), `Palette.load_colors()` (tâche 2), `EventBus.saturation_change_requested` (tâche 3).
- Produit la scène `pixel_view.tscn` :

```
PixelView (Control, script pixel_view.gd)
└─ Container (SubViewportContainer : stretch = true, texture_filter = nearest)
   └─ World (SubViewport : own_world_3d = true)
      ├─ Outline (MeshInstance3D : QuadMesh 2×2, flip_faces, extra_cull_margin maximal, sans ombre, outline.gdshader)
      └─ Grade (CanvasLayer) └─ Rect (ColorRect plein cadre, color_grade.gdshader)
```

- Produit `PixelView` :
  - `signal scale_changed(scale: int)`
  - `@export var palette_path: String = Palette.PATH`
  - `var saturation: float` (0.0 = gris du régime, 1.0 = pleine couleur ; écrit dans le shader)
  - `func set_zone(zone: Node3D) -> void` (ajoute la zone sous `World`, libère la précédente), `func get_zone() -> Node3D`
  - `func get_world_viewport() -> SubViewport`, `func get_pixel_scale() -> int`, `func get_palette_size() -> int`, `func get_low_res_image() -> Image`
- Comportement :
  - **Mise en page** (au `_ready` et à chaque signal `resized`) : `N = PixelSnap.integer_scale(size)` ; `Container.stretch_shrink = N` ; `Container.size = (PixelSnap.low_res_size(size, N) + 2 × MARGIN) × N` ; position de base `(-N × MARGIN, -N × MARGIN)` ; émet `scale_changed(N)` si `N` change.
  - **Calage** (dans `_process`, avec `process_priority = 1000` pour passer après tout le gameplay) : pour la caméra orthographique courante de `World`, fixe `camera.size = World.size.y / PIXELS_PER_METER`, remplace sa position par `PixelSnap.snap_position(…)`, place `Container` à `base + round(display_offset × N)`. Sans caméra orthographique : décalage nul.
  - **Contrat avec la caméra** : `PixelView` *déplace* la caméra. Son propriétaire doit donc la remettre à sa position idéale à chaque image, sinon les corrections s'accumulent et la compensation sous-pixel devient fausse (voir tâches 6 et 8).
  - **Palette** : au `_ready`, charge `Palette.load_colors(palette_path)` et transmet au shader `palette` (tableau de 32 `vec3`), `palette_size` et la couleur `noir` aux contours. Palette vide → `palette_size = 0` (le shader laisse passer la couleur) et une erreur est journalisée.
  - **Saturation** : sur `EventBus.saturation_change_requested(target, duration)`, anime `saturation` vers `target` (immédiat si `duration <= 0`).
- `shaders/outline.gdshader` (spatial, `render_mode unshaded, fog_disabled`) : `uniform vec3 outline_color : source_color`, `uniform float threshold = 0.08`. Le cœur, validé par l'essai :

```glsl
void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}
// fragment : c, l, r, u, d = view_depth au centre et aux 4 voisins (1 pixel).
// En orthographique la profondeur est linéaire sur un plan : son laplacien y est nul,
// donc aucune fausse arête sur les pentes.
// edge = step(threshold, abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c));
// ALBEDO = mix(couleur_écran, outline_color, edge);
```

- `shaders/color_grade.gdshader` (`canvas_item`, lit `hint_screen_texture` en *nearest*) : `uniform vec3 palette[32]`, `uniform int palette_size = 0`, `uniform float saturation = 1.0`, `uniform float dither_strength = 0.04`. Ordre : luminance (0,299 / 0,587 / 0,114) → `mix(gris, couleur, saturation)` → décalage Bayer 4×4 indexé par `FRAGCOORD` → couleur de palette la plus proche (distance euclidienne en sRGB). `palette_size == 0` → couleur inchangée.
- `tools/check.sh render` : lance GUT **sans** `--headless` avec `--rendering-driver opengl3 --audio-driver Dummy -gdir=res://tests/render`, sous `xvfb-run -a -s "-screen 0 1280x720x24"` quand `DISPLAY` est vide.

- [ ] **Étape 1 : tests sans rendu qui échouent** — `tests/test_pixel_view.gd` (instancie `pixel_view.tscn`, fixe `size`, attend 2 images) :

| Test | Assertion |
|---|---|
| `test_layout` (paramétré) | 1280×720 → échelle 2, `World.size == Vector2i(642, 362)` ; 1920×1080 → 3 et 642×362 ; 1366×768 → 2 et 685×386 ; 320×200 → 1 et 322×202 |
| `test_resizing_updates_the_scale` | passer de 1280×720 à 1920×1080 émet `scale_changed(3)` |
| `test_camera_is_snapped_and_sized` | caméra orthographique à `Vector3(3.37, 12.11, -7.93)`, orientée (−30°, 45°) : après une image, ses coordonnées locales x et y sont multiples de `TEXEL` et `camera.size == World.size.y / 16.0` |
| `test_container_follows_the_subpixel_offset` | `Container.position == base + round(offset × échelle)` pour cette caméra |
| `test_saturation_request_is_applied` | `EventBus.saturation_change_requested.emit(0.0, 0.0)` → `saturation == 0.0` |
| `test_palette_is_sent_to_the_shader` | `get_palette_size() == Palette.load_colors().size()` |
| `test_missing_palette_disables_the_grade_pass` | avec `palette_path = "res://absent.json"` fixé avant l'entrée dans l'arbre : `get_palette_size() == 0`, la scène se charge, l'erreur est journalisée |

- [ ] **Étape 2 : vérifier l'échec, écrire** les shaders, `pixel_view.gd`, `pixel_view.tscn` ; **vérifier** `tools/check.sh import && tools/check.sh test`.
- [ ] **Étape 3 : tests avec rendu** — `tests/render/test_pixel_render.gd`. `should_skip_script()` rend un message quand `DisplayServer.get_name() == "headless"`. La scène d'essai est construite dans le test : sol clair, cube clair éclairé, cube `rouge_propagande`, caméra orthographique.

| Test | Assertion |
|---|---|
| `test_every_pixel_is_a_palette_color` | chaque pixel de `get_low_res_image()` appartient à la palette (0 pixel hors palette) |
| `test_outline_draws_the_darkest_color` | le nombre de pixels `noir` est > 0, et vaut 0 quand `Outline` est masqué |
| `test_grey_and_colour_differ` | l'image à `saturation = 0.0` diffère de celle à `1.0` et reste dans la palette |

- [ ] **Étape 4 : vérifier** — `tools/check.sh render` → 3 tests passent ; `tools/check.sh test` → les mêmes sont signalés ignorés, rien n'échoue.
- [ ] **Étape 5 : committer** — `feat: rendu pixel 2.5D (échelle entière, calage sous-pixel, contours, palette)`.

### Tâche 6 : CameraRig — caméra isométrique

**Fichiers :**
- Créer : `scripts/actors/camera_rig.gd`, `scenes/actors/camera_rig.tscn`, `tests/test_camera_rig.gd`
- Modifier : `project.godot` (actions `camera_rotate_left`, `camera_rotate_right`)

**Interfaces :**
- Produit `CameraRig extends Node3D` : `const PITCH_DEGREES := 30.0`, `const YAW_OFFSET_DEGREES := 45.0`, `const STEP_DEGREES := 90.0`, `const DISTANCE := 60.0`, `const ROTATION_SECONDS := 0.25` ; `@export var target: Node3D` ; `var yaw_step: int` (0 à 3) ; `func rotate_step(direction: int) -> void` ; `func get_target_yaw_degrees() -> float` (`45 + 90 × yaw_step`).
- Scène : `CameraRig` (interpolation physique désactivée) → `Camera3D` (orthographique, `near = 0.1`, `far = 200`, `current = true`, tournée de −30° en x, reculée de `DISTANCE` le long de son axe z).
- Comportement : dans `_process`, le rig se place sur `target.get_global_transform_interpolated().origin` (suivi rigide), **réécrit la transformation locale de la caméra** (tangage −30°, recul `DISTANCE`) et lit `Input.is_action_just_pressed` pour tourner : `camera_rotate_left` → `rotate_step(-1)`, `camera_rotate_right` → `rotate_step(1)`. Le lacet est animé sur `ROTATION_SECONDS` ; une rotation demandée pendant l'animation part du pas cible. Le rig ne cale rien : c'est `PixelView` qui s'en charge, et c'est parce que `PixelView` déplace la caméra que le rig la replace à chaque image.
- Actions : `camera_rotate_left` = touche physique Q + LB ; `camera_rotate_right` = touche physique E + RB. (Sur AZERTY, les mêmes emplacements sont A et E.)

- [ ] **Étape 1 : tests qui échouent** — `test_initial_view_is_isometric` (lacet 45°, caméra orthographique, tangage −30°) ; `test_rotate_step_wraps_both_ways` (4 × `rotate_step(1)` → `yaw_step == 0` ; `rotate_step(-1)` depuis 0 → 3 et `get_target_yaw_degrees() == 315.0`) ; `test_rotation_reaches_the_target_yaw` (après `ROTATION_SECONDS + 0.1` s, `rotation_degrees.y ≈ 135`) ; `test_rig_follows_its_target` (cible déplacée à `(4, 0, -3)` → le rig y est après une image) ; `test_rig_resets_the_camera_every_frame` (caméra décalée à la main de `(0.3, 0.2, 0)` → après une image, sa position locale vaut de nouveau `(0, 30, 51.96)` à 0,01 près) ; `test_rig_without_target_stays_put`.
- [ ] **Étape 2 : vérifier l'échec, écrire, vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint`.
- [ ] **Étape 3 : committer** — `feat: caméra isométrique orthographique avec rotation par pas de 90°`.

### Tâche 7 : Player — contrôleur clavier + manette

**Fichiers :**
- Créer : `scripts/actors/player.gd`, `scenes/actors/player.tscn`, `tests/test_player.gd`
- Modifier : `project.godot` (actions `move_left`, `move_right`, `move_up`, `move_down`, `run`)

**Interfaces :**
- Consomme : contrat sauvegardable (tâche 3).
- Produit `Player extends CharacterBody3D` :
  - `const WALK_SPEED := 2.5`, `const RUN_SPEED := 5.5` (m/s), `const ACCELERATION := 30.0` (m/s²), `const TURN_SPEED := 12.0` (rad/s), `const FALL_LIMIT := -20.0` (m)
  - `var save_id: StringName = &"player"`
  - `static func move_direction(input: Vector2, camera_yaw: float) -> Vector3` → `Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)`
  - `func save_state() -> Dictionary` → `{"position": [x, y, z], "yaw": float}` ; `func load_state(state: Dictionary) -> void` (ignore un état mal formé ; après un chargement, appelle `reset_physics_interpolation()`)
- Comportement (`_physics_process`) : `Input.get_vector("move_left", "move_right", "move_up", "move_down")` → direction relative au lacet de `get_viewport().get_camera_3d()` (0 s'il n'y a pas de caméra) → vitesse cible `RUN_SPEED` si `run` est maintenu, sinon `WALK_SPEED`, multipliée par la norme de l'entrée (un stick peu incliné marche lentement) → `move_toward` avec `ACCELERATION` → gravité → `move_and_slide()`. Le visuel se tourne vers la direction. Sous `FALL_LIMIT`, le joueur revient à sa position d'apparition, vitesse nulle.
- Scène : `Player` (groupe `saveable`) → `CollisionShape3D` (capsule r = 0,3 m, h = 1,75 m) + `Visual` (tête, torse, deux bras, deux jambes en `BoxMesh`, dimensions multiples de 1/16 m, couleurs de la palette). Placeholder remplacé par le pipeline voxel en M1 ; un balancement de marche procédural minimal est permis s'il tient en une trentaine de lignes.
- Actions (touches **physiques**, zone morte 0,2) : `move_*` = W/A/S/D + flèches + stick gauche + croix directionnelle ; `run` = Maj gauche + bouton B. La section `[input]` est générée par un script jetable appelant `ProjectSettings.save()`, puis relue dans le diff.

- [ ] **Étape 1 : tests qui échouent**

```gdscript
# tests/test_player.gd (extrait : les valeurs épinglées)
func test_move_direction_follows_the_camera_yaw() -> void:
	var yaw := deg_to_rad(45.0)
	assert_almost_eq(Player.move_direction(Vector2.UP, yaw), Vector3(-0.7071, 0.0, -0.7071), Vector3.ONE * 0.001)
	assert_almost_eq(Player.move_direction(Vector2.RIGHT, yaw), Vector3(0.7071, 0.0, -0.7071), Vector3.ONE * 0.001)
	assert_almost_eq(Player.move_direction(Vector2.UP, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)


func test_move_direction_keeps_the_stick_magnitude() -> void:
	assert_almost_eq(Player.move_direction(Vector2(0.5, 0.0), 1.3).length(), 0.5, 0.001)
	assert_eq(Player.move_direction(Vector2.ZERO, 1.3), Vector3.ZERO)
```

  Plus : `test_walks_when_an_action_is_pressed` (joueur sur un sol statique, `Input.action_press("move_right")`, 30 images physiques → `position.x > 0.5` ; relâché → s'arrête) ; `test_running_covers_more_ground_than_walking` ; `test_stays_on_the_floor` (`position.y` reste dans ±0,05 après 60 images) ; `test_falling_out_of_the_world_respawns` (placé à `y = FALL_LIMIT - 1` → revenu au point d'apparition) ; `test_save_state_round_trip` ; `test_load_state_ignores_malformed_data` (`{}`, `{"position": [1.0]}`, `{"position": "x"}` → position inchangée) ; `test_move_actions_use_physical_keys` (chaque `InputEventKey` des actions `move_*`, `run`, `camera_rotate_*` a `physical_keycode != 0` et `keycode == 0`) ; `test_move_actions_have_a_dead_zone` (`InputMap.action_get_deadzone(action) == 0.2`) ; `test_each_action_has_keyboard_and_gamepad` (au moins un événement clavier et un événement manette par action de jeu).
- [ ] **Étape 2 : vérifier l'échec, écrire, vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint`.
- [ ] **Étape 3 : committer** — `feat: contrôleur du joueur clavier et manette`.

### Tâche 8 : Zone de test et scène principale

**Fichiers :**
- Créer : `shaders/debug_grid.gdshader`, `scenes/zones/test_zone.tscn`, `scripts/main/main.gd`, `scenes/main/main.tscn`, `tests/test_test_zone.gd`, `tests/test_main.gd`
- Modifier : `project.godot` (`run/main_scene`, actions `quick_save` F5, `quick_load` F9, `toggle_fullscreen` F11, `debug_toggle_color` F2)

**Interfaces :**
- Consomme : `PixelView.set_zone` (tâche 5), `CameraRig` (tâche 6), `Player` (tâche 7), `SaveManager`, `EventBus` (tâche 3).
- Produit `scenes/zones/test_zone.tscn` — « la dalle », boîtes grises écrites à la main en `CSGBox3D` (`use_collision = true`) : sol 48×48 m (damier d'1 m, `debug_grid.gdshader`), quatre murets d'enceinte, deux « tours » (12×24×12 m et 16×9×8 m), un bloc bas, une rampe vers une plateforme à 1,5 m, cinq caisses d'1 m aux couleurs vives du groupe `quartier`, un panneau `rouge_propagande`, un lampadaire avec `OmniLight3D` `orange_sodium`, un `DirectionalLight3D` avec ombres, un `WorldEnvironment` (fond `bleu_nuit`, lumière ambiante), une instance `Player` en `(0, 0.1, 6)`, une instance `CameraRig` dont `target` pointe le joueur. Tous les matériaux prennent leurs couleurs dans la palette.
- Produit `scenes/main/main.tscn` : `Main` (Node, `main.gd`) → `PixelView` (instance, plein cadre) + `UI` (CanvasLayer, rempli à la tâche 10).
- Produit `main.gd` (`class_name Main extends Node`) : `const DEFAULT_ZONE := "res://scenes/zones/test_zone.tscn"`, `const COLOR_FADE_SECONDS := 1.5` ; `func load_zone(path: String) -> bool` (instancie la scène dans `PixelView` ; `false` et `push_error` si elle ne se charge pas). Au démarrage : `load_zone(DEFAULT_ZONE)`, puis `print("[91350] prêt")` après la première image. Dans `_unhandled_input` : `quick_save` → `SaveManager.save_game()`, `quick_load` → `SaveManager.load_game()`, `toggle_fullscreen` → bascule fenêtré/plein écran, `debug_toggle_color` → `EventBus.saturation_change_requested.emit(cible, COLOR_FADE_SECONDS)` en alternant 0.0 et 1.0.

- [ ] **Étape 1 : tests qui échouent** — `tests/test_test_zone.gd` : `test_zone_has_one_player_and_an_orthographic_camera` ; `test_player_rests_on_the_ground` (60 images physiques → `abs(player.position.y) < 0.1`) ; `test_player_cannot_leave_the_slab` (`run` et `move_up` maintenus 300 images physiques → le joueur reste dans ±24 m). `tests/test_main.gd` : `test_main_loads_the_default_zone` ; `test_load_zone_refuses_a_missing_scene` (`load_zone("res://absent.tscn") == false`, zone courante inchangée) ; `test_quick_save_then_quick_load_restores_the_player` (sauver, déplacer le joueur, charger → position d'origine) ; `test_camera_snap_does_not_accumulate` (pendant 30 images, déplacer le joueur de `(0.013, 0, 0.007)` par image ; à chaque image, la caméra est à moins de 1e-3 de `PixelSnap.snap_position(idéal, …)`, où `idéal` est recalculé depuis la position du joueur et `DISTANCE`).
- [ ] **Étape 2 : vérifier l'échec, écrire, vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh lint`.
- [ ] **Étape 3 : contrôle visuel** — lancer le jeu sous Xvfb, enregistrer une capture provisoire et **la regarder** : contours visibles, lignes 2:1 nettes, ombres, couleurs de la palette.
- [ ] **Étape 4 : committer** — `feat: zone de test et scène principale jouable`.

### Tâche 9 : Mode capture d'écran

**Fichiers :**
- Modifier : `scripts/main/main.gd`, `tools/check.sh` (`render`), `tests/test_main.gd`
- Créer : `tests/render/test_screenshot.gd`

**Interfaces :**
- Produit dans `main.gd` : `const SCREENSHOT_DIR := "res://build/screenshots"`, `const SCREENSHOT_FRAMES := 30` ; `static func parse_screenshot_scene(args: PackedStringArray) -> String` (chemin `res://…` de la scène demandée, `""` sinon) ; `func save_screenshot(path: String) -> Error`.
- Comportement : `godot --path . -- --screenshot <scène>` charge la scène à la place de la zone par défaut, attend `SCREENSHOT_FRAMES` images, enregistre `build/screenshots/<nom de la scène>.png` (dossier créé au besoin), affiche le chemin, quitte avec le code 0. Scène introuvable → message d'erreur et code 1. Le mode ne fonctionne pas avec `--headless` (pas de rendu) : il le dit et sort en code 1.
- `tools/check.sh render` enchaîne désormais les tests de rendu **puis** la capture de `test_zone`, et échoue si `build/screenshots/test_zone.png` manque ou pèse moins de 2 ko.

- [ ] **Étape 1 : tests qui échouent** — dans `tests/test_main.gd`, `Main.parse_screenshot_scene(args)` :

| Arguments | Résultat attendu |
|---|---|
| `["--screenshot", "res://scenes/zones/test_zone.tscn"]` | `"res://scenes/zones/test_zone.tscn"` |
| `["--screenshot", "scenes/zones/test_zone.tscn"]` | `"res://scenes/zones/test_zone.tscn"` |
| `["--autre", "x", "--screenshot", "res://b.tscn"]` | `"res://b.tscn"` |
| `[]`, `["--screenshot"]`, `["--autre"]` | `""` |

  `tests/render/test_screenshot.gd` : `test_screenshot_is_written` (`save_screenshot("user://essai.png") == OK`, le fichier existe, sa taille est celle de la fenêtre, il contient au moins 4 couleurs distinctes).
- [ ] **Étape 2 : vérifier l'échec, écrire, vérifier** — `tools/check.sh test && tools/check.sh render` ; ouvrir `build/screenshots/test_zone.png` et la regarder.
- [ ] **Étape 3 : committer** — `feat: mode --screenshot pour la vérification visuelle`.

### Tâche 10 : Interface minimale, traductions, police, crédits

**Fichiers :**
- Créer : `assets/fonts/monogram-extended.ttf` (+ `.import` : sans anticrénelage, sans *hinting*), `assets/ASSETS.md`, `locale/strings.csv`, `scripts/ui/debug_hud.gd`, `tests/test_ui.gd`
- Modifier : `scenes/main/main.tscn` (contenu de `UI`), `scripts/main/main.gd` (échelle de l'UI), `project.godot` (police par défaut, traductions, locale de repli `fr`, action `toggle_credits` F1 + bouton Select)

**Interfaces :**
- Consomme : `PixelView.scale_changed` (tâche 5), `EventBus.game_saved` / `game_loaded` (tâche 3).
- Produit `locale/strings.csv` (colonnes `keys,fr`) : `HUD_CONTROLS`, `HUD_SAVED`, `HUD_LOADED`, `CREDITS_TITLE`, `CREDITS_BODY`. `CREDITS_BODY` cite Godot Engine (licence MIT, godotengine.org/license) et la police (CC0) ; l'attribution OpenStreetMap s'y ajoutera en M1 avec les données.
- Produit l'UI, dessinée en pixels basse résolution : `UI.scale = Vector2(N, N)` mis à jour sur `scale_changed`. `DebugHud` (Control) contient : l'aide des commandes, une ligne `version · IPS` rafraîchie deux fois par seconde, un message de 2 s sur `game_saved` / `game_loaded`, et un panneau Crédits masqué que `toggle_credits` affiche ou cache.
- `assets/ASSETS.md` : un tableau `asset | source | licence | statut` ; première ligne : la police.

- [ ] **Étape 1 : tests qui échouent** — `tests/test_ui.gd` : `test_every_key_is_translated_in_french` (pour chaque clé du CSV, `tr(key) != key`) ; `test_font_has_french_glyphs` (la police par défaut répond `has_char` pour chaque caractère de `àâäçéèêëîïôöùûüÿœæÀÂÇÉÈÊËÎÏÔÙÛÜŒ«»’…—·`) ; `test_ui_scale_follows_the_pixel_scale` (`scale_changed(3)` → `UI.scale == Vector2(3, 3)`) ; `test_credits_toggle` ; `test_saving_shows_a_message` (`EventBus.game_saved.emit(0)` → le message vaut `tr("HUD_SAVED")`).
- [ ] **Étape 2 : vérifier l'échec, écrire, vérifier** — `tools/check.sh import && tools/check.sh test && tools/check.sh render` ; regarder la capture : texte net, accents présents, lisible à 640×360. Si un glyphe manque, passer à Pixel Operator et le noter dans `ASSETS.md`.
- [ ] **Étape 3 : committer** — `feat: interface minimale, traductions et crédits`.

### Tâche 11 : Export web, CI et GitHub Pages

**Fichiers :**
- Créer : `export_presets.cfg`, `tools/web_smoke.mjs`, `.github/workflows/ci.yml`, `.github/ISSUE_TEMPLATE/bug.yml`, `.github/ISSUE_TEMPLATE/playtest.yml`
- Modifier : `tools/check.sh` (sous-commande `web`)

**Interfaces :**
- Produit le preset `Web` : `variant/thread_support=false`, `variant/extensions_support=false`, `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true`, `progressive_web_app/enabled=false`, `export_filter="all_resources"`, `include_filter="assets_src/palette.json,data/*"`, `exclude_filter="addons/gut/*,tests/*,tools/*,docs/*,build/*"`.
- Produit `tools/check.sh web` : `tools/godot.sh --headless --path . --export-release "Web" build/web/index.html`, puis échec si `index.html`, `index.wasm` ou `index.pck` manque.
- Produit `tools/web_smoke.mjs` (vérification locale, hors CI — Node + Playwright, préinstallés en session cloud) : sert `build/web`, ouvre la page dans Chromium (`--use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist`), attend `[91350] prêt` dans la console, capture `build/screenshots/web_1.png`, maintient la touche D une seconde, capture `web_2.png`. Échec si une erreur apparaît dans la console, si le marqueur n'arrive pas en 60 s ou si les deux captures sont identiques.
- Produit `.github/workflows/ci.yml` :

```yaml
name: CI
on:
  push:
  pull_request:
  workflow_dispatch:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  checks:
    # Un push sur une branche du dépôt est déjà couvert par l'événement push.
    if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name != github.repository
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with: { python-version: "3.13", cache: pip, cache-dependency-path: tools/requirements.txt }
      - run: pip install -r tools/requirements.txt
      - run: tools/check.sh lint
      - run: tools/check.sh data
      - uses: actions/cache@v6
        with:
          path: |
            .tools/godot
            ~/.local/share/godot/export_templates
          key: godot-${{ hashFiles('.godot-version') }}
      - run: tools/install_godot.sh --templates web
      - run: tools/check.sh import
      - run: tools/check.sh test
      - run: sudo apt-get install -y --no-install-recommends xvfb libgl1-mesa-dri
      - run: tools/check.sh render
      - uses: actions/upload-artifact@v7
        if: always()
        with: { name: captures, path: build/screenshots, if-no-files-found: ignore }
      - run: tools/check.sh web
      - uses: actions/upload-pages-artifact@v5
        with: { path: build/web }
  deploy:
    needs: checks
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-24.04
    permissions: { pages: write, id-token: write }
    environment: { name: github-pages, url: "${{ steps.deploy.outputs.page_url }}" }
    steps:
      - id: deploy
        uses: actions/deploy-pages@v5
```

- Gabarits d'issues : `bug.yml` (version du jeu, plateforme et navigateur, étapes, attendu / obtenu, capture) et `playtest.yml` (durée de jeu, ce qui a plu, ce qui a bloqué, clarté des commandes, fluidité, remarques libres).

- [ ] **Étape 1 : export** — écrire le preset et `check.sh web` ; `tools/check.sh web` → `build/web/index.{html,wasm,pck}` présents.
- [ ] **Étape 2 : essai dans le navigateur** — écrire `tools/web_smoke.mjs` ; `node tools/web_smoke.mjs` → `OK` ; regarder `web_1.png` et `web_2.png` (même rendu que sur bureau, le joueur a bougé). Vérifier au passage que F5 ne recharge pas la page quand le canvas a le focus ; sinon déplacer `quick_save` / `quick_load` sur F6 / F8.
- [ ] **Étape 3 : CI** — écrire `ci.yml` et les gabarits, committer (`ci: vérifications, export web et déploiement GitHub Pages`) et pousser.
- [ ] **Étape 4 : vérifier la CI** — lire l'exécution sur GitHub : le job `checks` est vert, l'artefact `captures` contient `test_zone.png`. Si le push des workflows est refusé (permission `workflows` de l'application GitHub), s'arrêter et le signaler : voir Risques.

### Tâche 12 : Documentation technique

**Fichiers :**
- Créer : `CLAUDE.md`, `CHANGELOG.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, `docs/LEGAL.md`
- Modifier : `README.md`, `assets/ASSETS.md`

**Contenu attendu :**
- `README.md` : le jeu en un paragraphe ; état (M0) ; lien vers le build web ; **version de Godot épinglée** ; installation (Windows, Linux, macOS ; variable `GODOT`) ; lancer le jeu ; `tools/check.sh all` ; arborescence ; crédits et licences.
- `CLAUDE.md` (**≤ 150 lignes**) : renvoi vers `docs/BRIEF.md` à relire en début de session ; version épinglée ; commandes (`tools/install_godot.sh`, `tools/check.sh …`, capture d'écran, essai web) ; conventions (typage, nommage, traductions, constantes nommées, commits) ; règles de travail du brief §3 ; particularités des sessions cloud (Xvfb, `add_repo` pour récupérer un addon, branche de session).
- `CHANGELOG.md` : format *Keep a Changelog*, section `0.0.1` pour M0.
- `docs/ROADMAP.md` : M0 à M5 en cases à cocher ; les cases M0 cochées une à une avec la preuve (commande ou lien).
- `docs/DECISIONS.md` : les 11 décisions par défaut de ce plan, datées et justifiées, plus celles prises en route (police retenue, touches de sauvegarde rapide sur le web, etc.).
- `docs/LEGAL.md` : attribution et licence OpenStreetMap (ODbL), y compris pour les données dérivées de `tools/osm_import/data/` ; œuvres protégées de la Grande Borne (s'inspirer et styliser, ne jamais copier ; l'exception de panorama exclut l'usage commercial) ; fiction assumée ; licences des tiers (Godot, GUT, Dialogue Manager, police) ; statut du code du dépôt public (aucune licence = tous droits réservés) ; liste « à faire valider par un juriste avant la sortie commerciale ».

- [ ] **Étape 1 : écrire** les six fichiers.
- [ ] **Étape 2 : vérifier** — `wc -l CLAUDE.md` ≤ 150 ; chaque commande citée dans `README.md` et `CLAUDE.md` a été exécutée telle quelle ; `4.7.2` apparaît dans `README.md`, `CLAUDE.md` et `.godot-version`.
- [ ] **Étape 3 : committer** — `docs: README, CLAUDE.md, feuille de route, décisions et cadre légal`.

### Tâche 13 : `docs/GDD.md`

**Contenu attendu** (brouillon à valider, en français, 100 % fictif — brief §16) : le jeu en une phrase et les 5 piliers ; boucle de jeu ; les 15 systèmes du brief §9 avec, pour chacun, règles, données, signaux `EventBus` envisagés et jalon ; le monde et la table des zones ; le régime (forces, contrôle, novlangue, propagande dynamique, l'eau) ; les 12 personnages du brief §8 ; **10 personnages secondaires proposés** (fiche : rôle, voix, lieu, quêtes) ; les **8 quêtes de l'acte 1** détaillées (donneur, prérequis, étapes avec types d'objectif, embranchements, récompenses) ; progression et économie ; interface, accessibilité, direction artistique et sonore ; **5 propositions de titre** avec une ligne d'argument chacune ; questions ouvertes. Les actes 2 à 4 n'ont qu'un paragraphe de cadrage (leur trame vient après l'acte 1).

- [ ] **Étape 1 : écrire** `docs/GDD.md`.
- [ ] **Étape 2 : vérifier** — 5 titres ; 10 fiches secondaires complètes ; 8 quêtes ; chaque personnage a une motivation, une voix et un trait qui casse le cliché ; aucun rôle lié à une origine ou une religion ; tous les personnages liés à la violence, aux armes ou aux trafics sont majeurs ; aucune personne ni marque réelle.
- [ ] **Étape 3 : committer** — `docs: première version du GDD`.

### Tâche 14 : `docs/TON.md`

**Contenu attendu** (brouillon à valider avant toute écriture en masse — brief §11) : principes des deux registres ; **20 répliques d'exemple pour le quartier** et **20 pour le régime** (dont GRAND FRÈRE s'adressant à un citoyen par son prénom) ; les trois tons de réponse (Calme / Cash / Malin) illustrés sur une même situation ; tics de langage par personnage principal ; lexique d'argot et de novlangue avec dosage ; contraintes de forme (2 lignes par bulle à 640×360, longueur de ligne mesurée avec la police retenue) ; ce qu'on n'écrit jamais (garde-fous du brief §16).

- [ ] **Étape 1 : écrire** `docs/TON.md`.
- [ ] **Étape 2 : vérifier** — 20 + 20 répliques ; aucune ne dépasse 2 lignes à la longueur mesurée ; garde-fous respectés.
- [ ] **Étape 3 : committer** — `docs: guide d'écriture TON.md`.

### Tâche 15 : Vérification finale, revue, PR et récap

- [ ] **Étape 1 : tout relancer depuis un clone propre** — `git clone` dans un dossier temporaire, puis `tools/install_godot.sh --templates web && tools/check.sh all && node tools/web_smoke.mjs`. Lire toute la sortie ; regarder `test_zone.png`, `web_1.png`, `web_2.png`.
- [ ] **Étape 2 : revue indépendante** de la branche entière (revue de code), corriger ce qui est confirmé.
- [ ] **Étape 3 : cocher** `docs/ROADMAP.md` et compléter `CHANGELOG.md`.
- [ ] **Étape 4 : ouvrir la PR** `claude/zen-ride-bebvan` → `main`, titre « M0 — Fondations », avec captures, liste de vérification et les deux actions manuelles ci-dessous.
- [ ] **Étape 5 : proposer** (avec demande d'approbation) un script de préparation pour l'environnement cloud : si le dossier `91350` existe, `tools/install_godot.sh --templates web` puis installation de `tools/requirements.txt`.
- [ ] **Étape 6 : récap en 10 lignes max** — ce qui marche, comment lancer le jeu, ce qui reste à faire.

## Définition de « terminé » pour M0

| Critère du brief (§17) | Preuve |
|---|---|
| On se déplace dans une scène test au rendu pixel net, sans scintillement | Tests des tâches 4 à 8 ; captures bureau et web regardées ; essai manuel du build web |
| CI verte | Job `checks` vert sur la PR |
| Build web jouable en ligne | Après fusion sur `main` : job `deploy` vert et page GitHub Pages jouable |
| Clavier + manette, EventBus, sauvegarde, mode capture d'écran, docs de base | Tests des tâches 3, 7, 9 ; fichiers des tâches 12 à 14 |

**Deux actions manuelles** (je ne peux pas les faire à ta place) :
1. Activer GitHub Pages : *Settings → Pages → Build and deployment → Source : GitHub Actions*.
2. Pour bloquer la fusion quand la CI échoue : *Settings → Rules → Rulesets* sur `main`, exiger le contrôle `checks`.

## Risques

| Risque | Parade |
|---|---|
| Le push des fichiers `.github/workflows/` est refusé à l'application GitHub (permission `workflows`) | Je m'arrête et te le signale : soit tu accordes la permission, soit tu déposes toi-même le fichier que je te fournis. |
| `add_repo` refusé pour `bitwes/Gut` | Tu ajoutes l'addon depuis l'Asset Library de l'éditeur, ou tu autorises le dépôt. |
| Le personnage « ondule » d'un pixel en marchant (la caméra est calée, pas lui) | Évalué sur le build web ; parade possible : caler aussi la position *visuelle* du joueur. |
| Contours sur un vrai GPU ≠ rendu logiciel testé ici | Capture comparée sur ta machine et sur le build web ; seuil `threshold` ajustable. |
| Ombres directionnelles qui scintillent en basse résolution | Réglage de la distance et du biais des ombres, sinon ombres désactivées en M0. |
| F5 / F11 interceptées par le navigateur | Vérifié à la tâche 11 ; repli sur F6 / F8. |
| Godot 4.8 sort pendant M0 | On reste en 4.7.2 (décision 11). |
| Runner GitHub sans Mesa | Paquet `libgl1-mesa-dri` installé explicitement dans la CI. |
