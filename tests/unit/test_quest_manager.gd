# Unit tests for QuestManager: loading, validation, prerequisites,
# objectives, completion, rewards, failure, reset.
#   tests/run_tests.sh tests/unit/test_quest_manager.gd
extends "res://tests/support/base_test.gd"

const FIXTURES: String = "res://tests/fixtures/quests/"
const MAIN: String = "test_two_steps"
const FOLLOW: String = "test_follow_up"

var _events: Array[String] = []


func run_tests() -> void:
	QuestManager.quest_dir = FIXTURES
	QuestManager.clear_cache()
	QuestManager.quest_started.connect(func(id: String) -> void: _events.append("started:" + id))
	QuestManager.objective_completed.connect(func(id: String, objective: String) -> void:
		_events.append("objective:%s/%s" % [id, objective]))
	QuestManager.quest_completed.connect(func(id: String) -> void:
		# Rewards must already be applied when listeners hear about completion.
		var reward: Variant = StoryFlagManager.get_flag("test_reward") if StoryFlagManager.has_flag("test_reward") else null
		_events.append("completed:%s reward=%s" % [id, str(reward)]))
	QuestManager.quest_failed.connect(func(id: String) -> void: _events.append("failed:" + id))

	_test_loading_errors()
	_test_validation_rules()
	_test_prerequisites_block_start()
	_test_start_and_progress()
	_test_follow_up_with_flag_already_set()
	_test_failure()
	_test_reset()

	QuestManager.quest_dir = QuestManager.QUEST_DIR
	QuestManager.clear_cache()
	QuestManager.reset()


func _reset() -> void:
	QuestManager.reset()
	StoryFlagManager.reset()
	_events.clear()


func _set_flag(flag: String, value: Variant) -> void:
	# Fixture flags are not in the shared list, so StoryFlagManager warns.
	capture_log(func() -> void: StoryFlagManager.set_flag(flag, value))


# ----------------------------------------------------------------------------

func _test_loading_errors() -> void:
	section("loading errors")
	var logged: Dictionary = capture_log(func() -> bool: return QuestManager.start_quest("missing_quest"))
	check(logged["result"] == false, "unknown quest does not start")
	check(has_message(logged["errors"], ["file not found", "missing_quest.json"]), "error names the missing file")
	check(QuestManager.get_quest_view("missing_quest").is_empty(), "no view for an unknown quest")

	logged = capture_log(func() -> Dictionary: return QuestManager.get_definition("test_invalid"))
	check(logged["result"].is_empty(), "invalid quest returns {}")
	for fragment: String in [
			"quest_id 'not_the_file_name' does not match file name 'test_invalid'",
			"root: unknown field 'reward'",
			"objectives[0]: type must be one of story_flag, talk_to"]:
		check(has_message(logged["errors"], [fragment]), "reports: " + fragment)


func _test_validation_rules() -> void:
	section("validation rules")
	var base: Dictionary = {
		"quest_id": "q", "title": "Q",
		"objectives": [{"objective_id": "a", "description": "A", "type": "talk_to", "target": "elias_voss"}],
	}
	check(QuestManager.validate_quest(base, "q").is_empty(), "minimal quest is valid")

	var cases: Array = [
		[{"title": ""}, "title must be a non-empty string"],
		[{"category": "epic"}, "category must be one of"],
		[{"objectives": []}, "objectives must be a non-empty array"],
		[{"objectives": [{"objective_id": "a", "description": "A", "type": "talk_to",
			"target": "x", "optional": true}]}, "at least one objective must not be optional"],
		[{"objectives": [
			{"objective_id": "a", "description": "A", "type": "talk_to", "target": "x"},
			{"objective_id": "a", "description": "B", "type": "talk_to", "target": "x"}]},
			"duplicate objective_id 'a'"],
		[{"objectives": [{"objective_id": "a", "description": "A", "type": "story_flag", "flag": "f"}]},
			"story_flag objectives need flag and value"],
		[{"objectives": [{"objective_id": "a", "description": "A", "type": "talk_to"}]},
			"talk_to objectives need target"],
		[{"objectives": [{"objective_id": "a", "description": "", "type": "talk_to", "target": "x"}]},
			"description must be a non-empty string"],
		[{"prerequisites": {"relationships": []}}, "prerequisites: 'relationships' is not supported yet"],
		[{"prerequisites": {"quests_completed": "q0"}}, "quests_completed must be an array"],
		[{"rewards": {"items": []}}, "rewards: 'items' is not supported yet"],
		[{"rewards": {"story_flags": [{"flag": "f"}]}}, "rewards.story_flags: each entry needs flag and value"],
	]
	for case: Array in cases:
		var data: Dictionary = base.duplicate(true)
		data.merge(case[0], true)
		var errors: PackedStringArray = QuestManager.validate_quest(data, "q")
		check(has_message(errors, [case[1]]), "rejects: %s (got %s)" % [case[1], str(errors)])


func _test_prerequisites_block_start() -> void:
	section("prerequisites")
	_reset()
	var logged: Dictionary = capture_log(func() -> bool: return QuestManager.start_quest(MAIN))
	check(logged["result"] == false and has_message(logged["warnings"], ["prerequisites", MAIN]),
		"flag prerequisite blocks the start")
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_NOT_STARTED, "status stays not_started")
	logged = capture_log(func() -> bool: return QuestManager.start_quest(FOLLOW))
	check(logged["result"] == false, "quests_completed prerequisite blocks the start")
	check(_events.is_empty(), "no signals for a blocked start")


func _test_start_and_progress() -> void:
	section("start, objectives, completion")
	_reset()
	_set_flag("test_ready", true)
	check(QuestManager.start_quest(MAIN), "start_quest() returns true once prerequisites hold")
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_ACTIVE, "status is active")
	check(_events == ["started:" + MAIN], "quest_started emitted once")
	check(QuestManager.get_active_quests() == [MAIN], "listed in get_active_quests()")

	var view: Dictionary = QuestManager.get_quest_view(MAIN)
	check(view["title"] == "Two Steps" and view["objectives"].size() == 3, "view has title and 3 objectives")
	check(view["objectives"].all(func(o: Dictionary) -> bool: return not o["done"]), "no objective done yet")
	check(view["objectives"][2]["optional"], "optional flag exposed in the view")

	var logged: Dictionary = capture_log(func() -> bool: return QuestManager.start_quest(MAIN))
	check(logged["result"] == false and has_message(logged["warnings"], ["already active"]),
		"starting an active quest again is refused")

	_events.clear()
	_set_flag("test_found", false)
	check(not QuestManager.is_objective_done(MAIN, "find"), "flag set to the wrong value does not count")
	_set_flag("test_found", true)
	check(QuestManager.is_objective_done(MAIN, "find"), "story_flag objective completes when its flag is set")
	check(_events == ["objective:%s/find" % MAIN], "objective_completed emitted")
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_ACTIVE, "quest still active")

	logged = capture_log(func() -> bool: return QuestManager.complete_objective(MAIN, "nope"))
	check(logged["result"] == false and has_message(logged["warnings"], ["no objective 'nope'"]),
		"unknown objective is refused")
	check(not QuestManager.complete_objective(MAIN, "find"), "completing a done objective returns false")

	_events.clear()
	check(QuestManager.complete_objective(MAIN, "talk"), "talk_to objective completed explicitly")
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_COMPLETED,
		"quest completes without its optional objective")
	check(_events == ["objective:%s/talk" % MAIN, "completed:%s reward=true" % MAIN],
		"objective then quest_completed, reward applied before the signal (got %s)" % str(_events))
	check(StoryFlagManager.get_flag("test_reward") == true, "reward story flag set")
	check(QuestManager.get_active_quests().is_empty(), "no longer active")
	check(QuestManager.get_quest_ids(QuestManager.STATUS_COMPLETED) == [MAIN], "listed as completed")

	logged = capture_log(func() -> bool: return QuestManager.complete_objective(MAIN, "extra"))
	check(logged["result"] == false and has_message(logged["warnings"], ["it is completed"]),
		"objectives of a completed quest cannot change")


func _test_follow_up_with_flag_already_set() -> void:
	section("follow-up quest, flag already set")
	_events.clear()
	_set_flag("test_follow", true)
	check(QuestManager.start_quest(FOLLOW), "quests_completed prerequisite met after completion")
	check(QuestManager.is_objective_done(FOLLOW, "already"), "flag set before the start counts immediately")
	check(QuestManager.get_quest_status(FOLLOW) == QuestManager.STATUS_COMPLETED, "quest completes on start")
	check(_events[0] == "started:" + FOLLOW and _events[-1].begins_with("completed:" + FOLLOW),
		"started is emitted before completed (got %s)" % str(_events))


func _test_failure() -> void:
	section("failure")
	_reset()
	_set_flag("test_ready", true)
	QuestManager.start_quest(MAIN)
	check(QuestManager.fail_quest(MAIN), "fail_quest() on an active quest")
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_FAILED, "status is failed")
	check(_events[-1] == "failed:" + MAIN, "quest_failed emitted")
	_set_flag("test_found", true)
	check(not QuestManager.is_objective_done(MAIN, "find"), "flags no longer move a failed quest")
	var logged: Dictionary = capture_log(func() -> bool: return QuestManager.fail_quest(MAIN))
	check(logged["result"] == false, "failing twice is refused")
	check(not StoryFlagManager.has_flag("test_reward") or StoryFlagManager.get_flag("test_reward") == false,
		"no reward for a failed quest")


func _test_reset() -> void:
	section("reset")
	QuestManager.reset()
	check(QuestManager.get_quest_status(MAIN) == QuestManager.STATUS_NOT_STARTED, "reset forgets status")
	check(QuestManager.get_quest_ids(QuestManager.STATUS_FAILED).is_empty(), "reset clears the lists")
