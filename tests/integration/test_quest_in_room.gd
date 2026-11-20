# Integration test: Elias's quest "Borrowed Power" played with real input.
# Elias gives the quest, the terminal completes the first objective, the
# report to Elias completes the quest, the HUD tracker follows along.
#   tests/run_tests.sh tests/integration/test_quest_in_room.gd
extends "res://tests/support/base_test.gd"

const ROOM_SCENE: String = "res://scenes/prototype/prototype_room.tscn"
const QUEST_ID: String = "ch1_main_borrowed_power"
const PHYSICS_FPS: int = 60

var _room: Node = null
var _player: PlayerController = null
var _hud: GameHud = null
var _box: DialogueBox = null
var _tracker: QuestTracker = null
var _toast: RelationshipToast = null
var _elias: NPCController = null


func run_tests() -> void:
	StoryFlagManager.reset()
	DialogueManager.reset()
	QuestManager.reset()
	RelationshipManager.reset()
	GameState.player_name = "Asel"

	_room = (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	_player = _room.get_node("Player") as PlayerController
	_hud = _room.get_node("HUD") as GameHud
	_box = _room.get_node("HUD/DialogueBox") as DialogueBox
	_tracker = _room.get_node("HUD/QuestTracker") as QuestTracker
	_toast = _room.get_node("HUD/RelationshipToast") as RelationshipToast
	_elias = _room.get_node("EliasVoss") as NPCController
	await physics_frames(2)

	check(not _tracker.visible, "quest tracker hidden with no quests")
	await _test_receive_quest()
	await _test_read_log()
	await _test_report_completes_quest()
	await _test_after_completion()


func _test_receive_quest() -> void:
	section("Elias gives the quest")
	await _stand_below(_elias, 25.0)
	await _press_e()  # start
	await _press_e()  # finish typing greeting
	check(RelationshipManager.get_trust("elias_voss") == 40, "Elias starts with trust 40 from data/npcs")
	await _press_e()  # "That's me. I'd like to hear how the ship is doing."
	check(RelationshipManager.get_trust("elias_voss") == 45, "asking about the ship: trust +5")
	check(_toast.get_lines() == PackedStringArray(["Elias Voss: Trust +5"]),
		"notice shows the change (got %s)" % str(_toast.get_lines()))
	await _press_e()  # finish typing status
	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 2 and buttons[0].text == "1. I'll find out why.", "quest is offered")
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_NOT_STARTED, "not started before choosing")

	await _press_e()  # choose "I'll find out why."
	check(_text().begins_with("Then start with the engineering log"), "Elias explains the task")
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE, "quest is active")
	check(_tracker.visible, "tracker appears")
	check(_tracker.get_lines() == PackedStringArray([
			"Borrowed Power",
			"[ ] Read the engineering log terminal",
			"[ ] Tell Elias what the log says"]),
		"tracker shows title and open objectives (got %s)" % str(_tracker.get_lines()))
	await _close_remaining_lines()
	check(not DialogueManager.is_dialogue_active, "dialogue closed")


func _test_read_log() -> void:
	section("terminal completes the first objective")
	await _wait_cooldown()
	await _stand_below(_room.get_node("Terminal") as Node2D, 30.0)
	await _press_e()
	check(_hud.is_message_open(), "engineering log opens")
	check(QuestManager.is_objective_done(QUEST_ID, "read_log"), "read_log objective done")
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE, "quest still active")
	check(_tracker.get_lines().has("[x] Read the engineering log terminal"), "tracker ticks the objective")
	check(_tracker.get_lines().has("[ ] Tell Elias what the log says"), "report objective still open")
	await process_frames(2)
	check(is_equal_approx(_tracker.modulate.a, QuestTracker.FADED_ALPHA),
		"tracker fades while the player stands behind it at the terminal (alpha %.2f)" % _tracker.modulate.a)
	await _wait_cooldown()
	await _press_e()
	check(not _hud.is_message_open(), "log closes")


func _test_report_completes_quest() -> void:
	section("report to Elias")
	await _wait_cooldown()
	await _stand_below(_elias, 25.0)
	await process_frames(2)
	check(is_equal_approx(_tracker.modulate.a, 1.0), "tracker opaque again when the player walks away")
	await _press_e()  # start: "Back again"
	await _press_e()  # finish typing
	await _press_e()  # continue to status
	await _press_e()  # finish typing
	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 2 and buttons[0].text.begins_with("1. The engineering log mentions")
		and buttons[1].text == "2. I'll leave you to it.",
		"signal question offered, quest offer hidden while active (got %d choices)" % buttons.size())

	await _press_e()  # ask about the signal
	check(_text().begins_with("You read that?"), "Elias answers")
	await _press_e()  # finish typing
	await _press_e()  # continue to report_thanks
	check(_text() == "And thanks for actually checking, Asel. That's more than upstairs ever did.",
		"quest-only thank-you line shown (got \"%s\")" % _text())
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_COMPLETED, "quest completed")
	check(StoryFlagManager.get_flag("power_draw_investigated") == true, "reward flag set")
	check(StoryFlagManager.get_flag("signal_disclosed") == true, "signal_disclosed set")
	check(RelationshipManager.get_bond("elias_voss") == 55, "sharing the log: bond +5")
	check(RelationshipManager.get_trust("elias_voss") == 60, "quest reward: trust +15 (45 -> 60)")
	check(_toast.get_lines().has("Elias Voss: Bond +5") and _toast.get_lines().has("Elias Voss: Trust +15"),
		"notices for both changes (got %s)" % str(_toast.get_lines()))
	check(_tracker.get_lines() == PackedStringArray(["Borrowed Power  COMPLETE"]),
		"tracker shows the quest as complete (got %s)" % str(_tracker.get_lines()))
	await _close_remaining_lines()
	check(not DialogueManager.is_dialogue_active, "dialogue closed")


func _test_after_completion() -> void:
	section("after completion")
	await get_tree().create_timer(QuestTracker.COMPLETED_DISPLAY_SECONDS + 0.3).timeout
	check(not _tracker.visible, "completed quest leaves the tracker after a few seconds")

	await _wait_cooldown()
	await _press_e()
	await _press_e()
	await _press_e()
	await _press_e()
	check(_toast.get_lines().is_empty(), "notices disappear after a few seconds")
	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 2 and buttons[0].text.begins_with("1. Off the record, Elias")
		and buttons[1].text == "2. I'll leave you to it.",
		"trust 60 unlocks the off-the-record question; quest offer and signal question gone (got %d)"
			% buttons.size())
	await _press_e()  # ask off the record
	check(_text().begins_with("Off the record? Whoever is transmitting knows our launch schedule."),
		"Elias shares his theory")
	await _close_remaining_lines()


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _press_e() -> void:
	tap_action(&"interact")
	await process_frames(2)


## Presses E until the dialogue closes (finishes typing and continues).
func _close_remaining_lines(max_presses: int = 8) -> void:
	for i: int in max_presses:
		if not DialogueManager.is_dialogue_active:
			return
		check(_box.get_choice_buttons().is_empty() or _box.is_typing(),
			"no unexpected choice while closing (line: \"%s\")" % _text())
		await _press_e()


func _wait_cooldown() -> void:
	await physics_frames(int(PlayerController.INTERACT_COOLDOWN * PHYSICS_FPS) + 2)


func _stand_below(target: Node2D, distance: float) -> void:
	_player.global_position = target.global_position + Vector2(0, distance)
	await physics_frames(3)


func _text() -> String:
	return (_box.get_node("%TextLabel") as Label).text
