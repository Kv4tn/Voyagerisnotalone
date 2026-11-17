# DialogueManager
# Manages conversation presentation and branching logic
# Autoload singleton: res://scripts/core/dialogue_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal dialogue_started(dialogue_id: String)
signal dialogue_ended()
signal dialogue_choice_made(choice_index: int)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var is_dialogue_active: bool = false
var current_dialogue_id: String = ""

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("DialogueManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func start_dialogue(dialogue_id: String) -> void:
	"""Start a dialogue sequence"""
	# TODO: Implement in Task 3.3
	print("DialogueManager: start_dialogue() - Not yet implemented")
	print("  dialogue_id: %s" % dialogue_id)

func reset() -> void:
	"""Reset dialogue state"""
	is_dialogue_active = false
	current_dialogue_id = ""
