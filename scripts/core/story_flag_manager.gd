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
