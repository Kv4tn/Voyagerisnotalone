# DialogueManager
# Runs branching conversations loaded from JSON (design.md 3.5).
# Holds no UI: DialogueBox listens to the signals and calls advance()/choose().
# Autoload singleton: res://scripts/core/dialogue_manager.gd
#
# Supported now (docs/dialogue-format.md): conditions on story flags and quest
# status, effects set_flag / start_quest / update_quest, {player_name} and
# {npc_name} in text, fallback_node for skipped nodes. Relationship conditions
# and effects arrive with RelationshipManager; the validator rejects them.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal dialogue_started(dialogue_id: String)
## line = {speaker_id, speaker_name, text, choices: Array[String], is_last: bool}
signal line_shown(line: Dictionary)
signal dialogue_choice_made(choice_index: int)
signal dialogue_ended()

# ============================================================================
# CONSTANTS
# ============================================================================

const PLAYER_SPEAKER_ID: String = "player"
const SUPPORTED_CONDITION_KEYS: PackedStringArray = ["story_flags", "quests"]
const SUPPORTED_EFFECT_TYPES: PackedStringArray = ["set_flag", "start_quest", "update_quest"]
## update_quest can only complete objectives for now.
const UPDATE_QUEST_STATUSES: PackedStringArray = ["completed"]
# Unknown keys are rejected so a typo ("next_nod") fails loudly instead of
# being ignored. "comment" is free text for writers.
const ROOT_KEYS: PackedStringArray = [
	"$schema", "version", "dialogue_id", "participants", "start_node", "nodes", "metadata", "comment"]
const NODE_KEYS: PackedStringArray = [
	"node_id", "speaker_id", "text", "conditions", "fallback_node", "effects",
	"responses", "next_node", "comment"]
const RESPONSE_KEYS: PackedStringArray = [
	"response_id", "text", "next_node", "conditions", "effects", "comment"]
const PLAYER_NAME_FALLBACK: String = "Commander"

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var is_dialogue_active: bool = false
var current_dialogue_id: String = ""

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _tree_cache: Dictionary = {}  # path -> validated tree, with "_nodes" index
var _tree: Dictionary = {}
var _npc_id: String = ""
var _node: Dictionary = {}
## Responses of the current node whose conditions passed, in display order.
var _visible_responses: Array[Dictionary] = []

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("DialogueManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func start_dialogue(dialogue_path: String, npc_id: String = "") -> bool:
	"""
	Start a conversation
	@param dialogue_path: res:// path of the dialogue JSON
	@param npc_id: NPC used for {npc_name}; may be empty
	@return: False if a dialogue is already running or the file is invalid
	"""
	if is_dialogue_active:
		push_warning("DialogueManager: dialogue already active, ignoring %s" % dialogue_path)
		return false

	var tree: Dictionary = load_tree(dialogue_path)
	if tree.is_empty():
		return false

	_tree = tree
	_npc_id = npc_id
	current_dialogue_id = tree["dialogue_id"]
	is_dialogue_active = true
	dialogue_started.emit(current_dialogue_id)
	_enter_node(tree["start_node"])
	return true

func advance() -> void:
	"""Continue past a line that has no choices. Ends the dialogue at the last line."""
	if not is_dialogue_active or not _visible_responses.is_empty():
		return
	var next_id: String = _node.get("next_node", "")
	if next_id.is_empty():
		end_dialogue()
	else:
		_enter_node(next_id)

func choose(index: int) -> void:
	"""
	Pick one of the choices from the last line_shown
	@param index: Index into that line's choices array
	"""
	if not is_dialogue_active or index < 0 or index >= _visible_responses.size():
		push_warning("DialogueManager: invalid choice %d" % index)
		return
	var response: Dictionary = _visible_responses[index]
	dialogue_choice_made.emit(index)
	_apply_effects(response.get("effects", []))
	_enter_node(response["next_node"])

func end_dialogue() -> void:
	if not is_dialogue_active:
		return
	is_dialogue_active = false
	current_dialogue_id = ""
	_tree = {}
	_node = {}
	_visible_responses.clear()
	dialogue_ended.emit()

func get_current_line() -> Dictionary:
	if not is_dialogue_active:
		return {}
	return _build_line()

func load_tree(dialogue_path: String) -> Dictionary:
	"""
	Load, validate and cache a dialogue tree
	@return: The tree, or {} when missing or invalid (errors are logged)
	"""
	if _tree_cache.has(dialogue_path):
		return _tree_cache[dialogue_path]

	var data: Variant = JsonLoader.load_file(dialogue_path)
	if data == null:
		return {}
	var errors: PackedStringArray = validate_tree(data)
	if not errors.is_empty():
		push_error("DialogueManager: %s is invalid:\n  %s" % [dialogue_path, "\n  ".join(errors)])
		return {}

	var tree: Dictionary = data
	var index: Dictionary = {}
	for node: Dictionary in tree["nodes"]:
		index[node["node_id"]] = node
	tree["_nodes"] = index
	_tree_cache[dialogue_path] = tree
	return tree

func clear_cache() -> void:
	"""Forget loaded trees so edited JSON files are read again."""
	_tree_cache.clear()

func reset() -> void:
	end_dialogue()

static func validate_tree(data: Variant) -> PackedStringArray:
	"""Check structure and references of a dialogue tree. Returns readable errors."""
	var errors: PackedStringArray = []
	if not data is Dictionary:
		errors.append("root must be an object")
		return errors
	_check_keys(data, ROOT_KEYS, "root", errors)
	if not _is_non_empty_string(data.get("dialogue_id")):
		errors.append("dialogue_id must be a non-empty string")
	if not data.get("nodes") is Array or (data["nodes"] as Array).is_empty():
		errors.append("nodes must be a non-empty array")
		return errors

	var ids: Dictionary = {}
	for i: int in (data["nodes"] as Array).size():
		var node: Variant = data["nodes"][i]
		if not node is Dictionary or not _is_non_empty_string(node.get("node_id")):
			errors.append("nodes[%d] needs a non-empty node_id" % i)
			continue
		if ids.has(node["node_id"]):
			errors.append("duplicate node_id '%s'" % node["node_id"])
		ids[node["node_id"]] = true

	if not ids.has(data.get("start_node", "")):
		errors.append("start_node '%s' is not a node_id" % str(data.get("start_node", "")))

	for node: Variant in data["nodes"]:
		if node is Dictionary and node.has("node_id"):
			_validate_node(node, ids, errors)
	return errors

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _enter_node(node_id: String) -> void:
	# Follow fallback_node while conditions fail; the hop limit stops loops.
	var nodes: Dictionary = _tree["_nodes"]
	var hops: int = 0
	var node: Dictionary = nodes.get(node_id, {})
	while not node.is_empty() and not _conditions_met(node.get("conditions", {})):
		hops += 1
		var fallback: String = node.get("fallback_node", "")
		if fallback.is_empty() or hops > nodes.size():
			node = {}
			break
		node = nodes.get(fallback, {})

	if node.is_empty():
		push_warning("DialogueManager: no reachable node from '%s', ending %s" % [node_id, current_dialogue_id])
		end_dialogue()
		return

	_node = node
	_apply_effects(node.get("effects", []))
	_visible_responses.clear()
	for response: Dictionary in node.get("responses", []):
		if _conditions_met(response.get("conditions", {})):
			_visible_responses.append(response)
	line_shown.emit(_build_line())

func _build_line() -> Dictionary:
	var speaker_id: String = _node["speaker_id"]
	var choices: Array[String] = []
	for response: Dictionary in _visible_responses:
		choices.append(_substitute(response["text"]))
	return {
		"speaker_id": speaker_id,
		"speaker_name": _speaker_name(speaker_id),
		"text": _substitute(_node["text"]),
		"choices": choices,
		"is_last": choices.is_empty() and str(_node.get("next_node", "")).is_empty(),
	}

func _speaker_name(speaker_id: String) -> String:
	if speaker_id == PLAYER_SPEAKER_ID:
		return _player_name()
	return NpcRegistry.get_display_name(speaker_id)

func _player_name() -> String:
	return GameState.player_name if not GameState.player_name.is_empty() else PLAYER_NAME_FALLBACK

func _substitute(text: String) -> String:
	var npc_name: String = NpcRegistry.get_display_name(_npc_id) if not _npc_id.is_empty() else ""
	return text.replace("{player_name}", _player_name()).replace("{npc_name}", npc_name)

func _conditions_met(conditions: Dictionary) -> bool:
	for check: Dictionary in conditions.get("story_flags", []):
		var flag: String = check["flag"]
		# A flag that was never set counts as false (no warning spam).
		var actual: Variant = StoryFlagManager.get_flag(flag) if StoryFlagManager.has_flag(flag) else false
		if actual != check["value"]:
			return false
	for check: Dictionary in conditions.get("quests", []):
		if QuestManager.get_quest_status(check["quest_id"]) != check["status"]:
			return false
	return true

func _apply_effects(effects: Array) -> void:
	for effect: Dictionary in effects:
		match effect["type"]:
			"set_flag":
				StoryFlagManager.set_flag(effect["flag"], effect["value"])
			"start_quest":
				QuestManager.start_quest(effect["quest_id"])
			"update_quest":
				QuestManager.complete_objective(effect["quest_id"], effect["objective_id"])

static func _validate_node(node: Dictionary, ids: Dictionary, errors: PackedStringArray) -> void:
	var where: String = "node '%s'" % node["node_id"]
	_check_keys(node, NODE_KEYS, where, errors)
	if not _is_non_empty_string(node.get("speaker_id")):
		errors.append(where + ": speaker_id must be a non-empty string")
	if not node.get("text") is String:
		errors.append(where + ": text must be a string")
	for key: String in ["next_node", "fallback_node"]:
		if node.has(key) and not ids.has(node[key]):
			errors.append(where + ": %s '%s' is not a node_id" % [key, str(node[key])])
	if node.has("conditions") and not node.has("fallback_node"):
		errors.append(where + ": has conditions but no fallback_node to go to when they fail")
	_validate_conditions(node.get("conditions", {}), where, errors)
	_validate_effects(node.get("effects", []), where, errors)

	var responses: Variant = node.get("responses", [])
	if not responses is Array:
		errors.append(where + ": responses must be an array")
		return
	for i: int in (responses as Array).size():
		var response: Variant = responses[i]
		var r_where: String = where + " responses[%d]" % i
		if not response is Dictionary:
			errors.append(r_where + ": must be an object")
			continue
		_check_keys(response, RESPONSE_KEYS, r_where, errors)
		if not _is_non_empty_string(response.get("text")):
			errors.append(r_where + ": text must be a non-empty string")
		if not ids.has(response.get("next_node", "")):
			errors.append(r_where + ": next_node '%s' is not a node_id" % str(response.get("next_node", "")))
		_validate_conditions(response.get("conditions", {}), r_where, errors)
		_validate_effects(response.get("effects", []), r_where, errors)
	if not (responses as Array).is_empty() and node.has("next_node"):
		errors.append(where + ": has both responses and next_node; use one")

static func _validate_conditions(conditions: Variant, where: String, errors: PackedStringArray) -> void:
	if not conditions is Dictionary:
		errors.append(where + ": conditions must be an object")
		return
	for key: Variant in conditions:
		if not key in SUPPORTED_CONDITION_KEYS:
			errors.append(where + ": condition '%s' is not supported yet" % key)
	var flags: Variant = conditions.get("story_flags", [])
	if not flags is Array:
		errors.append(where + ": story_flags must be an array")
	else:
		for check: Variant in flags:
			if not check is Dictionary or not _is_non_empty_string(check.get("flag")) or not check.has("value"):
				errors.append(where + ": each story_flags entry needs flag and value")
	var quests: Variant = conditions.get("quests", [])
	if not quests is Array:
		errors.append(where + ": quests must be an array")
		return
	for check: Variant in quests:
		if (not check is Dictionary or not _is_non_empty_string(check.get("quest_id"))
				or not check.get("status") in QuestManager.STATUSES):
			errors.append(where + ": each quests entry needs quest_id and status (%s)"
				% ", ".join(QuestManager.STATUSES))

static func _validate_effects(effects: Variant, where: String, errors: PackedStringArray) -> void:
	if not effects is Array:
		errors.append(where + ": effects must be an array")
		return
	for effect: Variant in effects:
		if not effect is Dictionary or not effect.get("type") in SUPPORTED_EFFECT_TYPES:
			var type_name: String = str(effect.get("type")) if effect is Dictionary else "?"
			errors.append(where + ": effect type '%s' is not supported yet" % type_name)
			continue
		match effect["type"]:
			"set_flag":
				if not _is_non_empty_string(effect.get("flag")) or not effect.has("value"):
					errors.append(where + ": set_flag needs flag and value")
			"start_quest":
				if not _is_non_empty_string(effect.get("quest_id")):
					errors.append(where + ": start_quest needs quest_id")
			"update_quest":
				if (not _is_non_empty_string(effect.get("quest_id"))
						or not _is_non_empty_string(effect.get("objective_id"))
						or not effect.get("status") in UPDATE_QUEST_STATUSES):
					errors.append(where + ": update_quest needs quest_id, objective_id and status \"completed\"")

static func _check_keys(object: Dictionary, allowed: PackedStringArray, where: String,
		errors: PackedStringArray) -> void:
	for key: Variant in object:
		if not key in allowed:
			errors.append(where + ": unknown field '%s'" % key)

static func _is_non_empty_string(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()
