# Unit tests for SaveManager: round trip (including a randomized property
# test, REQ-52.5), validation of damaged and incompatible files, slots,
# and that a failed load leaves the game unchanged.
#   tests/run_tests.sh tests/unit/test_save_manager.gd
extends "res://tests/support/base_test.gd"

const ROOM: String = "res://scenes/prototype/prototype_room.tscn"
const QUEST_ID: String = "ch1_main_borrowed_power"
const RANDOM_CASES: int = 200
const RANDOM_SEED: int = 20261120


func run_tests() -> void:
	_test_round_trip()
	_test_random_round_trips()
	_test_validation()
	_test_versions()
	await _test_slots_and_failed_load()
	_test_formatting()
	_reset_all()


func _reset_all() -> void:
	GameState.reset_game()
	SaveManager.last_error = ""


## A valid save dictionary with some progress, used as the base for mutations.
func _sample_data() -> Dictionary:
	return {
		"version": SaveManager.SAVE_VERSION,
		"timestamp": "2026-11-20T23:30:00",
		"saved_unix": 1795217400.5,
		"playtime_seconds": 754.25,
		"player_data": {"name": "Asel Nur", "chapter": 1, "current_scene": ROOM,
			"position": {"x": 300.5, "y": 250.0}},
		"story_data": {"flags": {"met_elias": true, "engineering_log_read": true, "visits": 3,
			"note": "Line one\nквота \"1420\""}},
		"quest_data": {"quests": [{"quest_id": QUEST_ID, "status": "active", "objectives_done": ["read_log"]}]},
		"relationship_data": {"elias_voss": {"trust": 45, "bond": 55}},
	}


func _without_timestamp(data: Dictionary) -> Dictionary:
	var copy: Dictionary = data.duplicate(true)
	copy.erase("timestamp")
	copy.erase("saved_unix")
	return copy


## Restore data, collect it back, write it as text, parse, restore, collect again.
## Returns {"first": ..., "second": ..., "errors": ...}.
func _round_trip(data: Dictionary) -> Dictionary:
	var parsed: Dictionary = capture_log(func() -> Dictionary:
		return SaveManager.parse_save_text(SaveManager.to_json(data)))["result"]
	if not parsed["errors"].is_empty():
		return {"errors": parsed["errors"]}
	capture_log(func() -> void: SaveManager.restore_state(parsed["data"]))
	var position: Vector2 = Vector2(data["player_data"]["position"]["x"], data["player_data"]["position"]["y"])
	var first: Dictionary = SaveManager.build_save_data(data["player_data"]["current_scene"], position)
	var reparsed: Dictionary = SaveManager.parse_save_text(SaveManager.to_json(first))
	if not reparsed["errors"].is_empty():
		return {"errors": reparsed["errors"]}
	_reset_all()
	capture_log(func() -> void: SaveManager.restore_state(reparsed["data"]))
	var second: Dictionary = SaveManager.build_save_data(first["player_data"]["current_scene"], position)
	return {"first": _without_timestamp(first), "second": _without_timestamp(second), "errors": []}


# ----------------------------------------------------------------------------

func _test_round_trip() -> void:
	section("round trip")
	_reset_all()
	var result: Dictionary = _round_trip(_sample_data())
	check(result["errors"].is_empty(), "sample save parses (errors %s)" % str(result["errors"]))
	if not result["errors"].is_empty():
		return
	check(result["first"] == result["second"], "save -> load -> save gives the same data")

	check(GameState.player_name == "Asel Nur" and GameState.current_chapter == 1, "name and chapter restored")
	check(is_equal_approx(GameState.game_time, 754.25), "playtime restored")
	check(GameState.game_started, "game marked as started")
	check(StoryFlagManager.get_flag("visits") is int and StoryFlagManager.get_flag("visits") == 3,
		"whole-number flag comes back as int 3, not float")
	check(StoryFlagManager.get_flag("note") == "Line one\nквота \"1420\"", "text flag with newline, quotes, Cyrillic")
	check(StoryFlagManager.get_flag("signal_disclosed") == false, "flags missing from the save keep their defaults")
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE, "quest status restored")
	check(QuestManager.is_objective_done(QUEST_ID, "read_log")
		and not QuestManager.is_objective_done(QUEST_ID, "report_to_elias"), "objective progress restored")
	check(RelationshipManager.get_trust("elias_voss") == 45 and RelationshipManager.get_bond("elias_voss") == 55,
		"relationships restored")
	check(RelationshipManager.get_trust("maya_chen") == 50, "crew missing from the save keep starting values")
	check(StoryFlagManager.get_flag("power_draw_investigated") == false
		and RelationshipManager.get_trust("elias_voss") == 45, "loading a quest gives no rewards again")

	var text: String = SaveManager.to_json(_sample_data())
	check(text.contains("\n\t\"player_data\": {"), "save file is tab-indented and readable")
	check(text.find("\"player_data\"") < text.find("\"playtime_seconds\"")
		and text.find("\"quest_data\"") < text.find("\"relationship_data\""), "keys are sorted")


func _test_random_round_trips() -> void:
	section("random round trips (%d cases, seed %d)" % [RANDOM_CASES, RANDOM_SEED])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	var failures: Array[String] = []
	for i: int in RANDOM_CASES:
		_reset_all()
		var data: Dictionary = _random_data(rng)
		var result: Dictionary = _round_trip(data)
		if not result["errors"].is_empty():
			failures.append("case %d rejected: %s" % [i, result["errors"][0]])
		elif result["first"] != result["second"]:
			failures.append("case %d changed:\n%s\nvs\n%s" % [i, str(result["first"]), str(result["second"])])
		elif not _matches_source(data, result["first"]):
			failures.append("case %d lost data in %s" % [i, _first_difference(data, result["first"])])
		if failures.size() >= 3:
			break
	check(failures.is_empty(), "every random state survives save and load%s"
		% ("" if failures.is_empty() else ": " + "\n".join(failures)))


## The restored state must hold what the generated save described. Whole
## numbers, text and booleans must match exactly. Fractional numbers may differ
## in the last binary digit: Godot's JSON parser is not correctly rounded for
## 17-digit decimals (about 1e-14 relative); a second save is then exact.
func _matches_source(source: Dictionary, restored: Dictionary) -> bool:
	if not _same(source["player_data"], restored["player_data"]):
		return false
	if not _same(source["playtime_seconds"], restored["playtime_seconds"]):
		return false
	for flag: String in source["story_data"]["flags"]:
		var expected: Variant = StoryFlagManager.normalize_value(source["story_data"]["flags"][flag])
		if not _same(expected, restored["story_data"]["flags"].get(flag)):
			return false
	if not _same(source["quest_data"], restored["quest_data"]):
		return false
	for npc_id: String in source["relationship_data"]:
		if not _same(source["relationship_data"][npc_id], restored["relationship_data"][npc_id]):
			return false
	return true


func _same(a: Variant, b: Variant) -> bool:
	if a is float and b is float:
		return is_equal_approx(a, b)
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for key: Variant in a:
			if not (b as Dictionary).has(key) or not _same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i: int in (a as Array).size():
			if not _same(a[i], b[i]):
				return false
		return true
	return a == b


func _first_difference(source: Dictionary, restored: Dictionary) -> String:
	for key: String in ["player_data", "quest_data"]:
		if not _same(source[key], restored[key]):
			return "%s: saved %s, restored %s" % [key, str(source[key]), str(restored[key])]
	for flag: String in source["story_data"]["flags"]:
		var expected: Variant = StoryFlagManager.normalize_value(source["story_data"]["flags"][flag])
		var actual: Variant = restored["story_data"]["flags"].get(flag)
		if not _same(expected, actual):
			return "flag %s: saved %s (%s), restored %s (%s)" % [flag, str(expected),
				type_string(typeof(expected)), str(actual), type_string(typeof(actual))]
	return "relationships or playtime"


func _random_data(rng: RandomNumberGenerator) -> Dictionary:
	var names: PackedStringArray = ["Asel", "Maya Chen", "Commander 7", "Айгерім Нұр", "Ян", "Zed"]
	var flag_names: PackedStringArray = ["met_elias", "engineering_log_read", "signal_disclosed",
		"test_counter", "test_note", "test_ratio", "test_choice"]
	var texts: PackedStringArray = ["", "a", "line\nbreak", "quote \" and \\ slash", "кириллица", "1420 MHz"]

	var flags: Dictionary = {}
	for flag: String in flag_names:
		if rng.randf() < 0.6:
			match rng.randi_range(0, 3):
				0: flags[flag] = rng.randf() < 0.5
				1: flags[flag] = rng.randi_range(-1000, 1000)
				2: flags[flag] = rng.randf_range(-100.0, 100.0)
				3: flags[flag] = texts[rng.randi_range(0, texts.size() - 1)]

	var relationships: Dictionary = {}
	for npc_id: String in RelationshipManager.CREW_MEMBERS:
		if rng.randf() < 0.75:
			relationships[npc_id] = {"trust": rng.randi_range(0, 100), "bond": rng.randi_range(0, 100)}

	var quests: Array = []
	if rng.randf() < 0.7:
		var done: Array = []
		for objective_id: String in ["read_log", "report_to_elias"]:
			if rng.randf() < 0.5:
				done.append(objective_id)
		var statuses: PackedStringArray = QuestManager.SAVABLE_STATUSES
		quests.append({"quest_id": QUEST_ID, "status": statuses[rng.randi_range(0, statuses.size() - 1)],
			"objectives_done": done})

	return {
		"version": SaveManager.SAVE_VERSION,
		"timestamp": "2026-11-20T00:00:00",
		"saved_unix": rng.randf_range(0.0, 2.0e9),
		"playtime_seconds": rng.randf_range(0.0, 36000.0),
		"player_data": {
			"name": names[rng.randi_range(0, names.size() - 1)],
			"chapter": rng.randi_range(1, GameState.TOTAL_CHAPTERS),
			"current_scene": ROOM,
			"position": {"x": rng.randf_range(-500.0, 1500.0), "y": rng.randf_range(-500.0, 1500.0)},
		},
		"story_data": {"flags": flags},
		"quest_data": {"quests": quests},
		"relationship_data": relationships,
	}


func _test_validation() -> void:
	section("damaged files give clear errors")
	var text_cases: Array = [
		["{\"version\": 1,", "not valid JSON (line"],
		["[1, 2]", "must contain a JSON object"],
		["{}", "missing or invalid version"],
	]
	for case: Array in text_cases:
		var errors: PackedStringArray = SaveManager.parse_save_text(case[0])["errors"]
		check(has_message(errors, [case[1]]), "rejects %s: %s (got %s)" % [case[0], case[1], str(errors)])

	var mutations: Array = [
		[func(d: Dictionary) -> void: d.erase("quest_data"), "missing field 'quest_data'"],
		[func(d: Dictionary) -> void: d["extra"] = 1, "unknown field 'extra'"],
		[func(d: Dictionary) -> void: d["playtime_seconds"] = -1, "playtime_seconds must be a number"],
		[func(d: Dictionary) -> void: d["player_data"]["name"] = "A", "player_data.name: Name must be at least 2"],
		[func(d: Dictionary) -> void: d["player_data"]["chapter"] = 9, "chapter must be a whole number from 1 to 7"],
		[func(d: Dictionary) -> void: d["player_data"]["current_scene"] = "res://scenes/nowhere.tscn",
			"current_scene does not exist"],
		[func(d: Dictionary) -> void: d["player_data"]["current_scene"] = "/etc/passwd", "must be a res:// .tscn path"],
		[func(d: Dictionary) -> void: d["player_data"]["position"].erase("y"), "position must be {x, y}"],
		[func(d: Dictionary) -> void: d["story_data"]["flags"]["met_elias"] = [1], "met_elias must be true/false"],
		[func(d: Dictionary) -> void: d["quest_data"]["quests"][0]["quest_id"] = "ghost_quest", "no such quest"],
		[func(d: Dictionary) -> void: d["quest_data"]["quests"][0]["objectives_done"] = ["fly"],
			"unknown objective 'fly'"],
		[func(d: Dictionary) -> void: d["quest_data"]["quests"][0]["status"] = "not_started",
			"status must be active, completed or failed"],
		[func(d: Dictionary) -> void: d["quest_data"]["quests"].append(d["quest_data"]["quests"][0].duplicate()),
			"listed twice"],
		[func(d: Dictionary) -> void: d["relationship_data"]["elias_voss"]["trust"] = 150,
			"elias_voss.trust must be a whole number from 0 to 100"],
		[func(d: Dictionary) -> void: d["relationship_data"]["ghost_unit"] = {"trust": 1, "bond": 1},
			"ghost_unit: not a crew member"],
	]
	for case: Array in mutations:
		var data: Dictionary = _sample_data()
		(case[0] as Callable).call(data)
		var result: Dictionary = SaveManager.parse_save_text(SaveManager.to_json(data))
		check(has_message(result["errors"], [case[1]]) and result["data"].is_empty(),
			"rejects: %s (got %s)" % [case[1], str(result["errors"])])


func _test_versions() -> void:
	section("versions")
	var data: Dictionary = _sample_data()
	check(SaveManager.parse_save_text(SaveManager.to_json(data))["errors"].is_empty(), "current version accepted")
	data["version"] = SaveManager.SAVE_VERSION + 1
	data["new_feature"] = {}
	var errors: PackedStringArray = SaveManager.parse_save_text(SaveManager.to_json(data))["errors"]
	check(errors.size() == 1 and has_message(errors, ["saved by a newer version of the game"]),
		"newer save format gives one clear version message, not field errors (got %s)" % str(errors))
	data["version"] = 0
	check(has_message(SaveManager.parse_save_text(SaveManager.to_json(data))["errors"], ["invalid version"]),
		"version 0 rejected")


func _test_slots_and_failed_load() -> void:
	section("slots and failed loads")
	_reset_all()
	var logged: Dictionary = capture_log(func() -> bool: return SaveManager.save_game(1))
	check(logged["result"] == false and SaveManager.last_error == "Start a game first.",
		"cannot save before a game starts")
	logged = capture_log(func() -> bool: return SaveManager.load_game(4))
	check(logged["result"] == false and SaveManager.last_error == "Save slot 4 does not exist.", "slot 4 rejected")
	logged = capture_log(func() -> bool: return SaveManager.load_game(1))
	check(logged["result"] == false and SaveManager.last_error == "Slot 1 is empty.", "empty slot rejected")
	check(SaveManager.get_slot_info(1) == {"exists": false, "valid": false, "error": ""}, "empty slot info")
	check(SaveManager.slot_path(2).begins_with(TEST_SAVE_DIR), "tests use the isolated save folder")

	# A damaged file must not change the running game.
	capture_log(func() -> void: SaveManager.restore_state(_sample_data()))
	var before: Dictionary = _without_timestamp(SaveManager.build_save_data(ROOM, Vector2(1, 2)))
	var damaged: Dictionary = _sample_data()
	damaged["relationship_data"]["elias_voss"]["trust"] = 999
	damaged["player_data"]["name"] = "Someone Else"
	var file: FileAccess = FileAccess.open(SaveManager.slot_path(2), FileAccess.WRITE)
	file.store_string(SaveManager.to_json(damaged))
	file.close()
	logged = capture_log(func() -> bool: return SaveManager.load_game(2))
	check(logged["result"] == false and SaveManager.last_error.begins_with("The save in slot 2 is damaged"),
		"damaged slot refused (%s)" % SaveManager.last_error)
	check(has_message(logged["errors"], ["slot 2 is not loadable", "elias_voss.trust"]), "log lists the problem")
	check(_without_timestamp(SaveManager.build_save_data(ROOM, Vector2(1, 2))) == before,
		"a failed load leaves the game unchanged")
	var info: Dictionary = SaveManager.get_slot_info(2)
	check(info["exists"] and not info["valid"] and "elias_voss.trust" in info["error"], "slot info reports the damage")
	check(SaveManager.delete_save(2) and not SaveManager.has_save(2), "delete_save removes the file")
	await process_frames(1)


func _test_formatting() -> void:
	section("formatting")
	check(SaveManager.format_playtime(0.0) == "0:00:00", "0 s")
	check(SaveManager.format_playtime(312.7) == "0:05:12", "312.7 s")
	check(SaveManager.format_playtime(3725.0) == "1:02:05", "3725 s")
	var info: Dictionary = {"player_name": "Asel Nur", "chapter": 1.0, "playtime_seconds": 754.25}
	check(SaveManager.describe_slot(info) == "CMDR ASEL NUR · Chapter 1 · 0:12:34 played",
		"slot description (got \"%s\")" % SaveManager.describe_slot(info))
