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
- [x] CI verte sur la PR ([#1](https://github.com/Yato-350/91350/pull/1), fusionnée)
- [ ] Build web jouable en ligne (après fusion sur `main` et activation de GitHub Pages)

## M1 — Tranche verticale (acte 1, ~45 min)

- [x] Pipeline voxel : `build_voxels.py` (modèles, blocs, échelle, icônes) et personnages
      générés depuis leur fiche (visages, coiffures, pilosité, bas, accessoires)
- [x] Affiches, tags et écrans : panneaux voxel (`panel:`), plutôt qu'un `build_pixels.py`
- [x] Import OpenStreetMap de Grigny 2 → zone jouable (bâtiments, routes, collisions)
- [x] Réalisme de Grigny 2 : trottoirs et marquages, parkings et voitures, 264 arbres réels
      et parcs plantés, lampadaires, clôtures et haies, entrées réelles des immeubles,
      mobilier, pylônes ; façades détaillées (loggias, linge, paraboles, tags)
- [x] La tour d'Akan : appartement, paliers du 11e et du 7e, hall, local à vélos, toit
      (intérieurs en plans de texte) ; salle de boxe de la maison de quartier
- [x] Besoins (faim, soif), endurance, accroupi, charge lourde, interactions
- [x] Inventaire en grille, objets, raccourcis, écran du sac
- [x] Dialogues (Dialogue Manager 4.2) et PNJ (regard, gestes)
- [x] Vérifications de niveau : lieux atteignables, aucun piège, repères accessibles
- [x] Quêtes pilotées par les données ; quêtes 1 à 8 de l'acte 1, jouées de bout en bout
      par un robot de parcours (et les trois issues du « contact »)
- [x] Surveillance : caméras, cônes de vision, Vigilance 0–5, statut citoyen ; contrebande
      et « grillé » pour l'infiltration
- [x] IA des Vigiles (patrouille → suspicion → alerte → recherche → retour)
- [x] Combat de base (mêlée, neutralisation par derrière, défense du hall par vagues) ;
      l'arme à distance (lance-pierre) est obtenue, son usage arrive en M2
- [x] Territoire : première zone libérée (couleurs, vrais noms, musique, planque) ; le
      régime quitte la zone
- [x] Cycle jour/nuit et couvre-feu ; le lit d'Akan ; horaires du point de ration
- [x] Audio généré (23 bruitages, 3 musiques, ambiance) et AudioManager
- [x] Menus : écran titre, pause, confirmation, fin de l'acte 1 ; sauvegarde à la planque
- [x] `release.yml` (Windows, Linux, macOS, Web) et release `v0.1.0`

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
