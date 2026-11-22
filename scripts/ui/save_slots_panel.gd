# SaveSlotsPanel
# Lists the three save slots with their metadata (task 9.3, REQ-50.6, 51.2).
# Save mode: pick a slot to save to (confirms before overwriting).
# Load mode: pick a slot to load (confirms first if progress would be lost).
# Each filled slot has a Delete button (confirmed). Esc or Back closes it.
# Scene: res://scenes/ui/save_slots_panel.tscn, used by the pause and main menus.
class_name SaveSlotsPanel
extends Control

# ============================================================================
# SIGNALS
# ============================================================================

signal closed()
signal saved(slot: int)
## Loading began; the caller should get out of the way (scene is changing).
signal load_started(slot: int)

# ============================================================================
# CONSTANTS
# ============================================================================

const MODE_SAVE: String = "save"
const MODE_LOAD: String = "load"
const DELETE_COLUMN_SIZE: Vector2 = Vector2(54, 22)

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _mode: String = MODE_LOAD
var _slot_buttons: Array[Button] = []
var _delete_buttons: Array[Button] = []

@onready var _title_label: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _status_label: Label = %SlotStatusLabel
@onready var _back_button: Button = %BackButton
@onready var _confirm: ConfirmDialog = $ConfirmDialog

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_back_button.pressed.connect(close)
	for slot: int in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var slot_button: Button = Button.new()
		slot_button.name = "Slot%dButton" % slot
		slot_button.custom_minimum_size = Vector2(0, 22)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.clip_text = true
		slot_button.add_theme_font_size_override("font_size", 11)
		slot_button.pressed.connect(_on_slot_pressed.bind(slot))
		var delete_button: Button = Button.new()
		delete_button.name = "Delete%dButton" % slot
		delete_button.text = "Delete"
		delete_button.add_theme_font_size_override("font_size", 10)
		delete_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		delete_button.pressed.connect(_on_delete_pressed.bind(slot))
		# The holder keeps the column width when Delete is hidden, so every
		# row's slot button has the same width.
		var delete_holder: Control = Control.new()
		delete_holder.custom_minimum_size = DELETE_COLUMN_SIZE
		delete_holder.add_child(delete_button)
		row.add_child(slot_button)
		row.add_child(delete_holder)
		_rows.add_child(row)
		_slot_buttons.append(slot_button)
		_delete_buttons.append(delete_button)

func _unhandled_input(event: InputEvent) -> void:
	# The confirm dialog is a child and answers Esc first when it is open.
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func open(mode: String) -> void:
	assert(mode == MODE_SAVE or mode == MODE_LOAD)
	_mode = mode
	_title_label.text = "SAVE GAME" if mode == MODE_SAVE else "LOAD GAME"
	_status_label.text = ""
	visible = true
	refresh()
	_focus_first_usable()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func get_mode() -> String:
	return _mode

func get_slot_button(slot: int) -> Button:
	return _slot_buttons[slot - 1]

func get_delete_button(slot: int) -> Button:
	return _delete_buttons[slot - 1]

func get_status_text() -> String:
	return _status_label.text

func get_confirm_dialog() -> ConfirmDialog:
	return _confirm

func refresh() -> void:
	for slot: int in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var info: Dictionary = SaveManager.get_slot_info(slot)
		var button: Button = get_slot_button(slot)
		button.text = describe_row(slot, info)
		# Saving may overwrite any slot; loading needs a valid save.
		button.disabled = _mode == MODE_LOAD and not info["valid"]
		get_delete_button(slot).visible = info["exists"]
	_link_focus()

static func describe_row(slot: int, info: Dictionary) -> String:
	"""e.g. "Slot 1   CMDR ASEL · Ch 1 · 0:12:34 · 2026-11-21 17:15"."""
	if not info["exists"]:
		return "Slot %d   Empty" % slot
	if not info["valid"]:
		return "Slot %d   Damaged: %s" % [slot, info["error"]]
	var saved_at: String = str(info["timestamp"]).replace("T", " ").left(16)
	return "Slot %d   CMDR %s · Ch %d · %s · %s" % [slot, str(info["player_name"]).to_upper(),
		int(info["chapter"]), SaveManager.format_playtime(info["playtime_seconds"]), saved_at]

func text_fits(slot: int) -> bool:
	"""True when the slot's row text is not clipped (used by tests)."""
	var button: Button = get_slot_button(slot)
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var style: StyleBox = button.get_theme_stylebox("normal")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return text_width <= button.size.x - style.get_minimum_size().x

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _link_focus() -> void:
	# Rows top to bottom, then Back; wraps around. Delete buttons sit to the
	# right of their slot. Nothing links outside the panel (see FocusUtils).
	var count: int = _slot_buttons.size()
	var order: Array[Control] = []
	for slot_index: int in count:
		var slot_button: Button = _slot_buttons[slot_index]
		var delete_button: Button = _delete_buttons[slot_index]
		var up: Control = _back_button if slot_index == 0 else _slot_buttons[slot_index - 1]
		var down: Control = _back_button if slot_index == count - 1 else _slot_buttons[slot_index + 1]
		var right: Control = delete_button if delete_button.visible else null
		FocusUtils.link(slot_button, up, down, null, right)
		FocusUtils.link(delete_button, up, down, slot_button, null)
		order.append(slot_button)
		if delete_button.visible:
			order.append(delete_button)
	FocusUtils.link(_back_button, _slot_buttons[count - 1], _slot_buttons[0], null, null)
	order.append(_back_button)
	FocusUtils.cycle_tab(order)

func _focus_first_usable() -> void:
	for button: Button in _slot_buttons:
		if not button.disabled:
			button.grab_focus()
			return
	_back_button.grab_focus()

func _save_to(slot: int) -> void:
	if SaveManager.save_game(slot):
		refresh()
		# Close first: the parent refreshes its status on closed, then adds the
		# "Saved" line on saved.
		close()
		saved.emit(slot)
	else:
		_status_label.text = SaveManager.last_error

func _load_from(slot: int) -> void:
	if SaveManager.load_game(slot):
		visible = false
		load_started.emit(slot)
	else:
		_status_label.text = SaveManager.last_error
		refresh()

func _delete(slot: int) -> void:
	if SaveManager.delete_save(slot):
		_status_label.text = "Slot %d deleted." % slot
	else:
		_status_label.text = "Could not delete slot %d." % slot
	refresh()
	get_slot_button(slot).grab_focus()
	if get_slot_button(slot).disabled:
		_focus_first_usable()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_slot_pressed(slot: int) -> void:
	if _mode == MODE_SAVE:
		if SaveManager.has_save(slot):
			_confirm.ask("Overwrite slot %d?" % slot, _save_to.bind(slot), "Overwrite")
		else:
			_save_to(slot)
		return
	if SaveManager.has_unsaved_progress():
		_confirm.ask("Load slot %d? Progress since your last save will be lost." % slot,
			_load_from.bind(slot), "Load")
	else:
		_load_from(slot)

func _on_delete_pressed(slot: int) -> void:
	_confirm.ask("Delete slot %d? This cannot be undone." % slot, _delete.bind(slot), "Delete")
