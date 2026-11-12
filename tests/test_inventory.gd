extends GutTest

const ITEMS := {
	"eau": {"id": "eau", "stack": 5},
	"batte": {"id": "batte", "stack": 1},
	"tickets": {"id": "tickets", "stack": 99},
}

var _inventory: Inventory


func before_each() -> void:
	_inventory = Inventory.new(ITEMS)


func test_starts_with_the_pocket_grid() -> void:
	assert_eq(_inventory.columns * _inventory.rows, 12)
	assert_eq(_inventory.slots.size(), 12)


func test_adding_stacks_then_spills_into_new_slots() -> void:
	assert_eq(_inventory.add("eau", 7), 0)
	assert_eq(_inventory.count("eau"), 7)
	assert_eq(_inventory.slots[0], {"id": "eau", "count": 5})
	assert_eq(_inventory.slots[1], {"id": "eau", "count": 2})


func test_adding_to_a_full_bag_returns_what_did_not_fit() -> void:
	assert_eq(_inventory.add("batte", 12), 0)
	assert_eq(_inventory.add("batte", 3), 3)
	assert_eq(_inventory.count("batte"), 12)


func test_unknown_item_is_refused() -> void:
	assert_eq(_inventory.add("licorne", 2), 2)
	assert_push_error("licorne")
	assert_eq(_inventory.count("licorne"), 0)


func test_removing_takes_from_several_stacks_or_nothing() -> void:
	_inventory.add("eau", 7)
	assert_false(_inventory.remove("eau", 8))
	assert_eq(_inventory.count("eau"), 7)
	assert_true(_inventory.remove("eau", 6))
	assert_eq(_inventory.count("eau"), 1)
	assert_true(_inventory.has("eau"))


func test_bigger_bag_keeps_items_and_smaller_bag_refuses_if_it_overflows() -> void:
	_inventory.add("batte", 12)
	assert_true(_inventory.set_bag("sac_moyen"))
	assert_eq(_inventory.slots.size(), 30)
	assert_eq(_inventory.count("batte"), 12)
	_inventory.add("batte", 10)
	assert_false(_inventory.set_bag(""), "22 objets ne tiennent pas dans 12 cases")
	assert_eq(_inventory.slots.size(), 30)


func test_moving_swaps_or_merges_slots() -> void:
	_inventory.add("eau", 5)
	_inventory.add("eau", 2)
	_inventory.add("batte", 1)
	_inventory.move(2, 5)
	assert_eq(_inventory.slots[5], {"id": "batte", "count": 1})
	assert_eq(_inventory.slots[2], {})
	_inventory.move(1, 0)
	assert_eq(_inventory.slots[0]["count"], 2, "une pile pleine ne fusionne pas : échange")
	_inventory.remove("eau", 3)
	_inventory.move(1, 0)
	assert_eq(_inventory.slots[0], {"id": "eau", "count": 4})
	assert_eq(_inventory.slots[1], {})


func test_quick_slots_remember_items_and_forget_them_when_gone() -> void:
	_inventory.add("eau", 1)
	_inventory.assign_quick_slot(0, "eau")
	assert_eq(_inventory.quick_slots[0], "eau")
	_inventory.remove("eau", 1)
	assert_eq(_inventory.quick_slots[0], "")


func test_changes_are_signalled_and_state_round_trips() -> void:
	watch_signals(_inventory)
	_inventory.add("tickets", 30)
	assert_signal_emitted_with_parameters(_inventory, "changed", ["tickets"])
	var copy := Inventory.new(ITEMS)
	copy.from_dict(_inventory.to_dict())
	assert_eq(copy.count("tickets"), 30)
	copy.from_dict({"slots": "x"})
	assert_eq(copy.count("tickets"), 30)
