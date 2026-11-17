# QuestManager
# Tracks quest progress and completion
# Autoload singleton: res://scripts/core/quest_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var active_quests: Dictionary = {}  # quest_id: quest_data
var completed_quests: Array[String] = []

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("QuestManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func activate_quest(quest_id: String) -> void:
	"""Activate a quest"""
	# TODO: Implement in Task 4.1
	print("QuestManager: activate_quest() - Not yet implemented")
	print("  quest_id: %s" % quest_id)

func reset() -> void:
	"""Reset all quests"""
	active_quests.clear()
	completed_quests.clear()
