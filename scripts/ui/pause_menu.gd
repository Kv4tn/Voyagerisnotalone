# PauseMenu
# Esc pauses the game: Resume, Save Game, Load Game, Main Menu (REQ-31, 50.2, 51.1).
# Save Game and Load Game open the three-slot screen. Main Menu asks first when
# progress since the last save would be lost (REQ-31.5).
# Part of res://scenes/ui/hud.tscn. Runs while the tree is paused.
class_name PauseMenu
extends Control

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

@onready var _hud: GameHud = get_parent() as GameHud
@onready var _resume_button: Button = %ResumeButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _menu_button: Button = %MainMenuButton
@onready var _status_label: Label = %StatusLabel
@onready var _slots: SaveSlotsPanel = $SaveSlotsPanel
@onready var _confirm: ConfirmDialog = $ConfirmDialog

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume_button.pressed.connect(close)
	_save_button.pressed.connect(_slots.open.bind(SaveSlotsPanel.MODE_SAVE))
	_load_button.pressed.connect(_slots.open.bind(SaveSlotsPanel.MODE_LOAD))
	_menu_button.pressed.connect(_on_main_menu_pressed)
	_slots.closed.connect(_on_slots_closed)
	_slots.saved.connect(_on_slot_saved)
	_slots.load_started.connect(_on_load_started)

func _unhandled_input(event: InputEvent) -> void:
	# The slot screen and the confirm dialog are children and handle Esc first.
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
	_refresh_status()
	_resume_button.grab_focus()

func close() -> void:
	visible = false
	if GameState.is_paused:
		GameState.resume_game()

func is_open() -> bool:
	return visible

func get_status_text() -> String:
	return _status_label.text

func get_slots_panel() -> SaveSlotsPanel:
	return _slots

func get_confirm_dialog() -> ConfirmDialog:
	return _confirm

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _refresh_status() -> void:
	var latest: int = SaveManager.get_latest_slot()
	_load_button.disabled = latest == 0
	if latest == 0:
		_status_label.text = "No saved games yet."
	else:
		_status_label.text = "Last save: slot %d · %s" % [
			latest, SaveManager.describe_slot(SaveManager.get_slot_info(latest))]
	if SaveManager.has_unsaved_progress():
		_status_label.text += "\nUnsaved progress."

func _go_to_main_menu() -> void:
	visible = false
	GameState.reset_game()
	SceneManager.transition_to(GameState.MAIN_MENU_PATH)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_main_menu_pressed() -> void:
	if SaveManager.has_unsaved_progress():
		_confirm.ask("Return to the main menu? Progress since your last save will be lost.",
			_go_to_main_menu, "Leave")
	else:
		_go_to_main_menu()

func _on_slots_closed() -> void:
	if not visible:
		return
	_refresh_status()
	_resume_button.grab_focus()

func _on_slot_saved(slot: int) -> void:
	_refresh_status()
	_status_label.text = "Saved to slot %d.\n" % slot + _status_label.text

func _on_load_started(_slot: int) -> void:
	# Loading restores the game and unpauses it.
	visible = false
