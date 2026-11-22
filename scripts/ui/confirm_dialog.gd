# ConfirmDialog
# Modal yes/no question drawn over the current UI. "No" is focused first so
# Enter never destroys anything by accident; Esc answers no.
# Usage: dialog.ask("Delete slot 2?", _delete_slot.bind(2), "Delete")
# Scene: res://scenes/ui/confirm_dialog.tscn. Works while the game is paused.
class_name ConfirmDialog
extends Control

# ============================================================================
# SIGNALS
# ============================================================================

signal answered(confirmed: bool)

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _on_yes: Callable = Callable()
var _return_focus: Control = null

@onready var _message_label: Label = %MessageLabel
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_yes_button.pressed.connect(_answer.bind(true))
	_no_button.pressed.connect(_answer.bind(false))
	# Keep arrows and Tab inside the dialog; buttons behind it must stay unreachable.
	FocusUtils.link(_no_button, null, null, _yes_button, _yes_button)
	FocusUtils.link(_yes_button, null, null, _no_button, _no_button)
	FocusUtils.cycle_tab([_no_button, _yes_button])

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func ask(message: String, on_yes: Callable, yes_text: String = "Yes", no_text: String = "Cancel") -> void:
	"""Show the question; on_yes runs only if the player confirms."""
	_message_label.text = message
	_yes_button.text = yes_text
	_no_button.text = no_text
	_on_yes = on_yes
	_return_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_no_button.grab_focus()

func is_open() -> bool:
	return visible

func get_message() -> String:
	return _message_label.text

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _answer(confirmed: bool) -> void:
	if not visible:
		return
	visible = false
	var action: Callable = _on_yes
	_on_yes = Callable()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	answered.emit(confirmed)
	if confirmed and action.is_valid():
		action.call()
