class_name Progression
extends RefCounted
## Expérience, niveaux, compétences et réputation d'Akan.

signal leveled_up(level: int)
signal reputation_changed(group: String, value: int)

## Les cinq arbres de compétences ; chacun compte MAX_SKILL_LEVEL paliers.
const SKILLS: Array[String] = ["discretion", "combat", "influence", "debrouille", "piratage"]
const MAX_SKILL_LEVEL := 4
const MAX_LEVEL := 30
## XP à gagner pour passer du niveau n au niveau n + 1 : n × XP_STEP.
const XP_STEP := 100
const MAX_REPUTATION := 100

var level := 1
var xp := 0
var skill_points := 0

var _skills := {}
var _reputation := {}


## XP total à accumuler pour atteindre `target_level`.
static func xp_for_level(target_level: int) -> int:
	return XP_STEP * target_level * (target_level - 1) / 2


func add_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
		skill_points += 1
		leveled_up.emit(level)


func skill_level(skill: String) -> int:
	return _skills.get(skill, 0)


## Dépense un point pour monter d'un palier. Rend false si c'est impossible.
func learn(skill: String) -> bool:
	if not skill in SKILLS or skill_points <= 0 or skill_level(skill) >= MAX_SKILL_LEVEL:
		return false
	skill_points -= 1
	_skills[skill] = skill_level(skill) + 1
	return true


func reputation(group: String) -> int:
	return _reputation.get(group, 0)


func add_reputation(group: String, amount: int) -> void:
	var value := clampi(reputation(group) + amount, -MAX_REPUTATION, MAX_REPUTATION)
	_reputation[group] = value
	reputation_changed.emit(group, value)


func to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"skill_points": skill_points,
		"skills": _skills.duplicate(),
		"reputation": _reputation.duplicate(),
	}


func from_dict(state: Dictionary) -> void:
	level = clampi(int(SaveCodec.number(state, "level", level)), 1, MAX_LEVEL)
	xp = maxi(int(SaveCodec.number(state, "xp", xp)), 0)
	skill_points = maxi(int(SaveCodec.number(state, "skill_points", skill_points)), 0)
	_skills.clear()
	var saved_skills := SaveCodec.table(state, "skills")
	for skill: String in SKILLS:
		var tier := int(SaveCodec.number(saved_skills, skill, 0.0))
		if tier > 0:
			_skills[skill] = mini(tier, MAX_SKILL_LEVEL)
	_reputation.clear()
	var saved_reputation := SaveCodec.table(state, "reputation")
	for group: Variant in saved_reputation:
		if group is String:
			var value := int(SaveCodec.number(saved_reputation, group, 0.0))
			_reputation[group] = clampi(value, -MAX_REPUTATION, MAX_REPUTATION)
