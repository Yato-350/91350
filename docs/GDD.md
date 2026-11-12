# Game Design Document — « 91350 »

Version 0.1 — brouillon de travail. Tout le contenu narratif est une proposition : il se
réécrit dans les fichiers de données (`data/`, `dialogue/`). Œuvre de fiction : le régime,
ses dirigeants et ses symboles sont inventés, aucun personnage n'est une personne réelle.

## 1. Le jeu en une phrase

Un **action-RPG d'infiltration en pixel art 2.5D** : dans une France fictive tombée sous un
régime totalitaire de surveillance, **Akan**, un jeune adulte de **Grigny (Essonne, 91350)**,
part de sa tour pour soulever son quartier, puis toute la ville, puis l'Essonne — jusqu'à
la libération de Paris.

### Piliers

1. **Le quartier est le héros collectif.** Solidarité, débrouille, humour, culture. La
   violence existe, mais elle ne définit pas les habitants.
2. **Big Brother est un système de jeu, pas un décor.** Caméras, drones, écrans,
   haut-parleurs, couvre-feu, contrôles, indics.
3. **Du hall à Paris.** Un homme seul → une tour → un quartier → une ville → un
   département → la capitale.
4. **Chaque choix a un prix.** Eau, nourriture et munitions sont rares ; la violence fait
   peur aux habitants et nourrit la propagande.
5. **La couleur, c'est la liberté.** Une zone tenue par le régime est grise ; libérée,
   elle retrouve ses couleurs, sa musique et ses vrais noms.

## 2. Titre

« 91350 » est le titre de travail. Cinq propositions :

| Titre | Argument |
|---|---|
| **91350** | Un code postal comme un blason : court, intrigant, et c'est le nom que le régime n'a pas pu effacer. |
| **Grand Frère** | L'ironie centrale du jeu : l'IA qui « veille » contre les vrais grands frères de la cité. |
| **Nos vrais noms** | Libérer une zone lui rend son nom. Le titre dit la victoire avant le combat. |
| **La Couleur des tours** | Le pilier visuel : du gris du régime à la couleur du quartier. |
| **Zone 7** | Le nom que le régime donne à Grigny. Un titre sec, à arracher zone par zone. |

## 3. Boucle de jeu

Explorer → parler et récolter des infos → préparer (ressources, équipement, alliés) → agir
(infiltration, propagande, sabotage, combat) → encaisser les conséquences (vigilance,
soutien, représailles) → renforcer sa planque → zone suivante.

Une session type dure 15 à 30 minutes : une quête principale ou deux quêtes secondaires,
un retour à la planque, une sauvegarde automatique.

## 4. Structure

| Acte | Titre | Zones | Durée visée |
|---|---|---|---|
| 1 | La tour | Grigny 2 | 45 min |
| 2 | La ville | La Grande Borne ; le Village et les Lacs | 45 min |
| 3 | Le département | Viry-Châtillon, Ris-Orangis, Fleury-Mérogis, Draveil et la forêt de Sénart, Évry-Courcouronnes | 60 min |
| 3→4 | Deux routes | Juvisy-sur-Orge (le rail) **ou** la Seine (les péniches) | 15 min |
| 4 | Paris | Le 13e, les quais, la Concorde | 30 min |

### Zones et novlangue

Chaque zone a un nom du régime et un vrai nom. **La libérer lui rend son vrai nom**, sur la
carte, les panneaux et l'interface.

| Vrai nom | Nom du régime | Rôle |
|---|---|---|
| Grigny | Zone de Résidence Encadrée n° 7 (« ZRE 7 ») | La ville |
| Grigny 2 | Secteur 7-A | Départ, tutoriel, première planque |
| La gare de Grigny-Centre | Point de Transit 7 | Check-point, passage vers les autres zones |
| Le centre commercial | Comptoir de Distribution 7 | Point de ration, file sous caméras |
| La Grande Borne | Secteur 7-B | Le Réseau, ruelles sinueuses, infiltration |
| La Plaine Centrale | Esplanade de la Concorde | Écran géant, rassemblements |
| Le centre culturel | Centre d'Harmonie Citoyenne | Propagande, puis radio pirate |
| Le Village, les Lacs | Secteur 7-C, Réserve Hydrique 7 | Les anciens, les archives, les passages par l'eau |
| Viry-Châtillon | ZRE 6 | La station de l'aqueduc |
| Ris-Orangis | ZRE 8 | Les quais, le ravitaillement |
| Fleury-Mérogis | Centre de Rééducation Sud | Libérer les prisonniers politiques |
| Draveil, la forêt de Sénart | Périmètre forestier interdit | Le camp rebelle |
| Évry-Courcouronnes | Préfecture de la Concorde — District Sud | QG régional, boss de l'acte 3 |
| Juvisy-sur-Orge | Nœud de Transit Sud | La route du rail |
| Paris | La Capitale protégée | Acte 4 |

Les zones sont générées depuis OpenStreetMap (≈ 1:1, recadrées sur 300 à 700 m de côté,
densifiées), puis habillées par des données : PNJ, caméras, patrouilles, caches, entrées
d'intérieurs. Les intérieurs (appartement, hall, planques, épicerie…) sont des plans en
texte convertis en petites scènes.

## 5. Systèmes

Un module autonome par système, piloté par les données, testé, relié aux autres par
l'`EventBus`.

| # | Système | Règles clés | Jalon |
|---|---|---|---|
| 1 | **Déplacement** | Marche 2,5 m/s, course 5,5 m/s (endurance 100 ; −10/s en course, +15/s après 1 s de repos), accroupi (silencieux, 1,5 m/s), petites escalades (≤ 1 m), interactions contextuelles. Scooter à l'acte 2 (12 m/s, bruyant). | M0 → M2 |
| 2 | **Besoins** | Faim et soif de 0 à 100. La soif perd 4/min (×2 en course), la faim 2,5/min. À zéro : l'endurance ne remonte plus qu'à moitié ; après 60 s, la santé perd 1 toutes les 5 s. Une pression, pas une punition : manger et boire sont fréquents et peu chers une fois l'eau rendue au quartier. | M1 |
| 3 | **Inventaire** | Grille (4×3 sans sac, 5×4, 6×5, 7×6 selon le sac), objets empilables, 4 raccourcis rapides. | M1 |
| 4 | **Informateurs** | Chaque personnage retrouvé révèle des éléments sur la carte (caméras, patrouilles, caches, failles) et débloque des quêtes. | M2 |
| 5 | **Surveillance** | Cônes de vision (caméras, drones, PNJ), bruit, **Vigilance 0–5** par zone. +1 quand Akan est vu en train d'agir illégalement ; −1 toutes les 45 s passées caché. 1 : Vigiles en alerte · 2 : patrouille en plus · 3 : drone · 4 : check-points et renforts · 5 : descente. | M1 |
| 6 | **Statut citoyen** | Conforme → Surveillé → Fiché → Ennemi public. Conditionne les rations et les contrôles. Faux papiers : redescendent d'un cran. Masque : bloque la reconnaissance faciale mais rend suspect. | M1 |
| 7 | **IA ennemie** | Patrouille → Suspicion → Alerte → Recherche → Retour. Les unités se préviennent et appellent des renforts. | M1 |
| 8 | **Combat** | Mêlée (combo de 3 coups, neutralisation silencieuse par derrière), distance (visée souris ou stick droit), couverture. **Neutraliser ou tuer** : tuer fait peur aux habitants (−Soutien) et nourrit la propagande. | M1 |
| 9 | **Territoire** | Par zone : *Contrôle du régime* et *Soutien populaire* (0–100). Zone libérable quand Contrôle ≤ 25 et Soutien ≥ 75, par une quête finale. Événement « Zone libérée » : couleurs, vrais noms, musique, planque, nouveaux PNJ. Le régime contre-attaque parfois. | M1 |
| 10 | **Propagande rebelle** | Tags, tracts, radio pirate, détournement d'écrans (mini-jeu de piratage). Choix du ton — colère, espoir, humour — et du canal : + Soutien, mais + Vigilance. | M2 |
| 11 | **Progression** | XP → niveaux → points dans 5 arbres : Discrétion, Combat, Influence, Débrouille, Piratage. Réputation (−100 à 100) auprès de 4 groupes : les Anciens, le Réseau, le Collectif, les Familles. | M2 |
| 12 | **Alliés et planques** | Recruter, affecter à une tâche (corvée d'eau, guet, fabrication, radio), améliorer la planque (stockage, atelier, infirmerie, studio radio). | M2 |
| 13 | **Économie** | Argent liquide, tickets de rationnement (monnaie du régime), troc, marché noir. | M2 |
| 14 | **Temps** | 1 journée = 24 min réelles. Couvre-feu à 21 h (avancé si la Vigilance est haute). Quêtes de nuit. | M1 |
| 15 | **Sauvegarde** | Automatique aux planques + manuelle. JSON versionné avec migrations. | M0 |

### Arbres de compétences (4 paliers chacun)

| Arbre | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| Discrétion | Pas feutrés | Angles morts visibles | Neutralisation rapide | Fantôme (la Vigilance retombe 2× plus vite) |
| Combat | Encaisse (+25 santé) | Combo long | Désarmement | Dernier round (un KO évité par combat) |
| Influence | Bagou (meilleurs prix) | Foule (les civils te cachent) | Tribun (+ Soutien par message) | Vrai grand frère (des habitants te suivent) |
| Débrouille | Sac bien rangé (+1 ligne) | Gourde (soif −25 %) | Bricoleur (gadgets moins chers) | Système D (1 gadget offert par jour) |
| Piratage | Boucle vidéo (caméra 10 s) | Brouillage | Écrans à nous | Porte dérobée (les drones t'ignorent 20 s) |

## 6. Le régime

- **« La Concorde nationale »** (nom de travail) : arrivée au pouvoir après une série de
  crises, elle gouverne par l'état d'urgence permanent, la surveillance et le rationnement.
  Son Directoire n'a pas de visage : personne ne signe, personne ne répond.
- **GRAND FRÈRE** : une IA de surveillance au visage synthétique, qui ne ressemble à
  personne et s'adresse à chacun par son prénom. Slogan : « Grand Frère veille sur toi. »
- **Forces** : Vigiles (patrouilles, matraques) · Garde (armée) · Drones (repérage, appel
  de renforts) · Unités d'intervention (fin de jeu) · Indics (civils qui signalent).
- **Contrôle** : caméras à reconnaissance faciale, couvre-feu, check-points, tickets de
  rationnement, statut citoyen.
- **Propagande dynamique** : écrans, affiches et haut-parleurs réagissent aux actions du
  joueur — le régime déforme chaque événement, diffuse un avis de recherche pixelisé
  d'Akan, félicite les délateurs.
- **L'eau** : le régime réserve l'eau de l'aqueduc à ses quartiers protégés de Paris et
  rationne la banlieue. Reprendre l'aqueduc (acte 3) rend l'eau aux quartiers.

### Le secret de GRAND FRÈRE

Grigny était une **zone pilote**. Pour apprendre à « veiller », l'IA a observé pendant des
années ceux en qui les habitants avaient confiance : les grands frères, les mères aux
fenêtres, les gardiens, les entraîneurs. Elle a copié leurs gestes de protection et en a
fait du contrôle. Les archives du Village (acte 2) le prouvent ; la « Salle des Prénoms »
(acte 4) le montre. La question du jeu — **qui est le vrai grand frère ?** — se règle face
à elle, pas à coups de poing.

## 7. Personnages

Règle : chaque personnage a une motivation, une voix reconnaissable et un trait qui casse
le cliché. Aucun rôle n'est lié à une origine ou une religion. Tous ceux qui touchent à la
violence, aux armes ou aux trafics sont majeurs.

### Principaux

| Personnage | Rôle | Voix | Ce qui casse le cliché |
|---|---|---|---|
| **Akan** (21 ans) | Le héros. Vit au 11e étage avec sa mère et sa petite sœur. | Vanneur, loyal, parle vite quand il a peur. | N'a jamais voulu être un héros : il veut juste retrouver Nino. |
| **Adjoua, « la daronne »** | Sa mère, aide-soignante de nuit. Fait passer des médicaments. | Autoritaire et drôle, phrases courtes, « Je répète pas. » | C'est elle la première résistante de la famille. |
| **Maya** (12 ans) | La petite sœur. Hors de toute violence. | Questions sans fin. | Dessine la carte du quartier mieux que personne. |
| **Nino** | Le meilleur ami, embarqué lors d'un contrôle. | (Absent : on l'entend dans les souvenirs.) | Il n'avait rien fait. C'est tout le problème. |
| **Le Vieux Lucien** | Ancien syndicaliste, cache une radio et les archives du « monde d'avant ». | Lent, précis, proverbes inventés. | Doute de tout, y compris de la rébellion. |
| **Le Grand** | Le vrai grand frère de la cité, ancien boxeur, tient la salle. | Peu de mots, pose des questions. | Refuse la violence. À convaincre, pas à acheter. |
| **Wifi** | Hackeuse autodidacte, études stoppées par le régime. | Sarcasme, jargon traduit en images. | A peur du vide : ne monte jamais sur un toit. |
| **Zed** | Patron du Réseau à la Grande Borne. | Calme, tout est un contrat. | Tient parole au centime près — jusqu'au jour où. |
| **Tonton** | L'épicier de nuit, vend tout sous le comptoir. | Bavard, répond par une question. | Ne ment jamais : il se tait. |
| **MC Béton** | Rappeur du quartier, voix de la radio pirate. | Rimes même en parlant. | Timide dès qu'il n'y a plus de micro. |
| **Tata Rose** | Tient le panier solidaire. | Chaleureuse, compte tout à voix haute. | La meilleure logisticienne de l'Essonne. |
| **Clé-de-12** | Mécano du garage clandestin. | Grognon, diagnostics en métaphores de moteur. | Récite de la poésie en travaillant. |
| **Bernard, le gardien** | Concierge et indic… parce qu'on menace sa fille. | Poli, s'excuse tout le temps. | Tient un carnet de tout ce qu'il a dû signaler, pour le rendre un jour. |
| **Commandant Vasseur** | Chef de la Garde pour l'Essonne. Boss d'Évry. | Glacial, méthodique, ne hausse jamais le ton. | Croit sincèrement protéger les gens. |

### Secondaires (10 propositions)

| Personnage | Rôle | Voix | Lieu | Quêtes |
|---|---|---|---|---|
| **Madame Ferrand, « la Prof »** (58) | Ancienne prof de français, tient une école de nuit (zone neutre). | Précise, cite un poème puis jure. | Une cave de Grigny 2 | Retrouver des livres interdits ; « lire entre les lignes » des communiqués (indices). Joue aux échecs par correspondance avec un Vigile. |
| **Odette, « Mamie Scooter »** (74) | Ancienne factrice, connaît chaque boîte aux lettres et chaque digicode. | Gouailleuse, « mon lapin ». | Partout, sur sa mobylette | Messages à porter, codes des halls. La plus rapide du quartier. |
| **Yanis et Inès, « les Jumeaux du toit »** (20) | Chefs des guetteurs. | Finissent les phrases l'un de l'autre. | Les toits de Grigny 2 | Chemins de toits, angles morts (quête « Les yeux du quartier »). Inès étudie le droit par correspondance et cite l'ancienne Constitution. |
| **Docteure Lemaire, « Doc »** (45) | Médecin du centre de santé (zone neutre). | Calme, humour à froid. | Le centre de santé | Médicaments avec la daronne. Soigne tout le monde, Vigiles compris — et cache des gens dans l'ambulance. |
| **Kévin, « Pixel »** (19) | Graffeur du Collectif. | Enthousiaste, jargon d'atelier. | Sous la dalle | Spots de tags, pochoirs, bombes de peinture. Daltonien : il voit le gris du régime autrement. |
| **Agente Clémence Aubry** (26) | Vigile en poste à Grigny, qui doute. | Novlangue qui se fissure. | Point de Transit 7 | Infos de l'intérieur ; déserter ou non. Tricote pendant ses gardes de nuit. |
| **Monsieur Henri, « le Colonel »** (81) | Retraité qui « commande » le terrain de pétanque. | Métaphores militaires pour les boules. | Le Village | Réseau des Anciens, infos gagnées à la pétanque. N'a jamais fait l'armée. |
| **Sofia, « Radio-Trottoir »** (33) | Coiffeuse ; son salon est le carrefour des rumeurs. | Rapide, « Tu sais pas la dernière ? » | Grigny 2 | Lancer des contre-rumeurs ; coupes et déguisements (statut citoyen). Tient les comptes de qui doit un service à qui. |
| **Mehdi, « le Chef »** (38) | Tient le snack, nourrit le bloc. | Généreux, parle en formules du menu. | Grigny 2 | Chaîne de ravitaillement, nourrir la file. Ancien étudiant en philosophie : cite Épicure entre deux commandes. |
| **Lila, « Câble »** (24) | Électricienne de la copropriété. | Technique, pince-sans-rire. | Les gaines techniques | Couper le courant des caméras, réparer l'ascenseur. Collectionne les vieilles ampoules. |

## 8. Quêtes

Pilotées par les données (`data/quests/*.json`, schéma JSON). Types d'objectif : `TALK`,
`GOTO`, `COLLECT`, `DELIVER`, `PUBLISH`, `SABOTAGE`, `HACK`, `ESCORT`, `STEALTH`, `DEFEND`,
`NEUTRALIZE`. Réponses avec le ton affiché : **Calme / Cash / Malin**.

### Acte 1 — La tour

| # | Quête | Donneur | Étapes | Choix et récompenses |
|---|---|---|---|---|
| 1 | **Ascenseur en panne** | La daronne | Réveil au 11e ; `TALK` la daronne ; manger et boire (tutoriel des besoins) ; `COLLECT` le bidon ; `GOTO` l'ascenseur (en panne), descendre par l'escalier jusqu'au hall. | 50 XP. Apprend : se déplacer, interagir, besoins. |
| 2 | **La file** | La daronne | `GOTO` le point de ration ; contrôle d'identité ; un voisin, Monsieur Paul, est embarqué sous les caméras ; `COLLECT` l'eau ; `DELIVER` à la daronne. | Se taire (Calme : rien) · protester (Cash : Vigilance +1, Familles +5) · faire diversion (Malin : sauve le sac de Monsieur Paul, récompense plus tard). 75 XP. |
| 3 | **Le Vieux du 7e** | Tonton | `TALK` Bernard, qui élude ; `TALK` Tonton ; `COLLECT` des piles ; `DELIVER` à Lucien (7e étage, frapper le bon code). | Lucien donne la liste des disparus et parle du Centre de Rééducation. Débloque la radio. Anciens +10. 100 XP. |
| 4 | **Les yeux du quartier** | Les Jumeaux du toit | `STEALTH` : ravitailler trois postes de guet sans être vu des caméras. | Carte de surveillance (cônes des caméras visibles). Collectif +10. 100 XP. |
| 5 | **Premier tag** | Pixel | `COLLECT` une bombe de peinture ; `GOTO` le mur de la tour après le couvre-feu ; `PUBLISH` le tag (colère / espoir / humour) ; semer les Vigiles. | Soutien +10, Vigilance +1. Le régime riposte sur ses écrans : avis de recherche pixelisé. 125 XP. |
| 6 | **Le Grand** | Lucien | `TALK` le Grand à la salle ; épreuve de confiance sans combat : porter de l'eau à trois étages, tenir les paos pour Mamie Scooter, répondre à « Pourquoi tu te bats ? ». | Le Grand rejoint la cause si Akan n'a tué personne. Sa présence divise par deux la peur des civils. +1 point de compétence. |
| 7 | **Le contact** | Le Grand | `GOTO` la passerelle vers la Grande Borne ; `TALK` l'émissaire de Zed ; le prix d'une première arme est un choix moral. | Livrer le colis sans regarder (ce sont des tickets volés au panier solidaire : Réseau +10, Familles −10) · payer cher · rendre les tickets à Tata Rose (Réseau −10, Familles +15, lance-pierre offert par Clé-de-12). |
| 8 | **La tour se lève** | Wifi | `SABOTAGE` la caméra du hall ; trois indices sur l'indic (le carnet, le téléphone, la lettre de menaces) ; confronter Bernard ; `TALK` cinq voisins ; `DEFEND` le hall pendant la descente des Vigiles. | Dénoncer Bernard (Soutien +5, il est perdu) · le retourner, s'il y a la lettre (agent double) · le menacer (il fuit : Vigilance +2). **Première zone libérée** : couleurs, vrais noms, planque. 300 XP. |

### Acte 2 — La ville

Principales :

1. **Le Labyrinthe** — trouver Zed dans les ruelles sinueuses de la Grande Borne, sous les drones ; négocier l'alliance.
2. **Radio Béton** — réunir les pièces de l'émetteur (Clé-de-12), poser l'antenne sur un toit, première émission de MC Béton (choix du ton).
3. **Les archives** — au Village, avec Lucien et la Prof : entrer dans l'ancienne mairie-école, sortir les plans de l'aqueduc et le « registre des prénoms », preuve du programme pilote.
4. **Par l'eau** — aux Lacs : circuler par les regards de l'aqueduc, saboter la station qui détourne l'eau. Première eau rendue (les besoins s'allègent).
5. **Écrans noirs** — avec Wifi : détourner l'écran géant de la Plaine Centrale (mini-jeu de piratage) pour diffuser la vérité.
6. **Grigny se lève** — soulèvement coordonné sur trois objectifs (la gare, la Plaine Centrale, la passerelle de l'A6) ; puis défendre la ville contre la contre-attaque. Grigny retrouve son nom.

Secondaires : *La fresque* (repeindre un mur avec Pixel, création originale stylisée), *Marché noir* (tournées pour Zed), *Courrier express* (Mamie Scooter), *Pétanque diplomatique* (le Colonel), *Le lavoir* (cache des Anciens), *La barque* (passeur des lacs), *Coupe d'été* (Sofia : changer de tête pour redescendre d'un statut), *Le menu du jour* (Mehdi), *Court-circuit* (Câble).

### Acte 3 — Le département

Principales :

1. **L'eau de tous** — Viry-Châtillon : reprendre la station de l'aqueduc (infiltration, sabotage, défense). L'eau revient dans toute la banlieue.
2. **Les quais** — Ris-Orangis : s'emparer d'une péniche de ravitaillement, rallier les dockers.
3. **Le camp** — forêt de Sénart : rejoindre le camp rebelle, recruter, s'entraîner.
4. **Rééducation** — Fleury-Mérogis : s'introduire dans le Centre de Rééducation et libérer les prisonniers politiques, dont Nino et Monsieur Paul. Tout ouvrir d'un coup (alarme, chaos, beaucoup de libérés) ou exfiltrer peu de monde en silence.
5. **Le prix de Zed** — selon la réputation auprès du Réseau et le choix de la quête 7 de l'acte 1 : Zed vend les plans du soulèvement (embuscade) ou sacrifie un convoi pour la cause.
6. **Préfecture** — Évry-Courcouronnes : entrer dans le QG régional. Face au commandant Vasseur : le neutraliser, ou retourner sa propre Garde par la propagande pour qu'elle l'arrête elle-même.
7. **Deux routes** — choisir Juvisy (s'emparer du train blindé : action) ou la Seine (les péniches de nuit sous les ponts : infiltration).

Secondaires : trois par zone, sur le même moule que l'acte 2 (ravitailler, taguer, saboter, escorter, pirater), chacune portée par un personnage local.

### Acte 4 — Paris

1. **Le Treizième** — entrer par le 13e arrondissement (la Grande Borne fut construite pour reloger des habitants du 13e : les familles se reconnaissent). Monter une planque.
2. **La Ville grise** — couper trois relais de GRAND FRÈRE, chacun par l'approche de son choix : piratage, sabotage ou propagande.
3. **Concorde** — le soulèvement final. La taille de la foule dépend du Soutien accumulé. Atteindre le centre de diffusion, entrer dans la Salle des Prénoms, faire face à GRAND FRÈRE.

## 9. Fins

Elles dépendent du Soutien total, du nombre de morts causées par Akan, du sort de Zed et du
dernier choix.

| Fin | Condition | Ce qui se passe |
|---|---|---|
| **Nos vrais noms** | Soutien élevé, peu ou pas de morts ; diffuser la vérité, puis éteindre l'IA devant tous | Paris retrouve ses couleurs. Le Grand parle à la foule : « Un grand frère, ça protège pas en enfermant. » |
| **Le courant coupé** | Débrancher GRAND FRÈRE sans rien expliquer | La liberté, et le chaos : tout reste à reconstruire. |
| **Le nouveau Grand Frère** | Beaucoup de morts ou Soutien faible ; prendre le contrôle de l'IA « pour le bien de tous » | Les écrans montrent le visage d'Akan. Le quartier détourne les yeux. |
| **La banlieue libre** | Échouer ou renoncer à Paris | Paris reste grise ; l'Essonne reste libre. Une frontière de couleur. |

## 10. Économie et objets

- **Argent liquide** : rare, sert au marché noir. **Tickets de rationnement** : monnaie du
  régime, liés au statut citoyen. **Troc** : toujours possible avec les habitants.
- **Mêlée** : batte, barre de fer, clé à molette, matraque (prise aux Vigiles).
- **Distance** : lance-pierre, pistolet, fusil à pompe, fusil d'assaut, fusil à impulsion
  du régime (fin de jeu). Munitions rares.
- **Gadgets** : fumigène, mortier d'artifice (diversion), bombe de peinture (tag, aveugler
  une caméra), brouilleur, drone piraté, crochet, talkie-walkie, mégaphone, faux papiers,
  masque.
- **Équipement** : sweat à capuche, doudoune, casquette, baskets, sac à dos (3 tailles),
  gilet pare-balles.
- **Ressources** : bouteille d'eau, bidon, jerrican, baguette, conserve, chips, kebab,
  ration grise du régime, fruits, trousse de soins, antidouleurs, munitions, billets,
  tickets, ferraille, composants électroniques, batteries, essence.

Armes et gadgets sont des objets de jeu avec des statistiques : aucune instruction réelle
de fabrication n'apparaît dans le contenu.

## 11. Interface et accessibilité

- Interface en pixel art, dessinée en 640×360 et agrandie à l'échelle entière.
- HUD : santé, endurance, faim, soif, Vigilance (0–5), statut citoyen, heure, zone
  (nom du régime ou vrai nom), raccourcis.
- **La couleur n'est jamais le seul signal** : chaque état (zone libérée, alerte, statut)
  a aussi une icône et un texte.
- Bulles de dialogue : 2 lignes au plus ; réponses avec le ton affiché.
- Carte de la zone avec la surveillance connue (cônes, patrouilles, caches).
- Options (M5) : taille du texte, modes daltoniens, difficulté, remappage des touches.

## 12. Direction artistique et son

- Monde 3D low-poly rendu comme du pixel art : 640×360, 16 px par mètre, contours,
  palette de 32 couleurs, léger tramage. Caméra orthographique isométrique, rotation par
  pas de 90°.
- Personnages, objets et props en voxels (1 voxel = 1/16 m), animés par parties rigides.
- **Palette du régime** : cinq gris béton, bleu nuit, orange sodium, rouge propagande.
  **Couleurs vives** réservées à la vie du quartier et à la rébellion.
- Ambiance : brume, pluie fréquente, cycle jour/nuit, écrans géants à la lumière froide,
  bourdonnement des drones, annonces au haut-parleur, sirènes lointaines, passage du train.
- Son : placeholders générés (sons rétro) ; annonces de propagande en texte avec effet
  radio. La musique revient avec la couleur : une zone libérée a son thème.

## 13. Garde-fous

- Fiction assumée : aucun parti, dirigeant, symbole, slogan, personne ni marque réels.
- Lieux de culte, écoles et lieux de soins sont neutres : ni combat ni cible.
- Pas de caricature fondée sur l'origine ou la religion.
- Aucun mineur impliqué dans la violence, les armes ou les trafics.
- La Grande Borne : s'inspirer et styliser, ne jamais copier fresques ni sculptures.

## 14. Questions ouvertes

1. Le titre définitif.
2. Le ton des fins : faut-il une cinquième fin où Akan s'efface au profit du collectif ?
3. La part de combat : le jeu doit rester finissable sans tuer personne.
4. La longueur des actes 3 et 4, à ajuster après les premiers playtests.
