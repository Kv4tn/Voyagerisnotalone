# Unit tests for DialogueManager: loading, validation, branching, effects.
#   tests/run_tests.sh tests/unit/test_dialogue_manager.gd
extends "res://tests/support/base_test.gd"

const FIXTURES: String = "res://tests/fixtures/dialogues/"
const BRANCHING: String = FIXTURES + "branching.json"

var _lines: Array[Dictionary] = []
var _started: Array[String] = []
var _ended: int = 0


func run_tests() -> void:
	DialogueManager.line_shown.connect(func(line: Dictionary) -> void: _lines.append(line))
	DialogueManager.dialogue_started.connect(func(id: String) -> void: _started.append(id))
	DialogueManager.dialogue_ended.connect(func() -> void: _ended += 1)

	_test_loading_errors()
	_test_validation_rules()
	_test_cache()
	_test_first_visit()
	_test_second_visit_and_hidden_choice()
	_test_guards()
	_test_fallback_loop()
	_test_player_name_fallback()


func _reset() -> void:
	DialogueManager.reset()
	StoryFlagManager.reset()
	GameState.player_name = "Asel"
	_lines.clear()
	_started.clear()
	_ended = 0


func _quiet(action: Callable) -> void:
	# New test flags make StoryFlagManager warn; expected here.
	capture_log(action)


# ----------------------------------------------------------------------------

func _test_loading_errors() -> void:
	section("loading errors")
	var logged: Dictionary = capture_log(func() -> Dictionary:
		return DialogueManager.load_tree(FIXTURES + "does_not_exist.json"))
	check(logged["result"].is_empty(), "missing file returns {}")
	check(has_message(logged["errors"], ["file not found", "does_not_exist.json"]),
		"missing file error names the path")

	logged = capture_log(func() -> Dictionary: return DialogueManager.load_tree(FIXTURES + "malformed.json"))
	check(logged["result"].is_empty(), "malformed JSON returns {}")
	check(has_message(logged["errors"], ["malformed.json", "line 5"]),
		"malformed JSON error gives file and line (got %s)" % str(logged["errors"]))

	logged = capture_log(func() -> Dictionary:
		return DialogueManager.load_tree(FIXTURES + "bad_reference.json"))
	check(logged["result"].is_empty(), "tree with bad references returns {}")
	check(has_message(logged["errors"], ["start_node 'missing_start' is not a node_id"]),
		"reports a missing start_node")
	check(has_message(logged["errors"], ["node 'only'", "next_node 'nowhere' is not a node_id"]),
		"reports a missing next_node")

	_reset()
	logged = capture_log(func() -> bool: return DialogueManager.start_dialogue(FIXTURES + "bad_reference.json"))
	check(logged["result"] == false and not DialogueManager.is_dialogue_active,
		"invalid file does not start a dialogue")
	check(_started.is_empty(), "dialogue_started not emitted for an invalid file")


func _test_validation_rules() -> void:
	section("validation rules")
	var cases: Array = [
		[{"next_nod": "b"}, "unknown field 'next_nod'"],
		[{"conditions": {"relationships": []}, "fallback_node": "b"},
			"condition 'relationships' is not supported yet"],
		[{"effects": [{"type": "change_relationship", "npc_id": "elias_voss"}]},
			"effect type 'change_relationship' is not supported yet"],
		[{"effects": [{"type": "start_quest"}]}, "start_quest needs quest_id"],
		[{"effects": [{"type": "update_quest", "quest_id": "q", "objective_id": "o", "status": "active"}]},
			"update_quest needs quest_id, objective_id and status \"completed\""],
		[{"conditions": {"quests": [{"quest_id": "q", "status": "done"}]}, "fallback_node": "b"},
			"each quests entry needs quest_id and status"],
		[{"effects": [{"type": "set_flag", "flag": "x"}]}, "set_flag needs flag and value"],
		[{"conditions": {"story_flags": [{"flag": "x", "value": true}]}},
			"has conditions but no fallback_node"],
		[{"next_node": "b", "responses": [{"text": "Go", "next_node": "b"}]},
			"has both responses and next_node"],
		[{"responses": [{"text": "Go", "next_node": "missing"}]},
			"next_node 'missing' is not a node_id"],
		[{"responses": [{"text": "", "next_node": "b"}]}, "text must be a non-empty string"],
		[{"speaker_id": ""}, "speaker_id must be a non-empty string"],
	]
	for case: Array in cases:
		var node_a: Dictionary = {"node_id": "a", "speaker_id": "elias_voss", "text": "A"}
		node_a.merge(case[0], true)
		var tree: Dictionary = {
			"dialogue_id": "t", "start_node": "a",
			"nodes": [node_a, {"node_id": "b", "speaker_id": "elias_voss", "text": "B"}],
		}
		var errors: PackedStringArray = DialogueManager.validate_tree(tree)
		check(has_message(errors, [case[1]]), "rejects: %s (got %s)" % [case[1], str(errors)])

	var duplicate: Dictionary = {"dialogue_id": "t", "start_node": "a", "nodes": [
		{"node_id": "a", "speaker_id": "x", "text": "1"},
		{"node_id": "a", "speaker_id": "x", "text": "2"}]}
	check(has_message(DialogueManager.validate_tree(duplicate), ["duplicate node_id 'a'"]),
		"rejects duplicate node ids")
	check(has_message(DialogueManager.validate_tree({"dialogue_id": "t", "nodes": []}),
		["nodes must be a non-empty array"]), "rejects an empty node list")

	var branching: Variant = JsonLoader.load_file(BRANCHING)
	check(DialogueManager.validate_tree(branching).is_empty(), "valid fixture has no errors")


func _test_cache() -> void:
	section("cache")
	DialogueManager.clear_cache()
	var first: Dictionary = DialogueManager.load_tree(BRANCHING)
	var second: Dictionary = DialogueManager.load_tree(BRANCHING)
	check(not first.is_empty() and is_same(first, second), "second load returns the cached tree")
	DialogueManager.clear_cache()
	check(not is_same(first, DialogueManager.load_tree(BRANCHING)), "clear_cache() forces a reload")


func _test_first_visit() -> void:
	section("first visit: fallback, substitution, effects")
	_reset()
	var ok: bool = capture_log(func() -> bool:
		return DialogueManager.start_dialogue(BRANCHING, "elias_voss"))["result"]
	check(ok and DialogueManager.is_dialogue_active, "start_dialogue() returns true")
	check(_started == ["test_branching"], "dialogue_started emitted with the dialogue_id")
	check(DialogueManager.current_dialogue_id == "test_branching", "current_dialogue_id set")

	var line: Dictionary = _lines[-1]
	check(line["text"] == "I am Elias Voss. You are Asel.",
		"failed condition falls back; {npc_name}/{player_name} replaced (got \"%s\")" % line["text"])
	check(line["speaker_name"] == "Elias Voss", "speaker name comes from data/npcs")
	check(line["choices"].is_empty() and not line["is_last"], "line without choices is not the last")
	check(StoryFlagManager.get_flag("test_met") == true, "node effect set_flag applied")

	DialogueManager.advance()
	line = _lines[-1]
	check(line["speaker_id"] == "player" and line["speaker_name"] == "Asel",
		"player lines use the commander name")
	check(line["choices"] == ["Always visible"], "choice with an unmet condition is hidden")
	DialogueManager.advance()
	check(_lines[-1]["text"] == "Choose.", "advance() does nothing while choices are shown")

	_quiet(func() -> void: DialogueManager.choose(0))
	check(StoryFlagManager.get_flag("test_choice") == "a", "response effect applied")
	line = _lines[-1]
	check(line["text"] == "Picked A." and line["is_last"], "choice leads to its next_node, marked last")
	check(line["speaker_name"] == "Ghost Unit", "unknown speaker gets a readable fallback name")

	DialogueManager.advance()
	check(not DialogueManager.is_dialogue_active and _ended == 1, "advance() on the last line ends once")
	check(DialogueManager.get_current_line().is_empty(), "no current line after the end")


func _test_second_visit_and_hidden_choice() -> void:
	section("second visit and revealed choice")
	_lines.clear()
	_quiet(func() -> void: StoryFlagManager.set_flag("test_secret", true))
	DialogueManager.start_dialogue(BRANCHING, "elias_voss")
	check(_lines[-1]["text"] == "Welcome back, Asel.", "met flag selects the repeat-visit node")
	DialogueManager.advance()
	check(_lines[-1]["choices"] == ["Always visible", "Needs secret"], "flag reveals the hidden choice")
	DialogueManager.choose(1)
	check(_lines[-1]["text"] == "Picked B.", "second choice leads to its node")
	DialogueManager.advance()


func _test_guards() -> void:
	section("guards")
	_reset()
	_quiet(func() -> void: DialogueManager.start_dialogue(BRANCHING, "elias_voss"))
	var logged: Dictionary = capture_log(func() -> bool: return DialogueManager.start_dialogue(BRANCHING))
	check(logged["result"] == false and has_message(logged["warnings"], ["already active"]),
		"second start_dialogue() while active is refused")
	DialogueManager.advance()
	var count: int = _lines.size()
	logged = capture_log(func() -> void: DialogueManager.choose(5))
	check(_lines.size() == count and has_message(logged["warnings"], ["invalid choice 5"]),
		"out-of-range choice is ignored with a warning")
	DialogueManager.end_dialogue()
	DialogueManager.end_dialogue()
	check(_ended == 1, "end_dialogue() twice emits dialogue_ended once")


func _test_fallback_loop() -> void:
	section("fallback loop")
	_reset()
	var logged: Dictionary = capture_log(func() -> void:
		DialogueManager.start_dialogue(FIXTURES + "fallback_loop.json"))
	check(not DialogueManager.is_dialogue_active, "dialogue ends instead of looping forever")
	check(has_message(logged["warnings"], ["no reachable node"]), "warns about the unreachable start")
	check(_ended == 1, "dialogue_ended emitted")


func _test_player_name_fallback() -> void:
	section("player name fallback")
	_reset()
	GameState.player_name = ""
	_quiet(func() -> void: DialogueManager.start_dialogue(BRANCHING, "elias_voss"))
	check(_lines[-1]["text"] == "I am Elias Voss. You are Commander.", "empty name becomes 'Commander'")
	DialogueManager.end_dialogue()
	GameState.player_name = ""
