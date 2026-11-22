# StoryFlagManager
# Manages global story flags and conditions
# Autoload singleton: res://scripts/core/story_flag_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal story_flag_set(flag_name: String, value: Variant)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var flags: Dictionary = {}  # flag_name: value (bool, int, or string)

# ============================================================================
# CONSTANTS
# ============================================================================

## Largest integer a JSON double holds exactly (2^53).
const MAX_SAFE_INTEGER: float = 9007199254740992.0

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("StoryFlagManager: Ready")
	initialize_default_flags()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func initialize_default_flags() -> void:
	"""Initialize default story flags"""
	# Chapter 1 flags
	flags["game_started"] = false
	flags["player_name_set"] = false
	flags["station_intro_complete"] = false
	flags["met_maya"] = false
	flags["met_elias"] = false
	flags["met_nora"] = false
	flags["met_daniel"] = false
	flags["power_grid_puzzle_started"] = false
	flags["power_grid_puzzle_complete"] = false
	flags["power_restored"] = false
	flags["preflight_checklist_started"] = false
	flags["preflight_checklist_complete"] = false
	flags["launch_authorized"] = false
	flags["engineering_log_read"] = false
	flags["signal_disclosed"] = false
	flags["power_draw_investigated"] = false

func set_flag(flag_name: String, value: Variant) -> void:
	"""Set a story flag value"""
	if not flags.has(flag_name):
		push_warning("StoryFlagManager: Creating new flag '%s'" % flag_name)
	
	value = normalize_value(value)
	flags[flag_name] = value
	print("StoryFlagManager: Flag '%s' set to %s" % [flag_name, str(value)])
	story_flag_set.emit(flag_name, value)

func get_flag(flag_name: String, default_value: Variant = false) -> Variant:
	"""Get a story flag value"""
	if not flags.has(flag_name):
		push_warning("StoryFlagManager: Flag '%s' not found, returning default: %s" % [flag_name, str(default_value)])
		return default_value
	
	return flags[flag_name]

func has_flag(flag_name: String) -> bool:
	"""Check if a flag exists"""
	return flags.has(flag_name)

func check_condition(condition: Dictionary) -> bool:
	"""
	Check if a condition is met
	@param condition: Dictionary with format {"flag_name": expected_value}
	@return: True if all conditions are met
	"""
	for flag_name in condition.keys():
		var expected_value = condition[flag_name]
		var actual_value = get_flag(flag_name)
		if actual_value != expected_value:
			return false
	return true

func reset() -> void:
	"""Reset all flags to initial state"""
	flags.clear()
	initialize_default_flags()

static func normalize_value(value: Variant) -> Variant:
	"""
	JSON reads every number as float. Whole numbers become int so a flag set
	from dialogue JSON (3.0) and one set in code (3) compare equal, and saved
	values come back with the same type.
	"""
	if value is float and is_finite(value) and value == roundf(value) and absf(value) < MAX_SAFE_INTEGER:
		return int(value)
	return value

func get_save_data() -> Dictionary:
	"""All flags for the save file."""
	return flags.duplicate(true)

static func validate_save_data(data: Variant) -> PackedStringArray:
	"""Check the story_data.flags section of a save file."""
	var errors: PackedStringArray = []
	if not data is Dictionary:
		errors.append("story_data.flags must be an object")
		return errors
	for flag_name: Variant in data:
		var value: Variant = data[flag_name]
		if not flag_name is String or (flag_name as String).is_empty():
			errors.append("story_data.flags: flag names must be non-empty strings")
		elif not (value is bool or value is int or value is float or value is String):
			errors.append("story_data.flags.%s must be true/false, a number or text" % flag_name)
	return errors

func load_save_data(data: Dictionary) -> void:
	"""
	Restore flags from a validated save. Starts from the defaults so flags
	added in newer game versions exist. Emits no signals: quest progress is
	restored from its own section, not re-derived from flags.
	"""
	reset()
	for flag_name: String in data:
		flags[flag_name] = normalize_value(data[flag_name])
