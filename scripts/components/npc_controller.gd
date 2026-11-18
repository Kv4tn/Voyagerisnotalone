# NPCController
# Standing NPC that starts its dialogue when the player uses it (E).
# Name and dialogue file come from res://data/npcs/<npc_id>.json.
# Attached to: res://scenes/npcs/npc_base.tscn (inherit it for each character)
class_name NPCController
extends CharacterBody2D

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

## Must match a file in res://data/npcs/ (e.g. "elias_voss").
@export var npc_id: String = ""
## Key in the metadata's dialogue_files used when the player talks.
@export var dialogue_key: String = "prologue"

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var display_name: String = ""

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

@onready var _interactable: Interactable = $Interactable
@onready var _placeholder: Node2D = $Placeholder

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	display_name = NpcRegistry.get_display_name(npc_id)
	_interactable.prompt_text = "Talk to " + display_name
	_interactable.interacted.connect(_on_interacted)
	if NpcRegistry.get_metadata(npc_id).is_empty():
		push_error("NPCController '%s': no valid metadata in %s" % [name, NpcRegistry.NPC_DIR])

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func face_towards(target: Vector2) -> void:
	"""Turn the sprite left or right towards a world position."""
	if absf(target.x - global_position.x) > 1.0:
		_placeholder.scale.x = -1.0 if target.x < global_position.x else 1.0

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_interacted(interactor: Node) -> void:
	if interactor is Node2D:
		face_towards((interactor as Node2D).global_position)
	var path: String = NpcRegistry.get_dialogue_path(npc_id, dialogue_key)
	if path.is_empty():
		push_warning("NPCController '%s': no dialogue_files.%s" % [npc_id, dialogue_key])
		return
	DialogueManager.start_dialogue(path, npc_id)
