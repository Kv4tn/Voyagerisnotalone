# QuestTracker
# Lists active quests and their objectives in the HUD (top right).
# A just-completed quest stays visible with "COMPLETE" for a few seconds.
# Part of res://scenes/ui/hud.tscn. The full journal (task 4.3) comes later.
class_name QuestTracker
extends VBoxContainer

# ============================================================================
# CONSTANTS
# ============================================================================

const COMPLETED_DISPLAY_SECONDS: float = 4.0
const OPEN_MARK: String = "[ ] "
const DONE_MARK: String = "[x] "
const OPTIONAL_SUFFIX: String = " (optional)"
const COMPLETED_SUFFIX: String = "  COMPLETE"
const TITLE_COLOR: Color = Color(0.88, 0.63, 0.25, 1.0)
const OPEN_COLOR: Color = Color(0.85, 0.92, 0.95, 1.0)
const DONE_COLOR: Color = Color(0.37, 0.7, 0.77, 0.8)
const TITLE_FONT_SIZE: int = 11
const OBJECTIVE_FONT_SIZE: int = 10
## Opacity while the player stands behind the tracker, so they stay visible.
const FADED_ALPHA: float = 0.25
## Extra pixels around the tracker that count as "behind" (sprite half-size).
const OVERLAP_MARGIN: float = 12.0

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

## quest_id -> seconds the completed quest stays on screen
var _recently_completed: Dictionary = {}

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.quest_updated.connect(_on_quest_updated)
	_rebuild()

func _process(delta: float) -> void:
	modulate.a = FADED_ALPHA if _player_is_behind() else 1.0
	for quest_id: String in _recently_completed.keys():
		_recently_completed[quest_id] -= delta
		if _recently_completed[quest_id] <= 0.0:
			_recently_completed.erase(quest_id)
			_rebuild()

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func get_lines() -> PackedStringArray:
	"""Text of every visible line, top to bottom (used by tests)."""
	var lines: PackedStringArray = []
	for child: Node in get_children():
		if child is Label:
			lines.append((child as Label).text)
	return lines

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var shown: Array[String] = QuestManager.get_active_quests()
	for quest_id: String in _recently_completed:
		if not quest_id in shown:
			shown.append(quest_id)

	for quest_id: String in shown:
		var view: Dictionary = QuestManager.get_quest_view(quest_id)
		if view.is_empty():
			continue
		var completed: bool = view["status"] == QuestManager.STATUS_COMPLETED
		_add_line(view["title"] + (COMPLETED_SUFFIX if completed else ""), TITLE_COLOR, TITLE_FONT_SIZE)
		if completed:
			continue
		for objective: Dictionary in view["objectives"]:
			var text: String = (DONE_MARK if objective["done"] else OPEN_MARK) + objective["description"]
			if objective["optional"]:
				text += OPTIONAL_SUFFIX
			_add_line(text, DONE_COLOR if objective["done"] else OPEN_COLOR, OBJECTIVE_FONT_SIZE)
	visible = get_child_count() > 0

func _player_is_behind() -> bool:
	if not visible:
		return false
	var player: Node2D = get_tree().get_first_node_in_group(PlayerController.GROUP) as Node2D
	if player == null:
		return false
	# Both rects are in screen pixels: the HUD layer has no transform and the
	# player's canvas transform includes any camera.
	var screen_position: Vector2 = player.get_global_transform_with_canvas().origin
	return _content_rect().grow(OVERLAP_MARGIN).has_point(screen_position)

func _content_rect() -> Rect2:
	# The container is taller than its text; only the lines should fade.
	var rect: Rect2 = Rect2()
	for child: Node in get_children():
		if child is Control:
			var child_rect: Rect2 = (child as Control).get_global_rect()
			rect = child_rect if rect.size == Vector2.ZERO else rect.merge(child_rect)
	return rect

func _add_line(text: String, color: Color, font_size: int) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_quest_completed(quest_id: String) -> void:
	_recently_completed[quest_id] = COMPLETED_DISPLAY_SECONDS

func _on_quest_updated(_quest_id: String) -> void:
	_rebuild()
