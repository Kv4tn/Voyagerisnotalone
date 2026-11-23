# SaveManager
# Saves and loads the game to JSON files in user://saves/slot_<n>.json
# (REQ-50..52, design.md 3.12).
#
# A save holds: commander name, chapter, playtime, scene and player position,
# all story flags, quest progress and crew relationships. Every file is fully
# validated before anything is restored, so a broken file never leaves the
# game half-loaded. Writes go to a temporary file first and are then renamed,
# so a crash while saving cannot destroy the previous save.
# Autoload singleton: res://scripts/core/save_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal game_saved(slot: int)
## Emitted after the saved scene is loaded and the player is placed.
signal game_loaded(slot: int)

# ============================================================================
# CONSTANTS
# ============================================================================

## Save format version. Bump it when the format changes and add a step to
## _migrate() so older saves keep loading.
const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"
const MAX_SAVE_SLOTS: int = 3
const ROOT_KEYS: PackedStringArray = [
	"version", "timestamp", "saved_unix", "playtime_seconds", "player_data", "story_data",
	"quest_data", "relationship_data"]
const PLAYER_KEYS: PackedStringArray = ["name", "chapter", "current_scene", "position"]

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

## Folder save files go to. Tests point it at an isolated folder.
var save_dir: String = SAVE_DIR
## Player-facing reason the last save_game()/load_game() failed, "" on success.
var last_error: String = ""

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _pending_position: Vector2 = Vector2.ZERO
var _pending_slot: int = 0
## Progress fingerprint at the last save, load or new game ("" = none yet).
var _clean_fingerprint: String = ""

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	ensure_save_directory()
	GameState.new_game_started.connect(mark_progress_saved)
	print("SaveManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func slot_path(slot: int) -> String:
	return save_dir + "slot_%d.json" % slot

func has_save(slot: int) -> bool:
	return is_valid_slot(slot) and FileAccess.file_exists(slot_path(slot))

func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SAVE_SLOTS

func get_save_blocker() -> String:
	"""Why the game cannot be saved right now, or "" when it can."""
	if not GameState.game_started:
		return "Start a game first."
	if SceneManager.is_transitioning:
		return "Wait for the scene to finish loading."
	if DialogueManager.is_dialogue_active:
		return "Finish the conversation first."
	if _find_player() == null:
		return "There is nothing to save here."
	return ""

func save_game(slot: int) -> bool:
	"""
	Save the running game to a slot (1..MAX_SAVE_SLOTS), overwriting it
	@return: True on success; otherwise last_error explains why
	"""
	last_error = ""
	if not is_valid_slot(slot):
		return _fail("Save slot %d does not exist." % slot)
	var blocker: String = get_save_blocker()
	if not blocker.is_empty():
		return _fail(blocker)

	var scene: Node = get_tree().current_scene
	var data: Dictionary = build_save_data(scene.scene_file_path, _find_player().global_position)
	if not ensure_save_directory():
		return _fail("Could not create the save folder.")

	var path: String = slot_path(slot)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _fail("Could not write the save file (%s)." % error_string(FileAccess.get_open_error()))
	file.store_string(to_json(data))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _fail("Could not write the save file (%s)." % error_string(write_error))
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _fail("Could not replace the old save (%s)." % error_string(rename_error))

	print("SaveManager: saved slot %d to %s" % [slot, ProjectSettings.globalize_path(path)])
	mark_progress_saved()
	game_saved.emit(slot)
	return true

func load_game(slot: int) -> bool:
	"""
	Load a slot: validate it, restore every system, then load the saved scene
	and put the player where they were. game_loaded fires when done.
	@return: True when loading started; otherwise last_error explains why and
		the current game is unchanged
	"""
	last_error = ""
	if not is_valid_slot(slot):
		return _fail("Save slot %d does not exist." % slot)
	if not has_save(slot):
		return _fail("Slot %d is empty." % slot)
	if SceneManager.is_transitioning:
		return _fail("Wait for the scene to finish loading.")

	var result: Dictionary = parse_save_text(FileAccess.get_file_as_string(slot_path(slot)))
	if not result["errors"].is_empty():
		push_error("SaveManager: slot %d is not loadable:\n  %s" % [slot, "\n  ".join(result["errors"])])
		return _fail("The save in slot %d is damaged or incompatible: %s" % [slot, result["errors"][0]])

	var data: Dictionary = result["data"]
	restore_state(data)
	mark_progress_saved()
	var player_data: Dictionary = data["player_data"]
	_pending_position = Vector2(player_data["position"]["x"], player_data["position"]["y"])
	_pending_slot = slot
	if not SceneManager.scene_loaded.is_connected(_on_scene_loaded):
		SceneManager.scene_loaded.connect(_on_scene_loaded, CONNECT_ONE_SHOT)
	SceneManager.transition_to(player_data["current_scene"])
	print("SaveManager: loading slot %d" % slot)
	return true

func delete_save(slot: int) -> bool:
	if not has_save(slot):
		return false
	return DirAccess.remove_absolute(slot_path(slot)) == OK

func get_slot_info(slot: int) -> Dictionary:
	"""
	Metadata for a save slot screen (REQ-50.6)
	@return: {exists, valid, error, player_name, chapter, playtime_seconds,
		timestamp, scene}. Only exists/valid/error are set for empty or bad slots.
	"""
	var info: Dictionary = {"exists": has_save(slot), "valid": false, "error": ""}
	if not info["exists"]:
		return info
	var result: Dictionary = parse_save_text(FileAccess.get_file_as_string(slot_path(slot)))
	if not result["errors"].is_empty():
		info["error"] = result["errors"][0]
		return info
	var data: Dictionary = result["data"]
	info["valid"] = true
	info["player_name"] = data["player_data"]["name"]
	info["chapter"] = data["player_data"]["chapter"]
	info["playtime_seconds"] = data["playtime_seconds"]
	info["timestamp"] = data["timestamp"]
	info["saved_unix"] = data["saved_unix"]
	info["scene"] = data["player_data"]["current_scene"]
	return info

func get_latest_slot() -> int:
	"""Slot with the most recent valid save, or 0 if there is none (for Continue)."""
	var latest: int = 0
	var latest_time: float = -1.0
	for slot: int in range(1, MAX_SAVE_SLOTS + 1):
		var info: Dictionary = get_slot_info(slot)
		if info["valid"] and float(info["saved_unix"]) > latest_time:
			latest = slot
			latest_time = float(info["saved_unix"])
	return latest

func has_any_save() -> bool:
	for slot: int in range(1, MAX_SAVE_SLOTS + 1):
		if has_save(slot):
			return true
	return false

func has_unsaved_progress() -> bool:
	"""
	True when story flags, quests, relationships, name or chapter changed since
	the last save, load or new game. Walking around and playtime do not count.
	"""
	if not GameState.game_started:
		return false
	return _progress_fingerprint() != _clean_fingerprint

func mark_progress_saved() -> void:
	"""Treat the current progress as saved (after saving, loading, a new game)."""
	_clean_fingerprint = _progress_fingerprint()

func build_save_data(scene_path: String, player_position: Vector2) -> Dictionary:
	"""Collect the whole game state into the save format (no file access)."""
	return {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"saved_unix": Time.get_unix_time_from_system(),
		"playtime_seconds": GameState.game_time,
		"player_data": {
			"name": GameState.player_name,
			"chapter": GameState.current_chapter,
			"current_scene": scene_path,
			"position": {"x": player_position.x, "y": player_position.y},
		},
		"story_data": {"flags": StoryFlagManager.get_save_data()},
		"quest_data": {"quests": QuestManager.get_save_data()},
		"relationship_data": RelationshipManager.get_save_data(),
	}

static func to_json(data: Dictionary) -> String:
	"""Human-readable save text (REQ-52.4): tab-indented, sorted keys, exact numbers."""
	return JSON.stringify(data, "\t", true, true) + "\n"

func parse_save_text(text: String) -> Dictionary:
	"""
	Parse and fully validate save text (REQ-51.3-5, REQ-52.6-7)
	@return: {"data": Dictionary, "errors": PackedStringArray}; data is only
		usable when errors is empty
	"""
	var errors: PackedStringArray = []
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append("not valid JSON (line %d: %s)" % [json.get_error_line() + 1, json.get_error_message()])
		return {"data": {}, "errors": errors}
	if not json.data is Dictionary:
		errors.append("the file must contain a JSON object")
		return {"data": {}, "errors": errors}
	var data: Dictionary = json.data

	# Version first: a newer format may look broken to this validator.
	var version: Variant = data.get("version")
	if not RelationshipManager.is_whole_number(version) or version < 1:
		errors.append("missing or invalid version")
		return {"data": {}, "errors": errors}
	if int(version) > SAVE_VERSION:
		errors.append("saved by a newer version of the game (save format %d, this build reads up to %d)"
			% [int(version), SAVE_VERSION])
		return {"data": {}, "errors": errors}
	data = _migrate(data, int(version))

	_validate(data, errors)
	return {"data": data if errors.is_empty() else {}, "errors": errors}

func restore_state(data: Dictionary) -> void:
	"""Apply validated save data to every system. Does not change the scene."""
	DialogueManager.reset()
	var player_data: Dictionary = data["player_data"]
	StoryFlagManager.load_save_data(data["story_data"]["flags"])
	RelationshipManager.load_save_data(data["relationship_data"])
	QuestManager.load_save_data(data["quest_data"]["quests"])
	GameState.restore_from_save(player_data["name"], int(player_data["chapter"]), float(data["playtime_seconds"]))

static func format_playtime(seconds: float) -> String:
	"""Playtime as H:MM:SS, e.g. 0:05:12."""
	var total: int = int(seconds)
	@warning_ignore("integer_division")
	var hours: int = total / 3600
	@warning_ignore("integer_division")
	var minutes: int = (total % 3600) / 60
	return "%d:%02d:%02d" % [hours, minutes, total % 60]

static func describe_slot(info: Dictionary) -> String:
	"""One line for a valid slot, e.g. "CMDR ASEL · Chapter 1 · 0:05:12 played"."""
	return "CMDR %s · Chapter %d · %s played" % [
		str(info["player_name"]).to_upper(), int(info["chapter"]), format_playtime(info["playtime_seconds"])]

func ensure_save_directory() -> bool:
	if DirAccess.dir_exists_absolute(save_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(save_dir) == OK

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _validate(data: Dictionary, errors: PackedStringArray) -> void:
	for key: Variant in data:
		if not ROOT_KEYS.has(str(key)):
			errors.append("unknown field '%s'" % str(key))
	for key: String in ROOT_KEYS:
		if not data.has(key):
			errors.append("missing field '%s'" % key)
	if not errors.is_empty():
		return

	if not data["timestamp"] is String:
		errors.append("timestamp must be text")
	var saved_unix: Variant = data["saved_unix"]
	if not (saved_unix is float or saved_unix is int) or not is_finite(saved_unix) or saved_unix < 0:
		errors.append("saved_unix must be a number of seconds, 0 or more")
	var playtime: Variant = data["playtime_seconds"]
	if not (playtime is float or playtime is int) or not is_finite(playtime) or playtime < 0:
		errors.append("playtime_seconds must be a number of seconds, 0 or more")

	_validate_player(data["player_data"], errors)

	var story: Variant = data["story_data"]
	if not story is Dictionary or not story.has("flags") or story.size() != 1:
		errors.append("story_data must be an object with only 'flags'")
	else:
		errors.append_array(StoryFlagManager.validate_save_data(story["flags"]))

	var quests: Variant = data["quest_data"]
	if not quests is Dictionary or not quests.has("quests") or quests.size() != 1:
		errors.append("quest_data must be an object with only 'quests'")
	else:
		errors.append_array(QuestManager.validate_save_data(quests["quests"]))

	errors.append_array(RelationshipManager.validate_save_data(data["relationship_data"]))

func _validate_player(player: Variant, errors: PackedStringArray) -> void:
	if not player is Dictionary:
		errors.append("player_data must be an object")
		return
	for key: Variant in player:
		if not PLAYER_KEYS.has(str(key)):
			errors.append("player_data: unknown field '%s'" % str(key))
	var player_name: Variant = player.get("name")
	if not player_name is String:
		errors.append("player_data.name must be text")
	else:
		var name_error: String = GameState.get_player_name_error(player_name)
		if not name_error.is_empty():
			errors.append("player_data.name: " + name_error)
	var chapter: Variant = player.get("chapter")
	if (not RelationshipManager.is_whole_number(chapter) or chapter < 1
			or chapter > GameState.TOTAL_CHAPTERS):
		errors.append("player_data.chapter must be a whole number from 1 to %d" % GameState.TOTAL_CHAPTERS)
	var scene_path: Variant = player.get("current_scene")
	if not scene_path is String or not (scene_path as String).begins_with("res://") \
			or not (scene_path as String).ends_with(".tscn"):
		errors.append("player_data.current_scene must be a res:// .tscn path")
	elif not ResourceLoader.exists(scene_path):
		errors.append("player_data.current_scene does not exist: %s" % scene_path)
	var position: Variant = player.get("position")
	if not position is Dictionary or position.size() != 2:
		errors.append("player_data.position must be {x, y}")
		return
	for axis: String in ["x", "y"]:
		var value: Variant = position.get(axis)
		if not (value is float or value is int) or not is_finite(value):
			errors.append("player_data.position.%s must be a number" % axis)

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Version 1 is the first format. A future change adds a step here, e.g.
	#   if from_version < 2: data["new_field"] = default; from_version = 2
	assert(from_version <= SAVE_VERSION)
	return data

func _progress_fingerprint() -> String:
	var data: Dictionary = build_save_data("", Vector2.ZERO)
	for key: String in ["timestamp", "saved_unix", "playtime_seconds"]:
		data.erase(key)
	data["player_data"].erase("position")
	data["player_data"].erase("current_scene")
	return JSON.stringify(data, "", true, true)

func _find_player() -> Node2D:
	return SceneManager.get_player()

func _fail(message: String) -> bool:
	last_error = message
	push_warning("SaveManager: " + message)
	return false

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_scene_loaded(_scene: Node) -> void:
	var player: Node2D = _find_player()
	if player == null:
		push_warning("SaveManager: loaded scene has no player to place")
	else:
		player.global_position = _pending_position
	game_loaded.emit(_pending_slot)
