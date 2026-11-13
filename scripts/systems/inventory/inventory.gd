class_name Inventory
extends RefCounted
## Le sac d'Akan : une grille de cases, des piles d'objets, quatre raccourcis.
## Les fiches d'objets (data/items/) donnent la taille maximale d'une pile.

## Le contenu a changé ; `item_id` est vide quand seul le rangement a bougé.
signal changed(item_id: String)

const NO_BAG := ""
## Taille de la grille (colonnes, lignes) selon le sac porté.
const BAG_GRIDS := {
	NO_BAG: Vector2i(4, 3),
	"sac_petit": Vector2i(5, 4),
	"sac_moyen": Vector2i(6, 5),
	"sac_grand": Vector2i(7, 6),
}
const QUICK_SLOT_COUNT := 4
const DEFAULT_STACK := 1

var bag := NO_BAG
var columns := 0
var rows := 0
## Une case est {} (vide) ou {"id": String, "count": int}.
var slots: Array[Dictionary] = []
var quick_slots: Array[String] = []

var _items: Dictionary


func _init(items: Dictionary) -> void:
	_items = items
	for i: int in QUICK_SLOT_COUNT:
		quick_slots.append("")
	set_bag(NO_BAG)


func stack_size(item_id: String) -> int:
	var item: Dictionary = _items.get(item_id, {})
	return int(item.get("stack", DEFAULT_STACK))


func count(item_id: String) -> int:
	var total := 0
	for slot: Dictionary in slots:
		if slot.get("id") == item_id:
			total += _count_of(slot)
	return total


## Vrai si le sac contient un objet lourd (bidon plein…) : on ne court plus.
func carries_heavy() -> bool:
	return _carries("heavy")


## Vrai si le sac contient un objet interdit (du matériel de guet) : qui le voit s'inquiète.
func carries_contraband() -> bool:
	return _carries("contraband")


# Vrai si un objet du sac porte la marque `key` (« heavy », « contraband »).
func _carries(key: String) -> bool:
	for slot: Dictionary in slots:
		var item: Dictionary = _items.get(slot.get("id", ""), {})
		if item.get(key, false):
			return true
	return false


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Ajoute `amount` objets et rend le nombre de ceux qui n'ont pas trouvé de place.
func add(item_id: String, amount: int = 1) -> int:
	if not _items.has(item_id):
		push_error("Objet inconnu : %s" % item_id)
		return amount
	var left := amount
	var stack := stack_size(item_id)
	# D'abord compléter les piles entamées, puis ouvrir de nouvelles cases.
	for slot: Dictionary in slots:
		if left > 0 and slot.get("id") == item_id:
			var moved := mini(stack - _count_of(slot), left)
			slot["count"] = _count_of(slot) + moved
			left -= moved
	for index: int in slots.size():
		if left > 0 and slots[index].is_empty():
			var moved := mini(stack, left)
			slots[index] = {"id": item_id, "count": moved}
			left -= moved
	if left < amount:
		changed.emit(item_id)
	return left


## Retire `amount` objets, ou rien du tout s'il n'y en a pas assez.
func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	var left := amount
	for index: int in range(slots.size() - 1, -1, -1):
		var slot := slots[index]
		if left <= 0 or slot.get("id") != item_id:
			continue
		var taken := mini(_count_of(slot), left)
		left -= taken
		if taken == _count_of(slot):
			slots[index] = {}
		else:
			slot["count"] = _count_of(slot) - taken
	if count(item_id) == 0:
		_forget_quick_slot(item_id)
	changed.emit(item_id)
	return true


## Change de sac. Refuse, sans rien toucher, si le contenu ne tient pas dans le nouveau.
func set_bag(bag_id: String) -> bool:
	if not BAG_GRIDS.has(bag_id):
		return false
	var grid: Vector2i = BAG_GRIDS[bag_id]
	var kept: Array[Dictionary] = []
	for slot: Dictionary in slots:
		if not slot.is_empty():
			kept.append(slot)
	if kept.size() > grid.x * grid.y:
		return false
	bag = bag_id
	columns = grid.x
	rows = grid.y
	slots = kept
	while slots.size() < columns * rows:
		slots.append({})
	changed.emit("")
	return true


## Déplace la case `from` vers `to` : deux piles du même objet fusionnent s'il reste de
## la place, sinon les deux cases s'échangent.
func move(from: int, to: int) -> void:
	if from == to or not _is_slot(from) or not _is_slot(to) or slots[from].is_empty():
		return
	var source := slots[from]
	var target := slots[to]
	var item_id: String = source["id"]
	var room := stack_size(item_id) - _count_of(target)
	if target.get("id") == item_id and room > 0:
		var moved := mini(room, _count_of(source))
		target["count"] = _count_of(target) + moved
		if moved == _count_of(source):
			slots[from] = {}
		else:
			source["count"] = _count_of(source) - moved
	else:
		slots[from] = target
		slots[to] = source
	changed.emit("")


## Place un objet du sac dans un raccourci ; un objet n'occupe qu'un raccourci.
func assign_quick_slot(index: int, item_id: String) -> void:
	if index < 0 or index >= QUICK_SLOT_COUNT:
		return
	_forget_quick_slot(item_id)
	quick_slots[index] = item_id if has(item_id) else ""
	changed.emit("")


func to_dict() -> Dictionary:
	return {"bag": bag, "slots": slots.duplicate(true), "quick_slots": quick_slots.duplicate()}


## Ignore un état mal formé : le contenu actuel est conservé.
func from_dict(state: Dictionary) -> void:
	var saved_bag := SaveCodec.text(state, "bag", "?")
	if not BAG_GRIDS.has(saved_bag) or not state.get("slots") is Array:
		return
	slots.clear()
	set_bag(saved_bag)
	var saved_slots := SaveCodec.list(state, "slots")
	for index: int in mini(saved_slots.size(), slots.size()):
		var saved: Variant = saved_slots[index]
		if not saved is Dictionary:
			continue
		var item_id := SaveCodec.text(saved, "id", "")
		var amount := int(SaveCodec.number(saved, "count", 0.0))
		if _items.has(item_id) and amount > 0:
			slots[index] = {"id": item_id, "count": mini(amount, stack_size(item_id))}
	var saved_quick := SaveCodec.list(state, "quick_slots")
	for index: int in QUICK_SLOT_COUNT:
		var item_id: Variant = saved_quick[index] if index < saved_quick.size() else ""
		quick_slots[index] = item_id if item_id is String and has(item_id) else ""
	changed.emit("")


func _is_slot(index: int) -> bool:
	return index >= 0 and index < slots.size()


func _count_of(slot: Dictionary) -> int:
	return int(slot.get("count", 0))


func _forget_quick_slot(item_id: String) -> void:
	for index: int in QUICK_SLOT_COUNT:
		if quick_slots[index] == item_id:
			quick_slots[index] = ""
