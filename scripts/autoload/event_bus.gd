extends Node
## Bus de signaux global : les systèmes s'y abonnent au lieu de se connaître entre eux.
## Un autoload est un nœud chargé une seule fois au lancement et accessible partout
## par son nom (ici « EventBus »).

## Une partie vient d'être écrite dans l'emplacement `slot`.
signal game_saved(slot: int)
## Une partie vient d'être relue depuis l'emplacement `slot`.
signal game_loaded(slot: int)
## Demande de changement de saturation du rendu : 0.0 = gris du régime, 1.0 = pleine couleur.
signal saturation_change_requested(target: float, duration: float)
