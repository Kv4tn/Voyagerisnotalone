# MainMenu
# Title screen with Continue / Load Game / New Game / Quit and the commander
# name entry (REQ-2, REQ-3). Continue loads the most recent valid save; Load
# Game opens the three-slot screen. Both appear only when a save exists.
# Attached to: res://scenes/ui/main_menu.tscn
class_name MainMenu
extends Control

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

## Text that produced the current error. LineEdit emits text_changed deferred,
## so a late signal for the same text must not clear a fresh error.
var _rejected_text: String = ""

@onready var _menu_panel: Control = $MenuPanel
@onready var _continue_button: Button = %ContinueButton
@onready var _load_game_button: Button = %LoadGameButton
@onready var _slots: SaveSlotsPanel = $SaveSlotsPanel
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
	_load_game_button.pressed.connect(_slots.open.bind(SaveSlotsPanel.MODE_LOAD))
	_slots.closed.connect(_show_menu)
	_slots.load_started.connect(_on_load_started)
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
	var any_save: bool = SaveManager.has_any_save()
	var latest: int = SaveManager.get_latest_slot()
	_continue_button.visible = any_save
	_continue_button.disabled = latest == 0
	_load_game_button.visible = any_save
	if not any_save:
		_save_info_label.text = ""
	elif latest == 0:
		_save_info_label.text = "All saved games are damaged. Open Load Game for details."
	else:
		_save_info_label.text = SaveManager.describe_slot(SaveManager.get_slot_info(latest))

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
	if SaveManager.load_game(SaveManager.get_latest_slot()):
		_on_load_started(SaveManager.get_latest_slot())
	else:
		_menu_message_label.text = SaveManager.last_error

func _on_load_started(_slot: int) -> void:
	# Lock the menu so a second press cannot start a second load.
	for button: Button in [_continue_button, _load_game_button, _new_game_button, _quit_button]:
		button.disabled = true

func _on_name_submitted(_text: String) -> void:
	_try_start()

func _on_name_changed(new_text: String) -> void:
	if new_text != _rejected_text:
		_error_label.text = ""
