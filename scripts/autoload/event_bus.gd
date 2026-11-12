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

## Une nouvelle partie commence, ou une partie vient d'être relue : tout est à relire.
signal game_state_reset
signal flag_changed(flag: String)
## Le contenu du sac a changé ; `item_id` est vide quand seul le rangement a bougé.
signal inventory_changed(item_id: String)
## Des objets n'ont pas trouvé de place dans le sac : ils tombent aux pieds d'Akan.
signal item_dropped(item_id: String, amount: int)
signal item_used(item_id: String)
signal quest_started(quest_id: String)
## L'étape en cours d'une quête a changé, ou son compteur a bougé.
signal quest_progressed(quest_id: String)
signal quest_step_completed(quest_id: String, step_id: String)
signal quest_completed(quest_id: String)
signal territory_changed(zone_id: String)
signal zone_liberated(zone_id: String)
signal vigilance_changed(zone_id: String, level: int)
## `status` est une valeur de Surveillance.Status.
signal status_changed(status: int)
signal leveled_up(level: int)
signal player_downed
## Akan vise un autre élément du monde ; `prompt` est vide quand il n'en vise aucun.
signal interaction_focus_changed(prompt: String)
## Demande de changement de lieu : « grigny2@gare », « appartement_akan ».
signal travel_requested(target: String)
