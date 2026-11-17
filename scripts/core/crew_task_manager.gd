# CrewTaskManager
# Manages crew task assignments during shipboard operations
# Autoload singleton: res://scripts/core/crew_task_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal task_assigned(crew_id: String, task_id: String)
signal task_completed(crew_id: String, task_id: String)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var active_tasks: Dictionary = {}  # crew_id: task_data

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("CrewTaskManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func assign_task(crew_id: String, task_id: String) -> void:
	"""Assign a task to a crew member"""
	# TODO: Implement in Task 5.6
	print("CrewTaskManager: assign_task() - Not yet implemented")
	print("  crew_id: %s, task_id: %s" % [crew_id, task_id])
