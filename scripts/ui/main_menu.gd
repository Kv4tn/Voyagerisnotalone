# MainMenu
# Title screen with Continue / New Game / Quit and the commander name entry
# (REQ-2, REQ-3). Continue loads save slot 1 and appears only when it exists.
# Attached to: res://scenes/ui/main_menu.tscn
class_name MainMenu
extends Control

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

## Text that produced the current error. LineEdit emits text_changed deferred,
## so a late signal for the same text must not clear a fresh error.
var _rejected_text: String = ""

const CONTINUE_SLOT: int = 1

@onready var _menu_panel: Control = $MenuPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _save_info_label: Label = %SaveInfoLabel
@onready var _menu_message_label: Label = %MenuMessageLabel
@onready var _new_game_button: Button = %NewGameButton
@onready var _quit_button: Button = %QuitButton
@onready var _name_panel: Control = $NamePanel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _error_label: Label = %ErrorLabel
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_show_name_entry)
	_quit_button.pressed.connect(GameState.quit_game)
	_start_button.pressed.connect(_try_start)
	_back_button.pressed.connect(_show_menu)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.max_length = GameState.MAX_PLAYER_NAME_LENGTH
	# Since Godot 4.4 Enter leaves edit mode; after a rejected name the
	# player must be able to keep typing without pressing Enter again.
	_name_edit.keep_editing_on_text_submit = true
	_show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if _name_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_menu()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func get_save_info_text() -> String:
	return _save_info_label.text

func get_menu_message() -> String:
	return _menu_message_label.text

func is_name_entry_open() -> bool:
	return _name_panel.visible

func get_error_text() -> String:
	return _error_label.text

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _show_menu() -> void:
	_name_panel.visible = false
	_menu_panel.visible = true
	_refresh_continue()
	if _continue_button.visible and not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()

func _refresh_continue() -> void:
	var info: Dictionary = SaveManager.get_slot_info(CONTINUE_SLOT)
	_continue_button.visible = info["exists"]
	_continue_button.disabled = not info["valid"]
	if not info["exists"]:
		_save_info_label.text = ""
	elif info["valid"]:
		_save_info_label.text = SaveManager.describe_slot(info)
	else:
		_save_info_label.text = "Saved game is damaged: " + str(info["error"])

func _show_name_entry() -> void:
	_menu_panel.visible = false
	_name_panel.visible = true
	_name_edit.clear()
	_error_label.text = ""
	_name_edit.grab_focus()
	_name_edit.edit()

func _try_start() -> void:
	var candidate: String = _name_edit.text.strip_edges()
	var error: String = GameState.get_player_name_error(candidate)
	if not error.is_empty():
		_rejected_text = _name_edit.text
		_error_label.text = error
		_name_edit.grab_focus()
		_name_edit.edit()
		return

	# Freeze the form so a second Enter cannot start the game twice.
	_name_edit.editable = false
	_start_button.disabled = true
	_back_button.disabled = true
	GameState.start_new_game(candidate)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_continue_pressed() -> void:
	_menu_message_label.text = ""
	if SaveManager.load_game(CONTINUE_SLOT):
		# Lock the menu so a second press cannot start a second load.
		for button: Button in [_continue_button, _new_game_button, _quit_button]:
			button.disabled = true
	else:
		_menu_message_label.text = SaveManager.last_error

func _on_name_submitted(_text: String) -> void:
	_try_start()

func _on_name_changed(new_text: String) -> void:
	if new_text != _rejected_text:
		_error_label.text = ""
