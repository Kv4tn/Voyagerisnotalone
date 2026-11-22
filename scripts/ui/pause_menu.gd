# PauseMenu
# Esc pauses the game: Resume, Save Game, Load Game, Main Menu (REQ-50.2, 51.1).
# Uses save slot 1 for now; the slot screen with three slots is task 9.3.
# Part of res://scenes/ui/hud.tscn. Runs while the tree is paused.
class_name PauseMenu
extends Control

# ============================================================================
# CONSTANTS
# ============================================================================

const SAVE_SLOT: int = 1

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

@onready var _hud: GameHud = get_parent() as GameHud
@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _status_label: Label = %StatusLabel

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(close)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_menu_button.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		get_viewport().set_input_as_handled()
		close()
		return
	# Esc closes the message box or does nothing during a conversation.
	if DialogueManager.is_dialogue_active or SceneManager.is_transitioning:
		return
	if _hud != null and _hud.is_message_open():
		return
	get_viewport().set_input_as_handled()
	open()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func open() -> void:
	GameState.pause_game()
	visible = true
	_show_slot_status()
	_resume_button.grab_focus()

func close() -> void:
	visible = false
	if GameState.is_paused:
		GameState.resume_game()

func is_open() -> bool:
	return visible

func get_status_text() -> String:
	return _status_label.text

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _show_slot_status() -> void:
	var info: Dictionary = SaveManager.get_slot_info(SAVE_SLOT)
	_load_button.disabled = not info["valid"]
	if not info["exists"]:
		_status_label.text = "Slot %d is empty." % SAVE_SLOT
	elif not info["valid"]:
		_status_label.text = "Slot %d is damaged: %s" % [SAVE_SLOT, info["error"]]
	else:
		_status_label.text = "Slot %d: %s" % [SAVE_SLOT, SaveManager.describe_slot(info)]

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_save_pressed() -> void:
	if SaveManager.save_game(SAVE_SLOT):
		_show_slot_status()
		_status_label.text = "Saved. " + _status_label.text
	else:
		_status_label.text = SaveManager.last_error

func _on_load_pressed() -> void:
	# Loading restores the game and unpauses it; on failure nothing changed.
	if SaveManager.load_game(SAVE_SLOT):
		visible = false
	else:
		_status_label.text = SaveManager.last_error

func _on_main_menu_pressed() -> void:
	visible = false
	GameState.reset_game()
	SceneManager.transition_to(GameState.MAIN_MENU_PATH)
