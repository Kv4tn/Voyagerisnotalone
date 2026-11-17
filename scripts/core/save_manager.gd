# SaveManager
# Handles game state persistence to disk
# Autoload singleton: res://scripts/core/save_manager.gd
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

const SAVE_VERSION: String = "1.0"
const SAVE_DIR: String = "user://saves/"
const MAX_SAVE_SLOTS: int = 3

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("SaveManager: Ready")
	ensure_save_directory()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func save_game(slot: int) -> bool:
	"""Save game to specified slot"""
	# TODO: Implement in Task 9.1
	print("SaveManager: save_game() - Not yet implemented")
	print("  slot: %d" % slot)
	return false

func load_game(slot: int) -> bool:
	"""Load game from specified slot"""
	# TODO: Implement in Task 9.2
	print("SaveManager: load_game() - Not yet implemented")
	print("  slot: %d" % slot)
	return false

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func ensure_save_directory() -> void:
	"""Ensure save directory exists"""
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		print("SaveManager: Created save directory: %s" % SAVE_DIR)
