# RelationshipToast
# Short HUD notices (top center) for trust/bond changes, e.g. "Elias Voss: Trust +5" (REQ-24.1-2).
# Each change gets its own line that disappears after a few seconds.
# Part of res://scenes/ui/hud.tscn.
class_name RelationshipToast
extends VBoxContainer

# ============================================================================
# CONSTANTS
# ============================================================================

const DISPLAY_SECONDS: float = 3.0
const FADE_SECONDS: float = 0.5
const MAX_LINES: int = 4
const UP_COLOR: Color = Color(0.37, 0.7, 0.77, 1.0)
const DOWN_COLOR: Color = Color(0.85, 0.36, 0.33, 1.0)
const FONT_SIZE: int = 10

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

## Label -> seconds left on screen
var _remaining: Dictionary = {}

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	RelationshipManager.relationship_changed.connect(_on_relationship_changed)

func _process(delta: float) -> void:
	for label: Label in _remaining.keys():
		_remaining[label] -= delta
		var left: float = _remaining[label]
		if left <= 0.0:
			_remove(label)
		elif left < FADE_SECONDS:
			label.modulate.a = left / FADE_SECONDS

# ============================================================================
# PUBLIC METHODS
# ============================================================================

static func format_change(npc_id: String, relationship_type: String, amount: int) -> String:
	"""Text of one notice, e.g. "Elias Voss: Trust +5"."""
	return "%s: %s %+d" % [NpcRegistry.get_display_name(npc_id), relationship_type.capitalize(), amount]

func get_lines() -> PackedStringArray:
	"""Text of every notice on screen, oldest first (used by tests)."""
	var lines: PackedStringArray = []
	for child: Node in get_children():
		if child is Label and not child.is_queued_for_deletion():
			lines.append((child as Label).text)
	return lines

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _remove(label: Label) -> void:
	_remaining.erase(label)
	remove_child(label)
	label.queue_free()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_relationship_changed(npc_id: String, relationship_type: String,
		old_value: int, new_value: int) -> void:
	var amount: int = new_value - old_value
	var label: Label = Label.new()
	label.text = format_change(npc_id, relationship_type, amount)
	label.add_theme_color_override("font_color", UP_COLOR if amount > 0 else DOWN_COLOR)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_remaining[label] = DISPLAY_SECONDS
	while get_child_count() > MAX_LINES:
		_remove(get_child(0) as Label)
