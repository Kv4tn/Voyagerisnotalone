# QuestManager
# Tracks quests defined in res://data/quests/<quest_id>.json (design.md 3.6).
# Definitions (from JSON) are kept apart from runtime state, so saving later
# only needs the state: {quest_id: {status, objectives: {objective_id: done}}}.
# Autoload singleton: res://scripts/core/quest_manager.gd
#
# Supported now (docs/quest-format.md):
#   objective types: story_flag (completes itself when a flag has a value),
#                    talk_to (completed by the dialogue effect update_quest)
#   prerequisites:   story_flags, quests_completed, relationships (trust/bond min/max)
#   rewards:         story_flags, relationships (trust/bond changes)
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal quest_started(quest_id: String)
## Any change visible in a journal: objective completed, quest started/ended.
signal quest_updated(quest_id: String)
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# ============================================================================
# CONSTANTS
# ============================================================================

const QUEST_DIR: String = "res://data/quests/"

const STATUS_NOT_STARTED: String = "not_started"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_FAILED: String = "failed"
const STATUSES: PackedStringArray = [
	STATUS_NOT_STARTED, STATUS_ACTIVE, STATUS_COMPLETED, STATUS_FAILED]

const OBJECTIVE_STORY_FLAG: String = "story_flag"
const OBJECTIVE_TALK_TO: String = "talk_to"
const OBJECTIVE_TYPES: PackedStringArray = [OBJECTIVE_STORY_FLAG, OBJECTIVE_TALK_TO]
const CATEGORIES: PackedStringArray = ["main", "side", "crew", "tutorial"]

const ROOT_KEYS: PackedStringArray = [
	"$schema", "version", "quest_id", "title", "description", "category", "chapter",
	"prerequisites", "objectives", "rewards", "comment"]
const OBJECTIVE_KEYS: PackedStringArray = [
	"objective_id", "description", "type", "target", "flag", "value", "optional", "comment"]
const PREREQUISITE_KEYS: PackedStringArray = ["story_flags", "quests_completed", "relationships"]
const REWARD_KEYS: PackedStringArray = ["story_flags", "relationships"]
## A quest that is not_started is simply absent from a save file.
const SAVABLE_STATUSES: PackedStringArray = [STATUS_ACTIVE, STATUS_COMPLETED, STATUS_FAILED]
const SAVE_ENTRY_KEYS: PackedStringArray = ["quest_id", "status", "objectives_done"]

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

## Folder quest files are read from. Tests point it at fixtures.
var quest_dir: String = QUEST_DIR

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _definitions: Dictionary = {}  # quest_id -> validated definition, {} if invalid
var _states: Dictionary = {}       # quest_id -> {status, objectives: {objective_id: bool}}
## Quest ids in the order they were started, for stable UI ordering.
var _start_order: Array[String] = []

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	StoryFlagManager.story_flag_set.connect(_on_story_flag_set)
	print("QuestManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func start_quest(quest_id: String) -> bool:
	"""
	Start a quest if it exists, has not been started and its prerequisites hold
	@return: True when the quest became active
	"""
	var definition: Dictionary = get_definition(quest_id)
	if definition.is_empty():
		return false
	if get_quest_status(quest_id) != STATUS_NOT_STARTED:
		push_warning("QuestManager: '%s' is already %s" % [quest_id, get_quest_status(quest_id)])
		return false
	if not prerequisites_met(quest_id):
		push_warning("QuestManager: prerequisites of '%s' are not met" % quest_id)
		return false

	var objectives: Dictionary = {}
	for objective: Dictionary in definition["objectives"]:
		objectives[objective["objective_id"]] = false
	_states[quest_id] = {"status": STATUS_ACTIVE, "objectives": objectives}
	_start_order.append(quest_id)
	print("QuestManager: started '%s'" % quest_id)
	quest_started.emit(quest_id)
	quest_updated.emit(quest_id)

	# A flag objective whose flag is already set counts as done right away.
	for objective: Dictionary in definition["objectives"]:
		if objective["type"] == OBJECTIVE_STORY_FLAG and _flag_matches(objective):
			_mark_objective(quest_id, objective["objective_id"])
	return true

func complete_objective(quest_id: String, objective_id: String) -> bool:
	"""
	Mark an objective of an active quest done; completes the quest when all
	required objectives are done
	@return: True when the objective changed from open to done
	"""
	if get_quest_status(quest_id) != STATUS_ACTIVE:
		push_warning("QuestManager: cannot update '%s', it is %s" % [quest_id, get_quest_status(quest_id)])
		return false
	var objectives: Dictionary = _states[quest_id]["objectives"]
	if not objectives.has(objective_id):
		push_warning("QuestManager: '%s' has no objective '%s'" % [quest_id, objective_id])
		return false
	if objectives[objective_id]:
		return false
	_mark_objective(quest_id, objective_id)
	return true

func fail_quest(quest_id: String) -> bool:
	"""Mark an active quest failed. Rewards are not given."""
	if get_quest_status(quest_id) != STATUS_ACTIVE:
		push_warning("QuestManager: cannot fail '%s', it is %s" % [quest_id, get_quest_status(quest_id)])
		return false
	_states[quest_id]["status"] = STATUS_FAILED
	print("QuestManager: failed '%s'" % quest_id)
	quest_failed.emit(quest_id)
	quest_updated.emit(quest_id)
	return true

func get_quest_status(quest_id: String) -> String:
	if not _states.has(quest_id):
		return STATUS_NOT_STARTED
	return _states[quest_id]["status"]

func is_objective_done(quest_id: String, objective_id: String) -> bool:
	if not _states.has(quest_id):
		return false
	return _states[quest_id]["objectives"].get(objective_id, false)

func get_quest_ids(status: String) -> Array[String]:
	"""Quest ids with the given status, in the order they were started."""
	var ids: Array[String] = []
	for quest_id: String in _start_order:
		if get_quest_status(quest_id) == status:
			ids.append(quest_id)
	return ids

func get_active_quests() -> Array[String]:
	return get_quest_ids(STATUS_ACTIVE)

func get_quest_view(quest_id: String) -> Dictionary:
	"""
	Everything a journal or tracker needs to show one quest
	@return: {quest_id, title, description, status, objectives: [{objective_id,
		description, done, optional}]}, or {} for an unknown quest
	"""
	var definition: Dictionary = get_definition(quest_id)
	if definition.is_empty():
		return {}
	var objectives: Array[Dictionary] = []
	for objective: Dictionary in definition["objectives"]:
		objectives.append({
			"objective_id": objective["objective_id"],
			"description": objective["description"],
			"done": is_objective_done(quest_id, objective["objective_id"]),
			"optional": objective.get("optional", false),
		})
	return {
		"quest_id": quest_id,
		"title": definition["title"],
		"description": definition.get("description", ""),
		"status": get_quest_status(quest_id),
		"objectives": objectives,
	}

func prerequisites_met(quest_id: String) -> bool:
	var prerequisites: Dictionary = get_definition(quest_id).get("prerequisites", {})
	for flag_check: Dictionary in prerequisites.get("story_flags", []):
		if not _flag_matches(flag_check):
			return false
	for required: String in prerequisites.get("quests_completed", []):
		if get_quest_status(required) != STATUS_COMPLETED:
			return false
	for relationship_check: Dictionary in prerequisites.get("relationships", []):
		if not RelationshipManager.check_met(relationship_check):
			return false
	return true

func get_definition(quest_id: String) -> Dictionary:
	"""
	Load, validate and cache a quest definition
	@return: The definition, or {} when missing or invalid (errors are logged)
	"""
	if _definitions.has(quest_id):
		return _definitions[quest_id]

	var definition: Dictionary = {}
	var path: String = quest_dir + quest_id + ".json"
	var data: Variant = JsonLoader.load_file(path)
	if data != null:
		var errors: PackedStringArray = validate_quest(data, quest_id)
		if errors.is_empty():
			definition = data
		else:
			push_error("QuestManager: %s is invalid:\n  %s" % [path, "\n  ".join(errors)])
	_definitions[quest_id] = definition
	return definition

func has_quest(quest_id: String) -> bool:
	return FileAccess.file_exists(quest_dir + quest_id + ".json")

func clear_cache() -> void:
	"""Forget loaded definitions so edited JSON files are read again."""
	_definitions.clear()

func get_save_data() -> Array:
	"""
	Quest progress for the save file, in start order:
	[{quest_id, status, objectives_done: [objective ids]}]
	"""
	var result: Array = []
	for quest_id: String in _start_order:
		var done: Array = []
		for objective: Dictionary in get_definition(quest_id)["objectives"]:
			if is_objective_done(quest_id, objective["objective_id"]):
				done.append(objective["objective_id"])
		result.append({"quest_id": quest_id, "status": get_quest_status(quest_id), "objectives_done": done})
	return result

func validate_save_data(data: Variant) -> PackedStringArray:
	"""Check the quest_data section of a save file against the quest definitions."""
	var errors: PackedStringArray = []
	if not data is Array:
		errors.append("quest_data must be an array")
		return errors
	var seen: Dictionary = {}
	for i: int in (data as Array).size():
		var entry: Variant = data[i]
		var where: String = "quest_data[%d]" % i
		if not entry is Dictionary:
			errors.append(where + " must be an object")
			continue
		_check_keys(entry, SAVE_ENTRY_KEYS, where, errors)
		var quest_id: Variant = entry.get("quest_id")
		if not _is_non_empty_string(quest_id):
			errors.append(where + ": quest_id must be a non-empty string")
			continue
		where = "quest_data '%s'" % quest_id
		if seen.has(quest_id):
			errors.append(where + ": listed twice")
		seen[quest_id] = true
		if not has_quest(quest_id):
			errors.append(where + ": no such quest in %s" % quest_dir)
			continue
		var definition: Dictionary = get_definition(quest_id)
		if definition.is_empty():
			errors.append(where + ": the quest file is invalid")
			continue
		if not _is_one_of(entry.get("status"), SAVABLE_STATUSES):
			errors.append(where + ": status must be active, completed or failed")
		var done: Variant = entry.get("objectives_done")
		if not done is Array:
			errors.append(where + ": objectives_done must be an array")
			continue
		var objective_ids: PackedStringArray = []
		for objective: Dictionary in definition["objectives"]:
			objective_ids.append(objective["objective_id"])
		for objective_id: Variant in done:
			if not _is_one_of(objective_id, objective_ids):
				errors.append(where + ": unknown objective '%s'" % str(objective_id))
	return errors

func load_save_data(data: Array) -> void:
	"""
	Restore quest progress from a validated save. Emits no signals and gives
	no rewards: rewards were already applied when the quest was completed,
	and their effects are in the saved flags and relationships.
	"""
	reset()
	for entry: Dictionary in data:
		var quest_id: String = entry["quest_id"]
		var objectives: Dictionary = {}
		for objective: Dictionary in get_definition(quest_id)["objectives"]:
			objectives[objective["objective_id"]] = objective["objective_id"] in entry["objectives_done"]
		_states[quest_id] = {"status": entry["status"], "objectives": objectives}
		_start_order.append(quest_id)

func reset() -> void:
	"""Forget all quest progress (new game)."""
	_states.clear()
	_start_order.clear()

static func validate_quest(data: Variant, expected_id: String = "") -> PackedStringArray:
	"""Check the structure of a quest definition. Returns readable errors."""
	var errors: PackedStringArray = []
	if not data is Dictionary:
		errors.append("root must be an object")
		return errors
	_check_keys(data, ROOT_KEYS, "root", errors)

	var quest_id: Variant = data.get("quest_id")
	if not _is_non_empty_string(quest_id):
		errors.append("quest_id must be a non-empty string")
	elif not expected_id.is_empty() and quest_id != expected_id:
		errors.append("quest_id '%s' does not match file name '%s'" % [quest_id, expected_id])
	if not _is_non_empty_string(data.get("title")):
		errors.append("title must be a non-empty string")
	if data.has("description") and not data["description"] is String:
		errors.append("description must be a string")
	if data.has("category") and not _is_one_of(data["category"], CATEGORIES):
		errors.append("category must be one of %s" % ", ".join(CATEGORIES))

	_validate_prerequisites(data.get("prerequisites", {}), errors)
	_validate_objectives(data.get("objectives"), errors)
	_validate_rewards(data.get("rewards", {}), errors)
	return errors

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _mark_objective(quest_id: String, objective_id: String) -> void:
	_states[quest_id]["objectives"][objective_id] = true
	print("QuestManager: '%s' objective '%s' done" % [quest_id, objective_id])
	objective_completed.emit(quest_id, objective_id)
	quest_updated.emit(quest_id)
	if _all_required_done(quest_id):
		_complete_quest(quest_id)

func _all_required_done(quest_id: String) -> bool:
	var done: Dictionary = _states[quest_id]["objectives"]
	for objective: Dictionary in get_definition(quest_id)["objectives"]:
		if not objective.get("optional", false) and not done[objective["objective_id"]]:
			return false
	return true

func _complete_quest(quest_id: String) -> void:
	_states[quest_id]["status"] = STATUS_COMPLETED
	print("QuestManager: completed '%s'" % quest_id)
	# Status changes before rewards, so reward flags that start follow-up
	# quests already see this quest as completed.
	var rewards: Dictionary = get_definition(quest_id).get("rewards", {})
	for reward: Dictionary in rewards.get("story_flags", []):
		StoryFlagManager.set_flag(reward["flag"], reward["value"])
	for reward: Dictionary in rewards.get("relationships", []):
		RelationshipManager.apply_change(reward)
	quest_completed.emit(quest_id)
	quest_updated.emit(quest_id)

func _flag_matches(flag_check: Dictionary) -> bool:
	var flag: String = flag_check["flag"]
	var actual: Variant = StoryFlagManager.get_flag(flag) if StoryFlagManager.has_flag(flag) else false
	return actual == flag_check["value"]

static func _validate_prerequisites(prerequisites: Variant, errors: PackedStringArray) -> void:
	if not prerequisites is Dictionary:
		errors.append("prerequisites must be an object")
		return
	for key: Variant in prerequisites:
		if not _is_one_of(key, PREREQUISITE_KEYS):
			errors.append("prerequisites: '%s' is not supported yet" % key)
	_validate_flag_list(prerequisites.get("story_flags", []), "prerequisites.story_flags", errors)
	var required: Variant = prerequisites.get("quests_completed", [])
	if not required is Array:
		errors.append("prerequisites.quests_completed must be an array of quest ids")
		return
	for entry: Variant in required:
		if not _is_non_empty_string(entry):
			errors.append("prerequisites.quests_completed must contain quest id strings")
	_validate_list(prerequisites.get("relationships", []), "prerequisites.relationships",
		RelationshipManager.validate_check, errors)

static func _validate_objectives(objectives: Variant, errors: PackedStringArray) -> void:
	if not objectives is Array or (objectives as Array).is_empty():
		errors.append("objectives must be a non-empty array")
		return
	var ids: Dictionary = {}
	var required_count: int = 0
	for i: int in (objectives as Array).size():
		var objective: Variant = objectives[i]
		var where: String = "objectives[%d]" % i
		if not objective is Dictionary:
			errors.append(where + ": must be an object")
			continue
		_check_keys(objective, OBJECTIVE_KEYS, where, errors)
		var objective_id: Variant = objective.get("objective_id")
		if not _is_non_empty_string(objective_id):
			errors.append(where + ": objective_id must be a non-empty string")
		elif ids.has(objective_id):
			errors.append(where + ": duplicate objective_id '%s'" % objective_id)
		else:
			ids[objective_id] = true
		if not _is_non_empty_string(objective.get("description")):
			errors.append(where + ": description must be a non-empty string")
		if objective.has("optional") and not objective["optional"] is bool:
			errors.append(where + ": optional must be true or false")
		if not objective.get("optional", false):
			required_count += 1

		match objective.get("type"):
			OBJECTIVE_STORY_FLAG:
				if not _is_non_empty_string(objective.get("flag")) or not objective.has("value"):
					errors.append(where + ": story_flag objectives need flag and value")
			OBJECTIVE_TALK_TO:
				if not _is_non_empty_string(objective.get("target")):
					errors.append(where + ": talk_to objectives need target (an npc_id)")
			_:
				errors.append(where + ": type must be one of %s" % ", ".join(OBJECTIVE_TYPES))
	if required_count == 0:
		errors.append("objectives: at least one objective must not be optional")

static func _validate_rewards(rewards: Variant, errors: PackedStringArray) -> void:
	if not rewards is Dictionary:
		errors.append("rewards must be an object")
		return
	for key: Variant in rewards:
		if not _is_one_of(key, REWARD_KEYS):
			errors.append("rewards: '%s' is not supported yet" % key)
	_validate_flag_list(rewards.get("story_flags", []), "rewards.story_flags", errors)
	_validate_list(rewards.get("relationships", []), "rewards.relationships",
		RelationshipManager.validate_change, errors)

static func _validate_flag_list(entries: Variant, where: String, errors: PackedStringArray) -> void:
	if not entries is Array:
		errors.append(where + " must be an array")
		return
	for entry: Variant in entries:
		if not entry is Dictionary or not _is_non_empty_string(entry.get("flag")) or not entry.has("value"):
			errors.append(where + ": each entry needs flag and value")

static func _validate_list(entries: Variant, where: String, validator: Callable,
		errors: PackedStringArray) -> void:
	if not entries is Array:
		errors.append(where + " must be an array")
		return
	for entry: Variant in entries:
		var problem: String = validator.call(entry)
		if not problem.is_empty():
			errors.append(where + ": " + problem)

static func _check_keys(object: Dictionary, allowed: PackedStringArray, where: String,
		errors: PackedStringArray) -> void:
	for key: Variant in object:
		if not _is_one_of(key, allowed):
			errors.append(where + ": unknown field '%s'" % key)

## `x in PackedStringArray` is a runtime error when x is not a String
## (e.g. a missing JSON field), so data from files is checked with this.
static func _is_one_of(value: Variant, allowed: PackedStringArray) -> bool:
	return value is String and allowed.has(value)

static func _is_non_empty_string(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_story_flag_set(flag_name: String, _value: Variant) -> void:
	for quest_id: String in get_active_quests():
		for objective: Dictionary in get_definition(quest_id)["objectives"]:
			if (objective["type"] == OBJECTIVE_STORY_FLAG and objective["flag"] == flag_name
					and not is_objective_done(quest_id, objective["objective_id"])
					and _flag_matches(objective)):
				_mark_objective(quest_id, objective["objective_id"])
				# The quest may have completed; its objectives no longer matter.
				if get_quest_status(quest_id) != STATUS_ACTIVE:
					break
