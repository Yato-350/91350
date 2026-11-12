# 91350

Un **action-RPG d'infiltration en pixel art 2.5D**. Dans une France fictive tombée sous
un régime de surveillance, **Akan**, un jeune adulte de **Grigny (Essonne, 91350)**, part
de sa tour pour soulever son quartier, puis la ville, puis l'Essonne — jusqu'à la
libération de Paris.

> Œuvre de fiction. Le régime, ses dirigeants et ses symboles sont inventés ; toute
> ressemblance avec des personnes réelles serait fortuite.

## Jouer

- **Dans le navigateur** : <https://yato-350.github.io/91350/> (build de `main`, publié
  par la CI ; demande que GitHub Pages soit activé sur le dépôt).
- **Depuis les sources** : voir « Installer et lancer ».

| Action | Clavier (position des touches) | Manette |
|---|---|---|
| Bouger | ZQSD (WASD en QWERTY) ou flèches | Stick gauche ou croix |
| Courir | Maj | B |
| Tourner la caméra | A / E (Q / E en QWERTY) | LB / RB |
| Sauvegarde / chargement rapides | F5 / F9 | — |
| Gris ↔ couleur (démonstration) | F2 | — |
| Crédits | F1 | Select |
| Plein écran | F11 | — |

## Installer et lancer

Le projet utilise **Godot 4.7.2-stable** (version épinglée dans `.godot-version`), en
GDScript typé, avec le renderer Compatibility.

**Linux**

```bash
tools/install_godot.sh --templates web
```

```bash
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
```

```bash
tools/godot.sh --path . --import
```

```bash
tools/godot.sh --path .
```

**Windows et macOS** : installe [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/),
puis indique son exécutable dans la variable d'environnement `GODOT` (sous Windows,
l'exécutable *console*). `tools/godot.sh` (Git Bash) et `tools/godot.ps1` (PowerShell)
lancent alors la bonne version et refusent toute autre. On peut aussi simplement ouvrir
`project.godot` dans l'éditeur.

## Vérifier

Les mêmes commandes tournent en local et dans la CI :

```bash
tools/check.sh all
```

| Sous-commande | Rôle |
|---|---|
| `lint` | `gdlint` et `gdformat --check` sur `scripts/`, `tests/`, `tools/` |
| `data` | Schémas JSON des données, puis tests du validateur |
| `import` | Import Godot, puis chargement de chaque script, scène, ressource et shader |
| `test` | Tests GUT sans affichage |
| `render` | Tests de rendu et capture de la zone de test (écran virtuel Xvfb si besoin) |
| `screenshot <scène>` | Capture `build/screenshots/<scène>.png` |
| `web` | Export web mono-thread dans `build/web/` |

Essai du build web dans Chromium (Node et Playwright requis) :

```bash
node tools/web_smoke.cjs
```

## Arborescence

```
addons/        GUT (tests)
assets/        généré + importé (police, thème) — voir assets/ASSETS.md
assets_src/    sources texte des assets (palette)
data/          données du jeu en JSON + schémas
docs/          brief, GDD, feuille de route, décisions, ton, cadre légal, plans
locale/        traductions (CSV)
scenes/        main/ zones/ actors/
scripts/       autoload/ systems/ actors/ main/ ui/
shaders/       contours, palette, damier de test
tests/         tests GUT (tests/render/ exige un vrai rendu)
tools/         installation de Godot, vérifications, validation des données
```

## Documentation

- [`docs/BRIEF.md`](docs/BRIEF.md) — le brief permanent du projet
- [`docs/GDD.md`](docs/GDD.md) — game design
- [`docs/TON.md`](docs/TON.md) — guide d'écriture
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — jalons
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — choix techniques datés
- [`docs/LEGAL.md`](docs/LEGAL.md) — licences, attributions, points à faire valider

## Crédits et licences

- Moteur : [Godot Engine](https://godotengine.org/license) (MIT).
- Police : Tiny5, The Tiny5 Project Authors (SIL Open Font License 1.1).
- Tests : [GUT](https://github.com/bitwes/Gut) (MIT), non distribué avec le jeu.
- Le code et le contenu du jeu ne sont pas sous licence libre : tous droits réservés.

Détails dans [`docs/LEGAL.md`](docs/LEGAL.md) et [`assets/ASSETS.md`](assets/ASSETS.md).
