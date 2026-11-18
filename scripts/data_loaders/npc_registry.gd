# NpcRegistry
# Loads NPC metadata from res://data/npcs/<npc_id>.json (design.md 4.3) and caches it.
# Used by NPCController (name, dialogue files) and DialogueManager (speaker names).
class_name NpcRegistry
extends RefCounted

const NPC_DIR: String = "res://data/npcs/"

static var _cache: Dictionary = {}


## Metadata dictionary for npc_id, or {} when the file is missing or invalid.
static func get_metadata(npc_id: String) -> Dictionary:
	if _cache.has(npc_id):
		return _cache[npc_id]

	var metadata: Dictionary = {}
	var path: String = NPC_DIR + npc_id + ".json"
	var data: Variant = JsonLoader.load_file(path) if FileAccess.file_exists(path) else null
	if data is Dictionary:
		var errors: PackedStringArray = validate(data, npc_id)
		if errors.is_empty():
			metadata = data
		else:
			push_error("NpcRegistry: %s is invalid:\n  %s" % [path, "\n  ".join(errors)])
	_cache[npc_id] = metadata
	return metadata


## Name shown in dialogue and prompts. Falls back to a readable form of the id.
static func get_display_name(npc_id: String) -> String:
	var metadata: Dictionary = get_metadata(npc_id)
	if metadata.is_empty():
		return npc_id.capitalize()
	return metadata["display_name"]


## Dialogue file for a story phase key such as "prologue", or "" if none.
static func get_dialogue_path(npc_id: String, key: String) -> String:
	var files: Variant = get_metadata(npc_id).get("dialogue_files", {})
	if files is Dictionary and files.has(key):
		return files[key]
	return ""


## Checks the fields the game relies on. Returns human-readable errors.
static func validate(data: Variant, expected_id: String = "") -> PackedStringArray:
	var errors: PackedStringArray = []
	if not data is Dictionary:
		errors.append("root must be an object")
		return errors
	var npc_id: Variant = data.get("npc_id")
	if not npc_id is String or (npc_id as String).is_empty():
		errors.append("npc_id must be a non-empty string")
	elif not expected_id.is_empty() and npc_id != expected_id:
		errors.append("npc_id '%s' does not match file name '%s'" % [npc_id, expected_id])
	var display_name: Variant = data.get("display_name")
	if not display_name is String or (display_name as String).is_empty():
		errors.append("display_name must be a non-empty string")
	var files: Variant = data.get("dialogue_files", {})
	if not files is Dictionary:
		errors.append("dialogue_files must be an object")
	else:
		for key: Variant in files:
			var path: Variant = files[key]
			if not path is String or not (path as String).begins_with("res://"):
				errors.append("dialogue_files.%s must be a res:// path" % key)
			elif not FileAccess.file_exists(path):
				errors.append("dialogue_files.%s points to a missing file: %s" % [key, path])
	return errors


static func clear_cache() -> void:
	_cache.clear()
