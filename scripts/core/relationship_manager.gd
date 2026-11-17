# RelationshipManager
# Tracks Trust and Bond values for all crew members
# Autoload singleton: res://scripts/core/relationship_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal relationship_changed(character_id: String, trust: int, bond: int)

# ============================================================================
# CONSTANTS
# ============================================================================

const MIN_RELATIONSHIP: int = 0
const MAX_RELATIONSHIP: int = 100

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var relationships: Dictionary = {}  # character_id: {trust: int, bond: int}

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("RelationshipManager: Ready")
	initialize_crew_relationships()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func initialize_crew_relationships() -> void:
	"""Initialize relationships for all crew members"""
	# Start with neutral relationships
	relationships["crew_maya"] = {"trust": 50, "bond": 50}
	relationships["crew_elias"] = {"trust": 50, "bond": 50}
	relationships["crew_nora"] = {"trust": 50, "bond": 50}
	relationships["crew_daniel"] = {"trust": 50, "bond": 50}

func change_trust(character_id: String, delta: int) -> void:
	"""Change trust value for a character"""
	# TODO: Implement in Task 3.7
	print("RelationshipManager: change_trust() - Not yet implemented")
	print("  character_id: %s, delta: %d" % [character_id, delta])

func change_bond(character_id: String, delta: int) -> void:
	"""Change bond value for a character"""
	# TODO: Implement in Task 3.7
	print("RelationshipManager: change_bond() - Not yet implemented")
	print("  character_id: %s, delta: %d" % [character_id, delta])

func reset() -> void:
	"""Reset all relationships to initial state"""
	initialize_crew_relationships()
