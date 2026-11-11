# Feuille de route

Les jalons viennent du brief (§17). Une case est cochée quand le critère est vérifié
(test, capture ou essai).

## M0 — Fondations

- [x] Projet Godot 4.7.2, renderer Compatibility, GDScript typé obligatoire
- [x] Rendu pixel 2.5D : basse résolution à l'échelle entière, caméra calée sur la grille
      de pixels, contours, palette (`tools/check.sh render`)
- [x] Contrôleur du joueur clavier + manette, actions réassignables par construction
- [x] EventBus
- [x] Sauvegarde JSON versionnée avec migrations
- [x] Mode capture d'écran (`tools/check.sh screenshot <scène>`)
- [x] Zone de test jouable
- [x] Interface minimale, traductions par clés, crédits
- [x] Export web mono-thread, essayé dans Chromium (`node tools/web_smoke.cjs`)
- [x] Docs de base : README, CLAUDE.md, GDD, TON, ROADMAP, DECISIONS, LEGAL
- [ ] CI verte sur la PR
- [ ] Build web jouable en ligne (après fusion sur `main` et activation de GitHub Pages)

## M1 — Tranche verticale (acte 1, ~45 min)

- [ ] Pipeline d'assets : `build_voxels.py` (modèles + icônes), `build_pixels.py`
- [ ] Import OpenStreetMap de Grigny 2 → zone jouable (bâtiments, routes, collisions)
- [ ] La tour d'Akan : hall, cage d'escalier, appartement
- [ ] Besoins (faim, soif), endurance, accroupi, interactions
- [ ] Inventaire en grille, objets, raccourcis
- [ ] Dialogues (Dialogue Manager 4.2) et PNJ
- [ ] Quêtes pilotées par les données ; quêtes 1 à 8 de l'acte 1
- [ ] Surveillance : caméras, cônes de vision, Vigilance 0–5, statut citoyen
- [ ] IA des Vigiles (patrouille → suspicion → alerte → recherche → retour)
- [ ] Combat de base (mêlée, neutralisation, distance)
- [ ] Territoire : première zone libérée (couleurs + vrais noms)
- [ ] Cycle jour/nuit et couvre-feu
- [ ] Audio généré (sons, ambiance)
- [ ] `release.yml` et release `v0.1.0` (Windows + Web)

## M2 — Toute Grigny

- [ ] Grande Borne, Village, Lacs (import OSM + habillage)
- [ ] Le Réseau, marché noir, économie (argent, tickets, troc)
- [ ] Propagande rebelle : tags, tracts, radio pirate, détournement d'écrans (piratage)
- [ ] Réseau d'informateurs et carte de surveillance
- [ ] Alliés et planques (affectations, améliorations)
- [ ] Progression : XP, 5 arbres, réputation auprès de 4 groupes
- [ ] Scooter
- [ ] Quêtes de l'acte 2 ; Grigny entière libérable ; `v0.2.x`

## M3 — L'Essonne

- [ ] Viry-Châtillon, Ris-Orangis, Fleury-Mérogis, Draveil/Sénart, Évry-Courcouronnes, Juvisy
- [ ] Contre-attaques du régime (missions de défense), Garde, drones, unités d'intervention
- [ ] L'aqueduc : rendre l'eau aux quartiers
- [ ] Boss : le commandant Vasseur
- [ ] Quêtes de l'acte 3 ; équilibrage

## M4 — Paris

- [ ] Quartiers parisiens stylisés (13e, Seine, Concorde)
- [ ] Les deux routes vers la capitale (rail ou Seine)
- [ ] Soulèvement final, GRAND FRÈRE, fins multiples

## M5 — Sortie

- [ ] Polish, équilibrage, performances (60 IPS sur un portable d'entrée de gamme)
- [ ] Accessibilité : taille du texte, daltonisme, difficulté, remappage
- [ ] Traduction anglaise
- [ ] Pages itch.io et Steam, bande-annonce, dossier de presse
- [ ] Release `v1.0.0`
