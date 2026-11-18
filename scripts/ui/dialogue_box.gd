# DialogueBox
# Shows DialogueManager lines with a typewriter effect and choice buttons.
# Part of res://scenes/ui/hud.tscn, so every room with a HUD can show dialogue.
# Controls: E / Enter continue or pick the focused choice, arrows move between
# choices, E while text is typing shows the whole line at once.
class_name DialogueBox
extends PanelContainer

# ============================================================================
# CONSTANTS
# ============================================================================

const CHARACTERS_PER_SECOND: float = 50.0
const HINT_CONTINUE: String = "[E] Continue"
const HINT_END: String = "[E] Close"
const HINT_CHOOSE: String = "Arrows: select    [E] Choose"

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _line: Dictionary = {}
var _typing: bool = false
var _visible_chars: float = 0.0

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %TextLabel
@onready var _choices: VBoxContainer = %Choices
@onready var _hint_label: Label = %HintLabel

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	visible = false
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if DialogueManager.is_dialogue_active:
		_on_line_shown(DialogueManager.get_current_line())

func _process(delta: float) -> void:
	if not _typing:
		return
	_visible_chars += CHARACTERS_PER_SECOND * delta
	_text_label.visible_characters = int(_visible_chars)
	if _text_label.visible_characters >= _text_label.get_total_character_count():
		_finish_typing()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()

	if _typing:
		_finish_typing()
		return
	if _line["choices"].is_empty():
		DialogueManager.advance()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and focused.get_parent() == _choices:
		(focused as Button).pressed.emit()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func is_typing() -> bool:
	return _typing

func get_choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _choices.get_children():
		if child is Button and not child.is_queued_for_deletion():
			buttons.append(child)
	return buttons

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_choices.visible = not _line["choices"].is_empty()
	var buttons: Array[Button] = get_choice_buttons()
	if not buttons.is_empty():
		buttons[0].grab_focus()
		_hint_label.text = HINT_CHOOSE
	else:
		_hint_label.text = HINT_END if _line["is_last"] else HINT_CONTINUE
	_hint_label.visible = true

func _rebuild_choices(choices: Array) -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	for i: int in choices.size():
		var button: Button = Button.new()
		button.text = "%d. %s" % [i + 1, choices[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(DialogueManager.choose.bind(i))
		_choices.add_child(button)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_line_shown(line: Dictionary) -> void:
	_line = line
	visible = true
	_speaker_label.text = line["speaker_name"]
	_text_label.text = line["text"]
	_text_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	_hint_label.visible = false
	_choices.visible = false
	_rebuild_choices(line["choices"])

func _on_dialogue_ended() -> void:
	_typing = false
	_line = {}
	visible = false
	for child: Node in _choices.get_children():
		child.queue_free()
