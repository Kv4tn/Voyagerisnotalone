# Content check for every dialogue, quest, NPC metadata file and NPC scene.
# Run it after editing anything in data/dialogues, data/quests, data/npcs
# or scenes/npcs:
#   tests/run_tests.sh tests/content/test_dialogue_content.gd
# Rules are documented in docs/dialogue-format.md and docs/quest-format.md.
extends "res://tests/support/base_test.gd"

const DIALOGUE_DIR: String = "res://data/dialogues/"
const NPC_DIR: String = "res://data/npcs/"
const QUEST_DIR: String = "res://data/quests/"
const NPC_SCENE_DIR: String = "res://scenes/npcs/"
const NPC_BASE_SCENE: String = "npc_base.tscn"


func run_tests() -> void:
	StoryFlagManager.reset()
	QuestManager.quest_dir = QUEST_DIR
	QuestManager.clear_cache()
	_check_npc_files()
	_check_quest_files()
	_check_dialogue_files()
	_check_npc_scenes()


func _check_npc_files() -> void:
	section("data/npcs")
	var files: PackedStringArray = _json_files(NPC_DIR)
	check(not files.is_empty(), "at least one NPC metadata file")
	for file: String in files:
		var data: Variant = _load(NPC_DIR + file)
		if data == null:
			continue
		var errors: PackedStringArray = NpcRegistry.validate(data, file.get_basename())
		check(errors.is_empty(), "%s is valid%s" % [file, _details(errors)])


func _check_dialogue_files() -> void:
	section("data/dialogues")
	var files: PackedStringArray = _json_files(DIALOGUE_DIR)
	check(not files.is_empty(), "at least one dialogue file")
	for file: String in files:
		var data: Variant = _load(DIALOGUE_DIR + file)
		if data == null:
			continue
		var errors: PackedStringArray = DialogueManager.validate_tree(data)
		check(errors.is_empty(), "%s: structure is valid%s" % [file, _details(errors)])
		if not errors.is_empty():
			continue

		check(data["dialogue_id"] == file.get_basename(),
			"%s: dialogue_id matches the file name (got '%s')" % [file, data["dialogue_id"]])
		check(_unknown_speakers(data).is_empty(),
			"%s: every speaker_id is 'player' or has data/npcs/<id>.json%s"
				% [file, _details(_unknown_speakers(data))])
		check(_unreachable_nodes(data).is_empty(),
			"%s: every node is reachable from start_node%s" % [file, _details(_unreachable_nodes(data))])
		check(_unregistered_flags(data).is_empty(),
			"%s: every story flag is in the shared list%s" % [file, _details(_unregistered_flags(data))])
		check(_bad_quest_references(data).is_empty(),
			"%s: every quest and objective it uses exists%s" % [file, _details(_bad_quest_references(data))])


func _check_quest_files() -> void:
	section("data/quests")
	for file: String in _json_files(QUEST_DIR):
		var data: Variant = _load(QUEST_DIR + file)
		if data == null:
			continue
		var errors: PackedStringArray = QuestManager.validate_quest(data, file.get_basename())
		check(errors.is_empty(), "%s: structure is valid%s" % [file, _details(errors)])
		if not errors.is_empty():
			continue
		var problems: PackedStringArray = _quest_reference_problems(data)
		check(problems.is_empty(), "%s: flags registered, NPCs and quests exist%s" % [file, _details(problems)])


func _check_npc_scenes() -> void:
	section("scenes/npcs")
	for file: String in DirAccess.get_files_at(NPC_SCENE_DIR):
		if file.get_extension() != "tscn" or file == NPC_BASE_SCENE:
			continue
		var scene: PackedScene = load(NPC_SCENE_DIR + file) as PackedScene
		var npc: NPCController = scene.instantiate() as NPCController if scene != null else null
		check(npc != null, "%s: root is an NPCController (inherit npc_base.tscn)" % file)
		if npc == null:
			continue
		check(not NpcRegistry.get_metadata(npc.npc_id).is_empty(),
			"%s: npc_id '%s' has a valid data/npcs file" % [file, npc.npc_id])
		var path: String = NpcRegistry.get_dialogue_path(npc.npc_id, npc.dialogue_key)
		check(not path.is_empty(), "%s: dialogue_files has key '%s'" % [file, npc.dialogue_key])
		npc.free()


# ----------------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------------

func _unknown_speakers(tree: Dictionary) -> PackedStringArray:
	var unknown: PackedStringArray = []
	for node: Dictionary in tree["nodes"]:
		var speaker: String = node["speaker_id"]
		if speaker == DialogueManager.PLAYER_SPEAKER_ID or speaker in unknown:
			continue
		if not FileAccess.file_exists(NPC_DIR + speaker + ".json"):
			unknown.append(speaker)
	return unknown


func _unreachable_nodes(tree: Dictionary) -> PackedStringArray:
	var nodes: Dictionary = {}
	for node: Dictionary in tree["nodes"]:
		nodes[node["node_id"]] = node
	var reached: Dictionary = {}
	var queue: Array[String] = [tree["start_node"]]
	while not queue.is_empty():
		var node_id: String = queue.pop_back()
		if reached.has(node_id):
			continue
		reached[node_id] = true
		var node: Dictionary = nodes[node_id]
		for key: String in ["next_node", "fallback_node"]:
			if node.has(key):
				queue.append(node[key])
		for response: Dictionary in node.get("responses", []):
			queue.append(response["next_node"])
	var unreachable: PackedStringArray = []
	for node_id: String in nodes:
		if not reached.has(node_id):
			unreachable.append(node_id)
	return unreachable


func _unregistered_flags(tree: Dictionary) -> PackedStringArray:
	var used: PackedStringArray = []
	for node: Dictionary in tree["nodes"]:
		_collect_flags(node, used)
		for response: Dictionary in node.get("responses", []):
			_collect_flags(response, used)
	var unregistered: PackedStringArray = []
	for flag: String in used:
		if not StoryFlagManager.has_flag(flag) and not flag in unregistered:
			unregistered.append(flag)
	return unregistered


func _bad_quest_references(tree: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = []
	for node: Dictionary in tree["nodes"]:
		var entries: Array = [node]
		entries.append_array(node.get("responses", []))
		for entry: Dictionary in entries:
			for quest_check: Dictionary in entry.get("conditions", {}).get("quests", []):
				_require_quest(quest_check["quest_id"], "", problems)
			for effect: Dictionary in entry.get("effects", []):
				match effect["type"]:
					"start_quest":
						_require_quest(effect["quest_id"], "", problems)
					"update_quest":
						_require_quest(effect["quest_id"], effect["objective_id"], problems)
	return problems


func _require_quest(quest_id: String, objective_id: String, problems: PackedStringArray) -> void:
	if not QuestManager.has_quest(quest_id):
		problems.append("quest '%s' has no data/quests file" % quest_id)
		return
	var definition: Dictionary = QuestManager.get_definition(quest_id)
	if definition.is_empty() or objective_id.is_empty():
		return
	for objective: Dictionary in definition["objectives"]:
		if objective["objective_id"] == objective_id:
			return
	problems.append("quest '%s' has no objective '%s'" % [quest_id, objective_id])


func _quest_reference_problems(quest: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = []
	var flags: Array = []
	flags.append_array(quest.get("prerequisites", {}).get("story_flags", []))
	flags.append_array(quest.get("rewards", {}).get("story_flags", []))
	for objective: Dictionary in quest["objectives"]:
		if objective["type"] == QuestManager.OBJECTIVE_STORY_FLAG:
			flags.append(objective)
		elif objective["type"] == QuestManager.OBJECTIVE_TALK_TO:
			if not FileAccess.file_exists(NPC_DIR + objective["target"] + ".json"):
				problems.append("talk_to target '%s' has no data/npcs file" % objective["target"])
	for entry: Dictionary in flags:
		if not StoryFlagManager.has_flag(entry["flag"]):
			problems.append("flag '%s' is not in the shared list" % entry["flag"])
	for required: String in quest.get("prerequisites", {}).get("quests_completed", []):
		if not QuestManager.has_quest(required):
			problems.append("quests_completed '%s' has no data/quests file" % required)
	return problems


func _collect_flags(entry: Dictionary, into: PackedStringArray) -> void:
	for flag_check: Dictionary in entry.get("conditions", {}).get("story_flags", []):
		into.append(flag_check["flag"])
	for effect: Dictionary in entry.get("effects", []):
		if effect["type"] == "set_flag":
			into.append(effect["flag"])


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _json_files(directory: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "json":
			result.append(file)
	result.sort()
	return result


func _load(path: String) -> Variant:
	var logged: Dictionary = capture_log(func() -> Variant: return JsonLoader.load_file(path))
	var ok: bool = logged["result"] != null
	check(ok, "%s parses as JSON%s" % [path.get_file(), _details(logged["errors"])])
	return logged["result"]


func _details(messages: PackedStringArray) -> String:
	return "" if messages.is_empty() else ": " + "; ".join(messages)
