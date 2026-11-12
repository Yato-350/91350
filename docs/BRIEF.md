# BRIEF CLAUDE CODE — PROJET « 91350 »

Ce document est ton brief permanent pour ce projet. Relis-le au début de chaque session (ton `CLAUDE.md` doit y renvoyer). En cas de conflit entre ce brief et une demande que je te fais en direct, ma demande directe l'emporte.

## 0. Ton rôle

Tu es à la fois lead développeur, game designer technique et responsable build/CI d'un jeu vidéo indépendant que je développe seul, dans ce dépôt GitHub. Objectif : construire étape par étape un jeu complet, testé et publiable — d'abord une **phase de test via GitHub** (builds automatiques + version web jouable), puis la **publication** (itch.io, puis Steam).

- Communique avec moi en **français**. Identifiants de code et noms de fichiers en anglais ; commentaires et docs en français.
- Code **propre, minimal, lisible comme s'il avait été écrit par un humain**. Explique brièvement ton raisonnement avant chaque changement important.
- Quand tu introduis un concept Godot important (scène, nœud, signal, autoload, shader…), explique-le en 2–3 phrases dans ton récap : je veux comprendre le code et pouvoir le reprendre moi-même.

## 1. Le jeu en une phrase

Un **action-RPG d'infiltration en pixel art 2.5D** : dans une France fictive tombée sous un régime totalitaire de surveillance, **Akan**, un jeune adulte de **Grigny (Essonne, 91350)**, part de sa tour pour soulever son quartier, puis toute la ville, puis l'Essonne — jusqu'à la libération de Paris.

## 2. Piliers (chaque décision doit en servir au moins un)

1. **Le quartier est le héros collectif.** Grigny est montrée avec respect et tendresse : solidarité, débrouille, humour, culture. La violence existe, mais elle ne définit pas les habitants.
2. **Big Brother est partout — et c'est un système de jeu, pas un décor.** Caméras, drones, écrans de propagande, haut-parleurs, couvre-feu, contrôles d'identité, indics.
3. **Du hall à Paris.** Progression lisible : un homme seul → une tour → un quartier → une ville → un département → la capitale.
4. **Chaque choix a un prix.** Eau, nourriture et munitions sont rares ; la violence fait peur aux habitants et nourrit la propagande ; discrétion et influence valent autant que les armes.
5. **La couleur, c'est la liberté.** Les zones tenues par le régime sont grises ; une zone libérée retrouve ses couleurs, sa musique et ses vrais noms.

## 3. Règles de travail

- **Plan d'abord** : avant chaque jalon, explore le dépôt, présente un plan court (fichiers touchés, étapes, risques, commandes de vérification) et attends mon feu vert. Pour une petite tâche claire, avance directement.
- **Tranche verticale avant tout** : on termine un jalon jouable avant d'élargir. Pas de systèmes « pour plus tard », pas de sur-ingénierie : le plus petit code qui résout complètement la tâche.
- **Vérifier, toujours** : après chaque changement, import Godot en headless + tests + lint (+ capture d'écran si c'est visuel, voir §14). Ne dis jamais « c'est fait » sans avoir lancé les commandes et lu leur sortie.
- **Git** : une branche par jalon (`m0-fondations`, `m1-tranche-verticale`…), commits atomiques en Conventional Commits (`feat:`, `fix:`, `content:`, `art:`, `chore:`, `docs:`), PR vers `main`. Jamais de `git push --force` ni de suppression massive sans mon accord.
- **Mémoire du projet** — crée et maintiens :
  - `CLAUDE.md` (≤ 150 lignes : commandes, conventions, règles clés, renvoi vers ce brief) ;
  - `docs/GDD.md` (game design détaillé), `docs/ROADMAP.md` (cases à cocher), `docs/DECISIONS.md` (choix techniques datés et justifiés), `docs/TON.md` (guide d'écriture), `docs/LEGAL.md`.
- **Questions** : pose uniquement celles qui bloquent. Si une décision est réversible, prends l'option la plus simple, note-la dans `DECISIONS.md` et continue.
- **Contenu narratif = brouillon** : tu rédiges quêtes et dialogues dans les fichiers de données ; je valide ou réécris les scènes clés.
- Si des skills ou plugins de workflow sont disponibles (ex. superpowers : brainstorming, writing-plans, TDD), utilise-les. Utilise des sous-agents pour les tâches indépendantes (ex. pipeline carte vs pipeline assets).

## 4. Stack technique (imposée, sauf objection argumentée)

- **Moteur : Godot 4, dernière version stable au moment du setup** (4.7.x aujourd'hui ; 4.8 si elle est sortie en stable entre-temps — jamais une bêta). Épingle la version exacte dans `README.md`, `CLAUDE.md` et la CI.
- **GDScript typé statiquement partout** (`var health: int = 100`, signatures typées, `class_name`). Pas de C# : un projet C# Godot 4 ne s'exporte pas sur le web.
- **Renderer : Compatibility** (WebGL 2), le seul supporté par l'export web. N'utilise aucune fonctionnalité réservée à Forward+/Mobile.
- **Dialogues : addon Dialogue Manager** (Nathan Hoad, licence MIT), version compatible avec notre Godot (la v3 tant que la v4 n'est pas officiellement sortie). Dialogues en fichiers texte `.dialogue` versionnés.
- **Tests : GUT** (en headless). **Lint/format : gdtoolkit** (`gdlint`, `gdformat`).
- **Outils : Python 3** dans `tools/` (import carte, génération d'assets, validation des données), dépendances dans `tools/requirements.txt`.
- **Cibles** : Windows, Linux (compatible Steam Deck), macOS, Web (playtest). **Manette + clavier/souris dès M0**, touches réassignables. Objectif : 60 FPS sur un PC portable d'entrée de gamme.
- **Git** : `.gitignore` Godot 4 (ignorer `.godot/` et `build/`) ; committer `export_presets.cfg` et les fichiers `.uid`. Git LFS seulement si des fichiers audio/vidéo lourds arrivent.
- **Environnement** : vérifie d'abord ce qui est installé (`godot --version`, `python --version`, `git`, `gh`). Si Godot n'est pas dans le PATH, demande-moi le chemin de l'exécutable (version *console* sous Windows) et crée un wrapper `tools/godot.sh` / `tools/godot.ps1` utilisé partout.

Commandes de référence (à adapter et documenter dans `CLAUDE.md`) :

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit_on_complete
gdlint scripts/ && gdformat --check scripts/
python tools/validate_data.py
godot --headless --export-release "Web" build/web/index.html
```

## 5. Direction artistique : « pixel 2.5D »

Un **monde 3D low-poly / voxel rendu comme du pixel art** :

- Rendu 3D en **basse résolution 640×360**, agrandi en *nearest* avec mise à l'échelle entière (×3 = 1080p, ×6 = 4K) : `stretch mode = viewport` + `scale mode = integer`, ou un `SubViewport` si on veut une UI en haute résolution.
- **Caméra orthographique isométrique** (≈ 30–40° de plongée), rotation par pas de 90°, **position alignée sur la grille de pixels** avec compensation sous-pixel pour un défilement fluide et sans scintillement.
- **Contours** avec une technique compatible avec le renderer Compatibility (vérifie le support de la texture de profondeur, sinon *inverted hull* par mesh) ; **palette limitée** (~32 couleurs) avec quantification et léger dithering en post-process.
- Textures pixel art minuscules, filtre *nearest*, pas de mipmaps. Densité : **16 px par mètre**.
- **Personnages, armes, objets et props en voxels** (1 voxel = 1/16 m), animés de façon procédurale par parties rigides (tête, torse, bras, jambes) : idle, marche, course, accroupi, frappe, tir, KO.
- **Palette du régime** : gris béton (5 nuances), bleu nuit, orange sodium des lampadaires, rouge propagande. **Couleurs vives** réservées à la vie du quartier et à la rébellion : tags, mosaïques, linge aux fenêtres, néon de l'épicerie de nuit.
- **Couleur = contrôle** : le post-process a un paramètre de saturation piloté par la zone, du gris (régime) à la pleine couleur (libérée), avec une transition animée au moment de la libération. Toujours doublé d'un indicateur d'interface (accessibilité).
- **Ambiance** : brume, pluie fréquente, cycle jour/nuit, écrans géants de propagande qui baignent les façades d'une lumière froide, bourdonnement des drones, annonces au haut-parleur, sirènes lointaines, passage du RER.
- UI en pixel art, police bitmap libre de droits, lisible à 640×360.

## 6. Le monde : la vraie Grigny (91350) et ses voisines

### 6.1 Pipeline carte (données réelles → niveaux jouables)

- `tools/osm_import/` télécharge les données **OpenStreetMap** via l'API Overpass (respecte sa politique d'usage : cache local, pas de requêtes en boucle). Récupère les limites communales (Grigny = code INSEE 91286) puis les bâtiments, routes, voies ferrées, eau (lacs, Seine), parcs, autoroute A6.
- Conversion : projection métrique locale, simplification ; extrusion des bâtiments selon `building:levels` / `height`, sinon hauteur par typologie (tours hautes de Grigny 2, bâtiments bas et courbes de la Grande Borne) ; textures de façades procédurales (grilles de fenêtres, balcons, paraboles, linge, tags).
- Génération d'**une scène Godot par zone** : meshes fusionnés par chunks (performances), collisions, navmesh.
- Chaque zone est à l'échelle **~1:1, recadrée et densifiée** sur l'essentiel (300 à 700 m de côté), avec un facteur d'échelle configurable. Transitions par points de passage (gare, souterrain, passerelle, scooter).
- Le résultat doit être **reconnaissable par un habitant** (silhouette des tours, courbes de la Grande Borne, lacs, A6, gare), puis retravaillé à la main pour le gameplay (planques, toits, raccourcis, couvertures).
- Option : hauteurs plus précises via la **BD TOPO de l'IGN** (licence ouverte Etalab 2.0, à créditer).

### 6.2 Repères réels à intégrer (vérifie et complète avec OSM)

- **Relief** : plateau au sud (≈ 80 m), coteau au centre (forte pente du bord de l'A6 jusqu'au lac), vallée de la Seine au nord-est (≈ 35 m).
- **Grigny 2 — zone de départ** : immense copropriété (~5 000 logements sur ~50 ha, l'une des plus grandes de France), entre l'A6 et la RD 310 ; avenue des Sablons, Square Surcouf, le centre commercial ; tout près, le grand ensemble des Tuileries et la **gare RER D de Grigny-Centre**.
- **La Grande Borne** (architecte Émile Aillaud, 1967–1971) : ~3 700 logements sur le plateau, de l'autre côté de l'A6, à cheval sur Viry-Châtillon. Bâtiments bas et sinueux, fresques en mosaïque, sculptures. Quartiers internes : Labyrinthe, Méridien, Ville-Haute, Ville-Basse, Peupleraie, Enclos, Radars, autour d'une grande **Plaine Centrale**. En face, de l'autre côté de l'A6 : la Ferme Neuve.
- **Le Village** (centre ancien, nord du coteau) : église, lavoir, ancienne mairie-école.
- **Les lacs** (lac de l'Arbalète, étangs de la Place Verte et de la Justice), le parc de l'Arbalète, le quartier pavillonnaire des Blancs Manteaux.
- **Le nord industriel** : zone des Noues de Seine, entre la Seine et la RN 7 ; les quais.
- **L'aqueduc de la Vanne et du Loing** : souterrain, parallèle à l'A6, il alimente Paris en eau → ressort majeur du scénario (§7).
- **Communes limitrophes** : Viry-Châtillon (ouest et nord), Fleury-Mérogis (sud), Ris-Orangis (est), Draveil (nord-est, de l'autre côté de la Seine).

### 6.3 Zones et progression

| Acte | Zone | Rôle dans le jeu |
|---|---|---|
| 1 | **Grigny 2** : la tour d'Akan, halls, caves, parkings, centre commercial, gare | Départ, tutoriel, première planque |
| 2 | **La Grande Borne** | Le Réseau (armes, marché noir) ; ruelles sinueuses idéales pour l'infiltration |
| 2 | **Le Village, les Lacs, les Blancs Manteaux** | Les anciens, les archives, des passages par l'eau |
| 3 | **Viry-Châtillon, Ris-Orangis** | La rébellion déborde de Grigny |
| 3 | **Fleury-Mérogis** | La grande prison devient le « Centre de Rééducation » : libérer les prisonniers politiques |
| 3 | **Draveil et la forêt de Sénart** | Camp rebelle en forêt |
| 3 | **Évry-Courcouronnes** | La préfecture devient le QG régional du régime (boss de l'acte) |
| 3→4 | **Juvisy-sur-Orge**, ou la **Seine** (qui coule de Grigny jusqu'à Paris) | Les deux routes vers la capitale |
| 4 | **Paris** (3–4 quartiers stylisés) | Entrée par le 13e (la Grande Borne a été construite pour reloger des habitants du 13e — clin d'œil historique), soulèvement final place de la Concorde |

## 7. Univers : le régime et Big Brother

Tout est **fictif** : aucun parti, dirigeant, symbole ou slogan réel.

- **Le régime — « la Concorde nationale »** (nom de travail) : arrivé au pouvoir après une série de crises, il gouverne par l'état d'urgence permanent, la surveillance et le rationnement.
- **« GRAND FRÈRE »** : le visage du régime sur tous les écrans, une IA de surveillance au visage synthétique (qui ne ressemble à personne de réel) et qui s'adresse aux citoyens par leur prénom. Slogan : *« Grand Frère veille sur toi. »* Ironie centrale : dans la cité, les vrais grands frères sont ceux qui protègent les petits. **Qui est le vrai grand frère ?**
- **Forces** : Vigiles (patrouilles, matraques), Garde (armée), Drones (repérage, appel de renforts), Unités d'intervention (fin de jeu), Indics (civils qui signalent).
- **Contrôle** : caméras à reconnaissance faciale, couvre-feu à 21 h, check-points, **tickets de rationnement** (eau et nourriture distribuées sous surveillance), **statut citoyen** (Conforme → Surveillé → Fiché → Ennemi public).
- **Novlangue** : les lieux sont rebaptisés (Grigny = « Zone de Résidence Encadrée n° 7 », la gare = « Point de Transit 7 », le centre culturel = « Centre d'Harmonie Citoyenne »…). **Libérer une zone lui rend son vrai nom.**
- **Propagande dynamique** : écrans, affiches et haut-parleurs réagissent aux actions du joueur (le régime déforme chaque événement, diffuse un avis de recherche pixelisé d'Akan, félicite les délateurs…).
- **L'eau** : le régime réserve l'eau de l'aqueduc à ses quartiers protégés de Paris et rationne la banlieue. Reprendre l'aqueduc (acte 3) rend l'eau aux quartiers et frappe le régime au cœur.

## 8. Personnages

**Règles d'écriture** : archétypes de quartier assumés, un peu clichés, mais **chaque personnage a une motivation, une voix reconnaissable et au moins un trait qui casse le cliché**. Distribution diverse, comme la vraie Grigny, **sans jamais lier un rôle (trafiquant, indic…) à une origine ou une religion**. Tous les personnages impliqués dans la violence, les armes ou les trafics sont **majeurs**. Aucune personne réelle.

- **Akan** (héros, ~21 ans) : vit avec sa mère et sa petite sœur au 11e étage d'une tour grise de Grigny 2 (étage à caler sur la hauteur réelle de la tour choisie) — l'ascenseur est en panne un jour sur deux. Débrouillard, vanneur, loyal, il n'a jamais voulu être un héros. Déclencheur : son meilleur ami est embarqué lors d'un contrôle et « disparaît ».
- **La daronne** : aide-soignante de nuit, épuisée, autoritaire et drôle ; fait passer des médicaments en douce.
- **Le Vieux Lucien** : ancien syndicaliste arrivé à la construction des tours ; cache une radio et les archives du « monde d'avant ».
- **Le Grand** : le vrai grand frère de la cité, ancien boxeur qui tient la salle ; respecté, il refuse la violence — à convaincre, pas à acheter.
- **Wifi** : hackeuse autodidacte, études stoppées par le régime ; détourne les écrans de propagande.
- **Zed** : patron du Réseau à la Grande Borne (armes, marché noir) ; pragmatique, pas idéologue — allié précieux, trahison possible.
- **Tonton** : l'épicier de nuit qui vend tout sous le comptoir et sait tout sur tout le monde.
- **MC Béton** : rappeur du quartier ; ses sons deviennent l'hymne de la rébellion grâce à la radio pirate.
- **Tata Rose** : tient le panier solidaire ; logistique de l'eau et de la nourriture.
- **Clé-de-12** : mécano du garage clandestin ; scooters et gadgets.
- **Bernard, le gardien** : concierge de la tour et indic du régime… parce qu'on menace sa fille. Rédemption possible.
- **Commandant Vasseur** : chef de la Garde pour l'Essonne, glacial et méthodique (boss d'Évry).

Dans le GDD, propose 10 personnages secondaires de plus (fiche : rôle, voix, lieu, quêtes).

## 9. Gameplay

**Boucle** : explorer → parler et récolter des infos → préparer (ressources, équipement, alliés) → agir (infiltration, propagande, sabotage, combat) → encaisser les conséquences (vigilance, soutien, représailles) → renforcer sa planque → zone suivante.

**Systèmes** (un module autonome par système, piloté par les données, testé) :

1. **Déplacement** : marche, course (endurance), accroupi, petites escalades, interactions contextuelles ; scooter à partir de l'acte 2.
2. **Besoins** : faim et soif (0–100) baissent avec le temps et l'effort ; à zéro, l'endurance puis la santé chutent. Une pression, pas une punition.
3. **Inventaire en grille** (capacité selon le sac), objets empilables, raccourcis rapides.
4. **Réseau d'informateurs** : chaque personnage retrouvé révèle des infos sur la carte (caméras, patrouilles, caches, failles du régime) et débloque des quêtes.
5. **Surveillance** : cônes de vision (caméras, drones, PNJ), bruit, **jauge de Vigilance 0–5** qui monte quand Akan est vu en train d'agir illégalement et redescend quand il se cache (halls, caves, toits, foule). Vigilance haute → plus de patrouilles et de drones, check-points, couvre-feu avancé, descentes.
6. **Statut citoyen** : conditionne l'accès aux rations et le comportement aux contrôles ; faux papiers ; masques (bloquent la reconnaissance faciale mais sont suspects en eux-mêmes).
7. **IA ennemie** : machine à états Patrouille → Suspicion → Alerte → Recherche → Retour ; communication entre unités, renforts.
8. **Combat temps réel** : mêlée (combo simple, neutralisation silencieuse par derrière), distance (visée souris / stick droit), couverture. Choix **neutraliser ou tuer** : tuer fait peur aux habitants et alimente la propagande.
9. **Territoire** : chaque zone a un *Contrôle du régime* et un *Soutien populaire* (0–100) que font bouger quêtes, tags, sabotages et services rendus. Seuils atteints → événement **« Zone libérée »** (couleurs, vrais noms, musique, nouvelle planque, nouveaux PNJ) ; le régime contre-attaque parfois (missions de défense).
10. **Propagande rebelle** : publier des appels à la rébellion — tags, tracts, radio pirate, réseau clandestin, détournement d'écrans (mini-jeu de piratage). Choix du ton (colère / espoir / humour) et du canal : + Soutien, mais + Vigilance.
11. **Progression d'Akan** : XP → points dans 5 arbres (Discrétion, Combat, Influence, Débrouille, Piratage) ; **réputation** auprès de 4 groupes : les Anciens, le Réseau, le Collectif (jeunes, artistes), les Familles.
12. **Alliés et planques** : recruter des alliés aux compétences uniques, les affecter à des tâches (corvée d'eau, guet, fabrication, radio), améliorer chaque planque (stockage, atelier, infirmerie, studio radio).
13. **Économie** : argent liquide, tickets de rationnement (monnaie du régime), troc, marché noir.
14. **Temps** : cycle jour/nuit (1 journée ≈ 24 min réelles), couvre-feu, quêtes de nuit.
15. **Sauvegarde** : automatique aux planques + manuelle, JSON versionné (`save_version`) avec migrations.

## 10. Quêtes

- **Data-driven** : `data/quests/*.json` validés par un schéma JSON. Champs : id, titre, résumé, donneur, prérequis (quêtes, réputation, statut, objets, heure), étapes avec types d'objectif (`TALK`, `GOTO`, `COLLECT`, `DELIVER`, `PUBLISH`, `SABOTAGE`, `HACK`, `ESCORT`, `STEALTH`, `DEFEND`, `NEUTRALIZE`), embranchements, récompenses (XP, objets, réputation, effets sur la zone), dialogues liés.
- Quêtes principales, secondaires, et petites tâches répétables (distribuer des tracts, ravitailler en eau, couvrir une caméra…).
- **Acte 1, à implémenter en premier :**
  1. **Ascenseur en panne** — réveil au 11e, tutoriel (se déplacer, interagir, manger, boire) ; la daronne envoie Akan chercher de l'eau.
  2. **La file** — point de ration sous les caméras : contrôle d'identité, un voisin est embarqué sous ses yeux.
  3. **Le Vieux du 7e** — retrouver Lucien, qui sait des choses sur les disparus.
  4. **Les yeux du quartier** — gagner la confiance des guetteurs, qui révèlent les angles morts des caméras (carte de surveillance).
  5. **Premier tag** — publier le premier appel à la rébellion sur le mur de la tour ; le régime riposte sur ses écrans.
  6. **Le Grand** — convaincre le vrai grand frère de la cité (épreuve de confiance, sans combat).
  7. **Le contact** — rejoindre le Réseau à la Grande Borne pour obtenir une première arme ; le prix à payer est un choix moral.
  8. **La tour se lève** — aveugler la caméra du hall, démasquer l'indic, rallier les habitants → **première zone libérée**.
- Ensuite, écris dans le GDD la trame des actes 2 à 4 (quêtes principales + 3 secondaires par zone, fins multiples) et **attends ma validation avant de l'implémenter**.

## 11. Dialogues et ton

- **Français**, toutes les chaînes passent par le système de traduction de Godot (clés), pour ajouter l'anglais plus tard.
- **Le quartier** : français oral, vivant, drôle ; argot et verlan dosés (*wesh, frérot, la daronne, téma, ouf, chelou, relou, vénère, en scred, poucave, c'est carré, t'inquiète*). Chaque PNJ a ses tics de langage. L'humour est vital dans un monde aussi oppressant.
- **Le régime** : novlangue froide, polie, administrative (*« Citoyen, votre conformité est notre sécurité. »* — *« Signaler, c'est protéger. »* — *« La tranquillité est un droit, la vigilance un devoir. »*).
- Répliques courtes (2 lignes max dans la bulle à 640×360), réponses avec le ton affiché (Calme / Cash / Malin), conséquences visibles.
- **Décor et ambiance** : tours grises, paraboles, linge aux fenêtres, halls tagués, boîtes aux lettres défoncées, ascenseur en panne, scooters, city-stade, kebab, épicerie de nuit, mamans aux fenêtres, son qui sort d'une voiture — des clichés traités avec tendresse.
- Avant d'écrire en masse : `docs/TON.md` avec 20 répliques d'exemple par registre, pour validation.

## 12. Assets : pipeline pixel 2D + voxel 3D

Tu ne dessines pas à la main : tu génères les assets **par code, depuis des sources texte versionnées**, remplaçables plus tard par de l'art fait main.

- `assets_src/voxel/*.txt` : modèles voxel en couches ASCII + légende de palette → `tools/build_voxels.py` → meshes `.glb` (couleurs par sommet) **+ icône d'inventaire 32×32 générée automatiquement** à partir du même modèle.
- `assets_src/pixel/*.txt` : sprites et textures en grilles ASCII + palette → `tools/build_pixels.py` → PNG (façades, tags, affiches, UI).
- Une palette unique, `assets_src/palette.json`, partagée par tout.
- `assets/ASSETS.md` : chaque asset avec sa source, sa licence et son statut (placeholder / final). Assets externes uniquement en CC0 (ex. Kenney) ou sous licence compatible, toujours listés.
- **Liste V1 :**
  - *Mêlée* : batte, barre de fer, clé à molette, matraque (récupérée sur les Vigiles).
  - *Distance* : lance-pierre, pistolet, fusil à pompe, fusil d'assaut, fusil à impulsion du régime (fin de jeu).
  - *Gadgets* : fumigène, mortier d'artifice (diversion), bombe de peinture (tag + aveugler les caméras), brouilleur, drone piraté, crochet, talkie-walkie, mégaphone, faux papiers, masque.
  - *Équipement* : sweat à capuche, doudoune, casquette, baskets, sac à dos (3 tailles), gilet pare-balles.
  - *Ressources* : bouteille d'eau, bidon, jerrican, baguette, conserve, chips, kebab, ration grise du régime, fruits, trousse de soins, antidouleurs, munitions, billets, tickets de rationnement, ferraille, composants électroniques, batteries, essence.
  - *Props* : caméra, drone, écran de propagande, affiche, haut-parleur, barrière de check-point, boîtes aux lettres, parabole, poubelle, scooter, voiture, abribus.
  - *Personnages* : Akan, les PNJ principaux, 6 variantes de civils, Vigile, Garde, Unité d'intervention.
- **Audio** : placeholders générés (sons rétro type sfxr) ou CC0 listés ; annonces de propagande en texte avec effet radio.

## 13. Architecture

```
res://
  addons/          dialogue_manager, gut
  assets/          généré + importé
  assets_src/      sources texte des assets
  data/            items/ quests/ characters/ zones/ factions/ (JSON) + schemas/
  dialogue/        *.dialogue
  scenes/          main/ zones/ actors/ ui/ props/
  scripts/
    autoload/      event_bus, game_state, save_manager, audio_manager
    systems/       needs, inventory, informants, surveillance, territory, quests, propaganda, progression, time
    actors/        player, npc, enemy_ai
    ui/
  tests/           GUT : au moins un fichier de test par système
  tools/           osm_import/ build_voxels.py build_pixels.py validate_data.py
  docs/            GDD.md ROADMAP.md DECISIONS.md TON.md LEGAL.md
.github/workflows/
```

- Systèmes découplés via un **EventBus** (signaux) ; le moins d'autoloads possible.
- Toute valeur d'équilibrage (stats, prix, seuils, durées) dans `data/` ou en constantes nommées : jamais de nombres magiques.
- Logique pure séparée des nœuds quand c'est possible, pour la tester facilement.
- Scènes `.tscn` simples écrites à la main ; tout ce qui est complexe ou généré est construit par code ou par les outils.

## 14. GitHub : tests, builds et phase de test

- **CI à chaque push et PR** (`.github/workflows/ci.yml`) : installe la version épinglée de Godot (ex. action `solarlabyrinth/action-setup-godot` ou `chickensoft-games/setup-godot`), `--import`, tests GUT, gdlint, `validate_data.py`. Merge sur `main` bloqué si ça échoue.
- **Builds sur tag `v*`** (`release.yml`) : exports Windows, Linux, macOS et Web → artefacts + **GitHub Release** avec notes générées depuis les commits.
- **Version web de playtest** : export web **mono-thread** (aucun en-tête HTTP spécial requis), déployé sur **GitHub Pages** (dépôt public, ou privé avec GitHub Pro / Student Pack) et/ou sur une page itch.io **restreinte** (mot de passe) via `butler`.
- **Secrets** : jamais de clé en clair dans le dépôt ; tout passe par les secrets GitHub (`BUTLER_API_KEY`, plus tard Steam).
- **Vérification visuelle en local** : ajoute un mode `--screenshot <scène>` qui charge la scène, attend quelques frames, enregistre une capture dans `build/screenshots/` puis quitte. Après chaque changement visuel, lance-le et regarde les captures.
- Templates d'issues (bug, retour de playtest), `CHANGELOG.md`, versionnage sémantique (`0.x` pendant toute la phase de test).
- Écran de démarrage et crédits avec toutes les attributions (OpenStreetMap, IGN si utilisée, assets CC0, addons).

## 15. Publication (après la phase de test)

1. **itch.io** : page publique (démo / accès anticipé), builds poussés par la CI avec butler.
2. **Steam** : compte Steamworks, frais Steam Direct de 100 $ par jeu (récupérés après 1 000 $ de revenus), page « Bientôt disponible » le plus tôt possible pour accumuler des listes de souhaits, Steam Playtest pour les bêtas fermées, **GodotSteam** (succès, Steam Deck), upload des builds via SteamCMD depuis la CI.
3. **Classification** : questionnaire de contenu Steam (violence, armes) ; IARC pour les autres boutiques.
4. Consoles et mobile : hors périmètre pour l'instant.
5. Aucune collecte de données personnelles dans le jeu.

## 16. Garde-fous (non négociables)

- **Fiction assumée** : régime, parti, dirigeants et symboles 100 % inventés ; aucune personne réelle (élus, célébrités, habitants, artistes) ; aucune marque ni logo réel (remplacés par des équivalents fictifs).
- **OpenStreetMap (ODbL)** : attribution « © les contributeurs d'OpenStreetMap — données sous licence ODbL » sur l'écran de démarrage et dans les crédits ; les données géographiques dérivées (`tools/osm_import/data/`) restent sous ODbL, avec leur fichier de licence.
- **Œuvres protégées** : la Grande Borne (architecture, fresques, sculptures) est une œuvre protégée, et l'exception de panorama française exclut tout usage commercial → **s'inspirer et styliser, ne jamais copier à l'identique** fresques et sculptures. Note dans `docs/LEGAL.md` les points à faire valider par un juriste avant la sortie commerciale.
- **Respect** : lieux de culte, écoles et lieux de soins sont des zones neutres — jamais de combat ni de cible. Pas de caricature fondée sur l'origine ou la religion. Aucun mineur impliqué dans la violence, les armes ou les trafics.
- Armes et gadgets sont des objets de jeu avec des statistiques : **aucune instruction réelle de fabrication** dans le contenu.

## 17. Jalons et définition de « terminé »

| Jalon | Contenu | Terminé quand… |
|---|---|---|
| **M0 — Fondations** | Projet Godot, rendu pixel 2.5D (basse résolution, caméra alignée, contours, palette), contrôleur joueur clavier + manette, EventBus, sauvegarde, mode capture d'écran, CI verte, docs de base | On se déplace dans une scène test au rendu pixel net, sans scintillement ; CI verte ; build web jouable en ligne |
| **M1 — Tranche verticale** | Import OSM de Grigny 2, tour d'Akan (hall, cage d'escalier, appartement), besoins, inventaire, dialogues, quêtes 1 à 8, caméras + Vigilance, IA des Vigiles, combat de base, première zone libérée (couleurs + vrais noms) | L'acte 1 (~45 min) se joue de bout en bout sans bug bloquant ; tests verts ; release `v0.1.0` (Windows + Web) |
| **M2 — Toute Grigny** | Grande Borne, Village, Lacs ; Réseau, propagande, piratage, informateurs, alliés, planques, scooter, cycle jour/nuit complet | Grigny entière libérable ; `v0.2.x` testée par des joueurs |
| **M3 — L'Essonne** | Viry, Ris, Fleury, Draveil/Sénart, Évry, Juvisy ; contre-attaques du régime ; boss | Acte 3 jouable et équilibré |
| **M4 — Paris** | Quartiers parisiens stylisés, soulèvement final, fins multiples | Le jeu se termine de bout en bout |
| **M5 — Sortie** | Polish, accessibilité (taille du texte, daltonisme, difficulté, remappage), traduction anglaise, pages itch/Steam, trailer, dossier de presse | Release `v1.0.0` |

## 18. Ta première tâche (maintenant)

1. Lis ce brief en entier. Pose-moi **au maximum 5 questions** vraiment bloquantes ; pour le reste, choisis l'option par défaut et documente-la.
2. Vérifie l'environnement (Godot, Python, git, gh) et l'état du dépôt.
3. Présente le **plan détaillé de M0** (fichiers, étapes, commandes de vérification) et attends mon feu vert.
4. Après validation : réalise M0, rédige `docs/GDD.md` (avec 5 propositions de titre pour le jeu) et `docs/TON.md`, ouvre la PR, puis fais-moi un récap en 10 lignes max : ce qui marche, comment lancer le jeu, ce qui reste à faire.
