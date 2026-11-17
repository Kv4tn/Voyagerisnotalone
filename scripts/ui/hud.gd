# GameHud
# Interaction prompt ("[E] Use terminal") and a simple message box.
# Attached to: res://scenes/ui/hud.tscn
# Any node can open the message box with:
#   get_tree().call_group(GameHud.GROUP_MESSAGE_DISPLAY, &"show_message", title, body)
class_name GameHud
extends CanvasLayer

# ============================================================================
# SIGNALS
# ============================================================================

signal message_opened()
signal message_closed()

# ============================================================================
# CONSTANTS
# ============================================================================

const GROUP_MESSAGE_DISPLAY: StringName = &"message_display"
const PROMPT_PREFIX: String = "[E] "
const NAME_PREFIX: String = "CMDR "

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _prompt_text: String = ""

@onready var _name_label: Label = $NameLabel
@onready var _prompt_panel: Control = $PromptPanel
@onready var _prompt_label: Label = $PromptPanel/PromptLabel
@onready var _message_panel: Control = $MessagePanel
@onready var _title_label: Label = $MessagePanel/Margin/VBox/TitleLabel
@onready var _body_label: Label = $MessagePanel/Margin/VBox/BodyLabel

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	add_to_group(GROUP_MESSAGE_DISPLAY)
	_message_panel.visible = false
	_refresh_prompt()
	GameState.player_name_changed.connect(_set_commander_name)
	_set_commander_name(GameState.player_name)

func _unhandled_input(event: InputEvent) -> void:
	if not _message_panel.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		# Consume the key so the player does not reuse the same press.
		get_viewport().set_input_as_handled()
		close_message()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func get_commander_text() -> String:
	return _name_label.text if _name_label.visible else ""

func is_message_open() -> bool:
	return _message_panel.visible

func get_prompt_text() -> String:
	return _prompt_label.text if _prompt_panel.visible else ""

func set_prompt(target: Interactable) -> void:
	_prompt_text = "" if target == null else PROMPT_PREFIX + target.prompt_text
	_refresh_prompt()

func show_message(title: String, body: String) -> void:
	_title_label.text = title
	_body_label.text = body
	_message_panel.visible = true
	_refresh_prompt()
	message_opened.emit()

func close_message() -> void:
	if not _message_panel.visible:
		return
	_message_panel.visible = false
	_refresh_prompt()
	message_closed.emit()

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _set_commander_name(commander_name: String) -> void:
	_name_label.text = NAME_PREFIX + commander_name.to_upper()
	_name_label.visible = not commander_name.is_empty()

func _refresh_prompt() -> void:
	_prompt_label.text = _prompt_text
	_prompt_panel.visible = not _prompt_text.is_empty() and not _message_panel.visible
