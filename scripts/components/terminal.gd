# Terminal
# Solid station console. Using it (E) shows its title and message in the HUD.
# Attached to: res://scenes/prefabs/terminal.tscn
# Dias: place the scene in a room and set terminal_id, title and message in the inspector.
class_name Terminal
extends StaticBody2D

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

@export var terminal_id: String = "terminal_01"
@export var title: String = "Terminal"
@export_multiline var message: String = ""

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

@onready var _interactable: Interactable = $Interactable

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_interacted(_interactor: Node) -> void:
	if get_tree().get_nodes_in_group(GameHud.GROUP_MESSAGE_DISPLAY).is_empty():
		push_warning("Terminal '%s': no node in group '%s' to show the message" % [
			terminal_id, GameHud.GROUP_MESSAGE_DISPLAY])
		return
	get_tree().call_group(GameHud.GROUP_MESSAGE_DISPLAY, &"show_message", title, message)
