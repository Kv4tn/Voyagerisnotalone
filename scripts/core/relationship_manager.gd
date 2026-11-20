# RelationshipManager
# Trust (confidence in the commander) and Bond (personal connection) for each
# crew member, both 0..100 (REQ-22, design.md 3.7).
# Changed by dialogue (change_relationship effect) and quest rewards; read by
# dialogue conditions. Autoload singleton: res://scripts/core/relationship_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted only when a value actually changes (after clamping).
signal relationship_changed(npc_id: String, relationship_type: String, old_value: int, new_value: int)

# ============================================================================
# CONSTANTS
# ============================================================================

const CREW_MEMBERS: PackedStringArray = ["maya_chen", "elias_voss", "nora_reyes", "daniel_kim"]
const TRUST: String = "trust"
const BOND: String = "bond"
const TYPES: PackedStringArray = [TRUST, BOND]

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100
## Starting value when data/npcs/<id>.json has no initial_relationships (REQ-22.3).
const DEFAULT_VALUE: int = 50

## Upper bounds of the design.md tiers: 0-25 low, 26-50 neutral, 51-75 good, 76+ high.
const TIER_LOW_MAX: int = 25
const TIER_NEUTRAL_MAX: int = 50
const TIER_GOOD_MAX: int = 75

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _values: Dictionary = {}  # npc_id -> {"trust": int, "bond": int}

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	reset()
	print("RelationshipManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func reset() -> void:
	"""Set every crew member to their starting values (new game)."""
	_values.clear()
	for npc_id: String in CREW_MEMBERS:
		var metadata: Dictionary = NpcRegistry.get_metadata(npc_id)
		_values[npc_id] = {
			TRUST: initial_value_from(metadata, TRUST),
			BOND: initial_value_from(metadata, BOND),
		}

func is_crew_member(npc_id: String) -> bool:
	return npc_id in CREW_MEMBERS

func get_value(npc_id: String, relationship_type: String) -> int:
	"""Current trust or bond; DEFAULT_VALUE (with a warning) for unknown input."""
	if not _is_valid(npc_id, relationship_type):
		return DEFAULT_VALUE
	return _values[npc_id][relationship_type]

func get_trust(npc_id: String) -> int:
	return get_value(npc_id, TRUST)

func get_bond(npc_id: String) -> int:
	return get_value(npc_id, BOND)

func get_relationship_status(npc_id: String) -> Dictionary:
	"""{trust, bond, trust_tier, bond_tier} for one crew member, {} if unknown."""
	if not is_crew_member(npc_id):
		push_warning("RelationshipManager: '%s' is not a crew member" % npc_id)
		return {}
	return {
		TRUST: get_trust(npc_id),
		BOND: get_bond(npc_id),
		"trust_tier": tier_for(get_trust(npc_id)),
		"bond_tier": tier_for(get_bond(npc_id)),
	}

func change(npc_id: String, relationship_type: String, amount: int) -> int:
	"""
	Add amount to trust or bond, clamped to MIN_VALUE..MAX_VALUE
	@return: The change actually applied (0 at the limits or for invalid input)
	"""
	if not _is_valid(npc_id, relationship_type):
		return 0
	var old_value: int = _values[npc_id][relationship_type]
	var new_value: int = clampi(old_value + amount, MIN_VALUE, MAX_VALUE)
	if new_value == old_value:
		return 0
	_values[npc_id][relationship_type] = new_value
	print("RelationshipManager: %s %s %d -> %d" % [npc_id, relationship_type, old_value, new_value])
	relationship_changed.emit(npc_id, relationship_type, old_value, new_value)
	return new_value - old_value

func modify_trust(npc_id: String, amount: int) -> int:
	return change(npc_id, TRUST, amount)

func modify_bond(npc_id: String, amount: int) -> int:
	return change(npc_id, BOND, amount)

static func tier_for(value: int) -> String:
	"""design.md tiers: low, neutral, good, high."""
	if value <= TIER_LOW_MAX:
		return "low"
	if value <= TIER_NEUTRAL_MAX:
		return "neutral"
	if value <= TIER_GOOD_MAX:
		return "good"
	return "high"

static func initial_value_from(metadata: Dictionary, relationship_type: String) -> int:
	"""Starting value from NPC metadata initial_relationships, clamped; DEFAULT_VALUE if absent."""
	var initial: Variant = metadata.get("initial_relationships", {})
	if not initial is Dictionary:
		return DEFAULT_VALUE
	var value: Variant = initial.get(relationship_type, DEFAULT_VALUE)
	if not (value is int or value is float):
		return DEFAULT_VALUE
	return clampi(int(value), MIN_VALUE, MAX_VALUE)

static func is_whole_number(value: Variant) -> bool:
	"""JSON numbers load as float; relationship numbers must still be whole."""
	return value is int or (value is float and is_equal_approx(value, roundf(value)))

func check_met(entry: Dictionary) -> bool:
	"""
	Evaluate a relationship check {npc_id, type, min?, max?} (validated by
	validate_check). Bounds are inclusive.
	"""
	var value: int = get_value(entry["npc_id"], entry["type"])
	if entry.has("min") and value < int(entry["min"]):
		return false
	if entry.has("max") and value > int(entry["max"]):
		return false
	return true

func apply_change(entry: Dictionary) -> int:
	"""Apply {npc_id, relationship, change} (validated by validate_change)."""
	return change(entry["npc_id"], entry["relationship"], int(entry["change"]))

static func validate_check(entry: Variant) -> String:
	"""
	Check the shape of {npc_id, type, min?, max?} used by dialogue conditions
	and quest prerequisites
	@return: "" when valid, otherwise a readable reason
	"""
	if not entry is Dictionary:
		return "each relationships entry must be an object"
	for key: Variant in entry:
		if not key in ["npc_id", "type", "min", "max"]:
			return "relationships entry: unknown field '%s'" % key
	var where: String = "relationships entry for '%s'" % str(entry.get("npc_id", "?"))
	if not _is_one_of(entry.get("npc_id"), CREW_MEMBERS):
		return where + ": npc_id must be a crew member (%s)" % ", ".join(CREW_MEMBERS)
	if not _is_one_of(entry.get("type"), TYPES):
		return where + ": type must be trust or bond"
	if not entry.has("min") and not entry.has("max"):
		return where + ": needs min and/or max"
	for key: String in ["min", "max"]:
		if entry.has(key) and (not is_whole_number(entry[key])
				or entry[key] < MIN_VALUE or entry[key] > MAX_VALUE):
			return where + ": %s must be a whole number from %d to %d" % [key, MIN_VALUE, MAX_VALUE]
	if entry.has("min") and entry.has("max") and entry["min"] > entry["max"]:
		return where + ": min is greater than max"
	return ""

static func validate_change(entry: Variant) -> String:
	"""
	Check {npc_id, relationship, change} used by the dialogue effect
	change_relationship and quest rewards
	@return: "" when valid, otherwise a readable reason
	"""
	if not entry is Dictionary:
		return "relationship change must be an object"
	var where: String = "relationship change for '%s'" % str(entry.get("npc_id", "?"))
	if not _is_one_of(entry.get("npc_id"), CREW_MEMBERS):
		return where + ": npc_id must be a crew member (%s)" % ", ".join(CREW_MEMBERS)
	if not _is_one_of(entry.get("relationship"), TYPES):
		return where + ": relationship must be trust or bond"
	var amount: Variant = entry.get("change")
	if not is_whole_number(amount) or is_zero_approx(float(amount)):
		return where + ": change must be a non-zero whole number"
	return ""

# ============================================================================
# PRIVATE METHODS
# ============================================================================

## `x in PackedStringArray` is a runtime error when x is not a String
## (e.g. a missing JSON field), so data from files is checked with this.
static func _is_one_of(value: Variant, allowed: PackedStringArray) -> bool:
	return value is String and allowed.has(value)

func _is_valid(npc_id: String, relationship_type: String) -> bool:
	if not is_crew_member(npc_id):
		push_warning("RelationshipManager: '%s' is not a crew member" % npc_id)
		return false
	if not relationship_type in TYPES:
		push_warning("RelationshipManager: unknown relationship type '%s'" % relationship_type)
		return false
	return true
