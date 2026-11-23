# Door
# Solid station door. Using it (E) takes the player to target_scene and puts
# them on the Marker2D named spawn_point_name there (REQ-8.2, task 2.6).
# A door can stay locked until a story flag is true; then E shows locked_message.
# Attached to: res://scenes/prefabs/door.tscn
# Dias: place the scene in a room's wall and fill in the inspector fields.
# docs/room-setup.md explains spawn markers; the content check validates links.
class_name Door
extends StaticBody2D

# ============================================================================
# CONSTANTS
# ============================================================================

const OPEN_COLOR: Color = Color(0.37, 0.7, 0.77, 1.0)
const LOCKED_COLOR: Color = Color(0.85, 0.36, 0.33, 1.0)

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

## Scene this door leads to.
@export_file("*.tscn") var target_scene: String = ""
## Name of the Marker2D in target_scene where the player appears.
@export var spawn_point_name: String = ""
## Shown in the prompt: "[E] Go to <destination_name>".
@export var destination_name: String = "Next Room"
## Story flag that must be true to open the door. Empty = always open.
@export var required_flag: String = ""
## Shown when the player uses the door while it is locked.
@export_multiline var locked_message: String = "Access restricted."

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

@onready var _interactable: Interactable = $Interactable
@onready var _light: CanvasItem = $Placeholder/Light

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	StoryFlagManager.story_flag_set.connect(_on_story_flag_set)
	_refresh()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func is_locked() -> bool:
	if required_flag.is_empty():
		return false
	return not (StoryFlagManager.has_flag(required_flag) and StoryFlagManager.get_flag(required_flag) == true)

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _refresh() -> void:
	var locked: bool = is_locked()
	_interactable.prompt_text = ("%s (locked)" if locked else "Go to %s") % destination_name
	_light.modulate = LOCKED_COLOR if locked else OPEN_COLOR

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_interacted(_interactor: Node) -> void:
	if is_locked():
		get_tree().call_group(GameHud.GROUP_MESSAGE_DISPLAY, &"show_message", destination_name, locked_message)
		return
	SceneManager.travel_to(target_scene, spawn_point_name)

func _on_story_flag_set(flag_name: String, _value: Variant) -> void:
	if flag_name == required_flag:
		_refresh()
