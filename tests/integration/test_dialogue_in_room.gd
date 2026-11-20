# Integration test: talk to Elias in the prototype room with real input.
# Covers NPC prompt, dialogue box, typewriter skip, choice navigation,
# movement lock, repeat visit and the choice unlocked by the terminal.
#   tests/run_tests.sh tests/integration/test_dialogue_in_room.gd
extends "res://tests/support/base_test.gd"

const ROOM_SCENE: String = "res://scenes/prototype/prototype_room.tscn"
const PHYSICS_FPS: int = 60

var _room: Node = null
var _player: PlayerController = null
var _hud: GameHud = null
var _box: DialogueBox = null
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
	_elias = _room.get_node("EliasVoss") as NPCController
	await physics_frames(2)

	await _test_prompt()
	await _test_first_conversation()
	await _test_read_terminal()
	await _test_repeat_visit_with_signal_question()
	await _test_low_trust_hides_theory()


# ----------------------------------------------------------------------------

func _test_prompt() -> void:
	section("NPC prompt")
	check(_elias.display_name == "Elias Voss", "NPC name loaded from data/npcs/elias_voss.json")
	check(not _box.visible, "dialogue box hidden at start")
	await _stand_below(_elias, 25.0)
	check(_hud.get_prompt_text() == "[E] Talk to Elias Voss",
		"prompt shows '[E] Talk to Elias Voss' (got '%s')" % _hud.get_prompt_text())


func _test_first_conversation() -> void:
	section("first conversation")
	await _press_e()
	check(DialogueManager.is_dialogue_active, "E starts the dialogue")
	check(_box.visible and _box.is_typing(), "dialogue box opens and types the line")
	check(_speaker_text() == "Elias Voss", "speaker label shows Elias Voss")
	check(_hud.get_prompt_text() == "", "interaction prompt hidden during dialogue")
	check(_player.input_locked, "player input locked during dialogue")

	await _press_e()
	check(not _box.is_typing(), "E while typing shows the whole line")
	check(_body_label().visible_characters == -1, "all characters visible")
	check(_body_label().text == "So you're Asel. The commander they picked for Voyager.",
		"line uses the commander name (got \"%s\")" % _body_label().text)
	check(StoryFlagManager.get_flag("met_elias") == true, "met_elias set on the first greeting")

	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 2, "two choices shown (got %d)" % buttons.size())
	check(buttons.size() == 2 and root.gui_get_focus_owner() == buttons[0], "first choice focused")
	check(_hint_text() == DialogueBox.HINT_CHOOSE, "hint explains how to choose")

	var before: Vector2 = _player.global_position
	Input.action_press("move_down")
	await physics_frames(20)
	Input.action_release("move_down")
	check(_player.global_position.distance_to(before) < 0.5, "player cannot walk away mid-dialogue")

	tap_action(&"ui_down")
	await process_frames(2)
	check(buttons.size() == 2 and root.gui_get_focus_owner() == buttons[1], "Down moves focus to choice 2")
	await _press_e()
	check(_body_label().text.begins_with("Mission leadership has sent me"),
		"E picks the focused choice (skeptic branch)")

	await _finish_line_and_continue()
	buttons = _box.get_choice_buttons()
	check(buttons.size() == 2 and buttons[0].text == "1. I'll find out why."
		and buttons[1].text == "2. I'll leave you to it.",
		"signal question hidden before the log is read")

	await _press_e()  # finish typing
	tap_action(&"ui_down")
	await process_frames(2)
	await _press_e()  # choose "I'll leave you to it."
	check(_body_label().text.begins_with("Now if you'll excuse me"), "goodbye line shown")
	await _press_e()
	check(_hint_text() == DialogueBox.HINT_END, "last line shows the close hint")
	await _press_e()
	check(not DialogueManager.is_dialogue_active and not _box.visible, "E on the last line closes the dialogue")
	check(not _player.input_locked, "player input unlocked")
	check(_hud.get_prompt_text() == "[E] Talk to Elias Voss", "prompt returns")
	await process_frames(3)
	check(not DialogueManager.is_dialogue_active, "closing press does not restart the dialogue")
	check(StoryFlagManager.get_flag("signal_disclosed") == false, "signal_disclosed still false")
	check(RelationshipManager.get_bond("elias_voss") == 55 and RelationshipManager.get_trust("elias_voss") == 40,
		"commenting on his tone: bond +5, trust unchanged")
	check(QuestManager.get_quest_status("ch1_main_borrowed_power") == QuestManager.STATUS_NOT_STARTED,
		"leaving does not start Elias's quest")


func _test_read_terminal() -> void:
	section("read the engineering log")
	await _wait_cooldown()
	var terminal: Terminal = _room.get_node("Terminal") as Terminal
	await _stand_below(terminal, 30.0)
	await _press_e()
	check(_hud.is_message_open(), "terminal message opens")
	check(StoryFlagManager.get_flag("engineering_log_read") == true, "terminal sets engineering_log_read")
	await _wait_cooldown()
	await _press_e()
	check(not _hud.is_message_open(), "terminal message closes")


func _test_repeat_visit_with_signal_question() -> void:
	section("repeat visit")
	await _wait_cooldown()
	await _stand_below(_elias, 25.0)
	await _press_e()
	await _press_e()
	check(_body_label().text.begins_with("Back again, Asel?"), "repeat visit skips the introduction")

	await _press_e()  # continue to status
	await _press_e()  # finish typing
	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 3 and buttons[0].text.begins_with("1. The engineering log mentions"),
		"signal question appears after reading the log (got %d choices)" % buttons.size())
	await _press_e()  # choose the focused first choice
	check(_body_label().text.begins_with("You read that?"), "signal answer shown")
	check(StoryFlagManager.get_flag("signal_disclosed") == true, "signal_disclosed set")

	await _finish_line_and_continue()
	await _press_e()
	await _press_e()
	check(not DialogueManager.is_dialogue_active, "dialogue closed after goodbye")
	check(QuestManager.get_quest_status("ch1_main_borrowed_power") == QuestManager.STATUS_NOT_STARTED,
		"asking about the signal without the quest leaves the quest unstarted")


func _test_low_trust_hides_theory() -> void:
	section("low trust hides the off-the-record question")
	check(RelationshipManager.get_trust("elias_voss") == 40, "trust still 40 without the quest")
	await _wait_cooldown()
	await _press_e()
	await _press_e()
	await _press_e()
	await _press_e()
	var buttons: Array[Button] = _box.get_choice_buttons()
	check(buttons.size() == 1 and buttons[0].text == "1. I'll leave you to it.",
		"trust 40 < 60: theory hidden even though the signal is disclosed (got %d)" % buttons.size())
	await _press_e()
	await _press_e()
	await _press_e()
	check(not DialogueManager.is_dialogue_active, "dialogue closed")


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _press_e() -> void:
	tap_action(&"interact")
	await process_frames(2)


func _finish_line_and_continue() -> void:
	await _press_e()
	await _press_e()


func _wait_cooldown() -> void:
	await physics_frames(int(PlayerController.INTERACT_COOLDOWN * PHYSICS_FPS) + 2)


func _stand_below(target: Node2D, distance: float) -> void:
	_player.global_position = target.global_position + Vector2(0, distance)
	await physics_frames(3)


func _speaker_text() -> String:
	return (_box.get_node("%SpeakerLabel") as Label).text


func _body_label() -> Label:
	return _box.get_node("%TextLabel") as Label


func _hint_text() -> String:
	var hint: Label = _box.get_node("%HintLabel") as Label
	return hint.text if hint.visible else ""
