# M2 — Toute Grigny : plan

**Objectif (brief §17) :** Grande Borne, Village, Lacs ; Réseau, propagande, piratage,
informateurs, alliés, planques, scooter, cycle jour/nuit complet. **Grigny entière
libérable** ; release `v0.2.x`.

**Spec :** `docs/BRIEF.md` (§6.2, §6.3, §9, §10) et `docs/GDD.md` (§5 systèmes 4, 10 à 13 ;
§8 acte 2). Consigne de l'auteur : autorisation complète, on enchaîne sans attendre.

## Principes

- **Tranches jouables** : chaque phase finit par une quête jouée de bout en bout par le
  robot de parcours, et une PR verte. Pas de système sans la quête qui s'en sert.
- On **réutilise** ce que M1 a posé : import OSM (`tools/osm_import/`, une entrée par zone
  dans `zones.json`), habillage cuit, `Zone` et ses conditions de présence, moteur de
  quêtes, `Neighbourhood`/`Story` pour les dialogues, `Territory` pour la libération.
- **La Grande Borne** : on s'inspire des formes (bâtiments bas et sinueux, places, la
  Plaine Centrale) ; jamais de copie des fresques ni des sculptures (garde-fou §16).

## Phases

### A. La Grande Borne et le Réseau
1. Import OSM de la Grande Borne (`grande_borne`), cuisson, habillage ; la passerelle
   de l'A6 relie Grigny 2 et la Grande Borne (portes dans les deux sens).
2. Le Réseau : QG de Zed (intérieur), coursiers, guetteurs ; **drones** (caméra volante
   qui patrouille un circuit, même cône de vision).
3. **Économie** : billets (argent liquide), tickets de rationnement, troc ; écran
   d'échange avec un vendeur (acheter, vendre, troquer), prix selon la réputation.
4. Quête 2-1 **Le Labyrinthe** (trouver Zed sous les drones, négocier l'alliance) ;
   secondaire **Marché noir** (tournées pour Zed).

### B. Progression
1. **Cinq arbres** (Discrétion, Combat, Influence, Débrouille, Piratage), trois ou quatre
   compétences chacun, branchés sur des effets concrets (bruit des pas, dégâts, prix,
   temps de piratage, options de dialogue) ; écran des compétences.
2. Réputation auprès des 4 groupes visible et utilisée (prix, portes de dialogue).

### C. Propagande
1. **Tracts** (distribuer à des points de passage), **radio pirate** (émetteur, antenne,
   émission avec choix du ton), **écrans détournés** : mini-jeu de **piratage** (`HACK`).
2. Quêtes 2-2 **Radio Béton** et 2-5 **Écrans noirs** ; secondaire **La fresque**.

### D. Le Village et les Lacs
1. Import OSM du Village (église et école : décor neutre) et des Lacs (lac de
   l'Arbalète, étangs, Blancs Manteaux).
2. **L'aqueduc** : regards reliés sous terre (voyage discret entre zones).
3. Quêtes 2-3 **Les archives** et 2-4 **Par l'eau** (la première eau rendue allège les
   besoins) ; secondaires **Le lavoir**, **La barque**.

### E. Alliés, informateurs, scooter
1. **Alliés** recrutés, **affectés** à une tâche (corvée d'eau, guet, fabrication,
   radio) ; **planques** améliorées (stockage, atelier, infirmerie, studio radio).
2. **Informateurs** : chaque personnage retrouvé révèle des éléments sur la carte de
   surveillance (caméras, patrouilles, caches, failles).
3. **Scooter** (12 m/s, bruyant) ; secondaire **Courrier express** (Mamie Scooter).

### F. Grigny se lève
1. Quête 2-6 **Grigny se lève** : trois objectifs simultanés (gare, Plaine Centrale,
   passerelle de l'A6), puis la défense contre la contre-attaque ; Grigny retrouve son
   nom (toutes les zones libérées).
2. Secondaires restantes (*Pétanque diplomatique*, *Coupe d'été*, *Le menu du jour*,
   *Court-circuit*).
3. Robot de parcours de l'acte 2, release `v0.2.0`.

## Risques

- **Taille** : M2 est plus gros que M1. Parade : une PR par phase, chacune jouable.
- **Overpass** : une requête par zone, mise en cache (politique d'usage) ; si l'API est
  injoignable, on garde le cache et on le signale.
- **Performances** : quatre zones extérieures ; on ne charge qu'une zone à la fois (comme
  en M1), maillages fusionnés par morceaux.

## Terminé quand

- Les six quêtes principales de l'acte 2 et les secondaires se jouent de bout en bout
  (robot de parcours) ; Grigny entière est libérable.
- Tests verts, captures relues, release `v0.2.0` publiée.
