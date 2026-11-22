# Integration test: the full first-milestone flow with real input.
# New game -> name -> talk to Elias -> take the quest -> read the terminal ->
# pause and save -> main menu -> Continue -> state and position restored ->
# finish the quest -> load the save from the pause menu rewinds it.
#   tests/run_tests.sh tests/integration/test_save_load_flow.gd
extends "res://tests/support/base_test.gd"

const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const QUEST_ID: String = "ch1_main_borrowed_power"
const PHYSICS_FPS: int = 60
const SAVE_SPOT: Vector2 = Vector2(400, 250)

var _loaded_slots: Array[int] = []


func run_tests() -> void:
	SaveManager.game_loaded.connect(func(slot: int) -> void: _loaded_slots.append(slot))
	GameState.reset_game()
	get_tree().change_scene_to_file(MENU_SCENE)
	await process_frames(3)

	await _test_new_game_without_save()
	await _test_progress_and_pause_rules()
	await _test_save_from_pause_menu()
	await _test_main_menu_and_continue()
	await _test_load_from_pause_menu_rewinds()


# ----------------------------------------------------------------------------

func _test_new_game_without_save() -> void:
	section("no save yet")
	var menu: MainMenu = get_tree().current_scene as MainMenu
	check(not (menu.get_node("%ContinueButton") as Button).visible, "Continue hidden without a save")
	check(menu.get_save_info_text() == "", "no save info shown")
	tap_action(&"ui_accept")  # New Game
	await process_frames(2)
	type_text("Asel")
	tap_key(KEY_ENTER)
	check(await wait_for_transition(), "room loaded")
	check(get_tree().current_scene.name == &"PrototypeRoom", "in the prototype room")


func _test_progress_and_pause_rules() -> void:
	section("progress, and when Esc pauses")
	var room: Node = get_tree().current_scene
	var player: PlayerController = room.get_node("Player")
	var hud: GameHud = room.get_node("HUD")
	var pause: PauseMenu = room.get_node("HUD/PauseMenu")

	await _stand_below(room.get_node("EliasVoss"), 25.0)
	await _press(&"interact")  # start
	await _press(&"interact")  # finish typing
	await _press(&"interact")  # ask about the ship: trust +5
	tap_action(&"ui_cancel")
	await process_frames(2)
	check(not pause.is_open() and DialogueManager.is_dialogue_active, "Esc does not pause during a conversation")
	await _press(&"interact")  # finish typing status
	await _press(&"interact")  # "I'll find out why."
	await _close_dialogue()
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE, "quest taken")

	await _wait_cooldown()
	await _stand_below(room.get_node("Terminal"), 30.0)
	await _press(&"interact")
	check(hud.is_message_open(), "engineering log open")
	tap_action(&"ui_cancel")
	await process_frames(2)
	check(not hud.is_message_open() and not pause.is_open(), "Esc closes the log instead of pausing")
	check(QuestManager.is_objective_done(QUEST_ID, "read_log"), "read_log done")

	player.global_position = SAVE_SPOT
	await physics_frames(3)
	tap_action(&"ui_cancel")
	await process_frames(2)
	check(pause.is_open() and get_tree().paused, "Esc opens the pause menu and pauses the game")
	check(pause.get_status_text() == "No saved games yet.\nUnsaved progress.",
		"status: no saves, unsaved progress (got \"%s\")" % pause.get_status_text())
	check((pause.get_node("%LoadButton") as Button).disabled, "Load disabled without a save")
	check(root.gui_get_focus_owner() == pause.get_node("%ResumeButton"), "Resume focused")
	Input.action_press("move_left")
	await process_frames(20)
	Input.action_release("move_left")
	check(player.global_position == SAVE_SPOT, "player frozen while paused")


func _test_save_from_pause_menu() -> void:
	section("save from the pause menu")
	var pause: PauseMenu = get_tree().current_scene.get_node("HUD/PauseMenu")
	var slots: SaveSlotsPanel = pause.get_slots_panel()
	tap_action(&"ui_down")
	await process_frames(1)
	check(root.gui_get_focus_owner() == pause.get_node("%SaveButton"), "Down moves to Save Game")
	await _press(&"ui_accept")
	check(slots.is_open() and slots.get_mode() == SaveSlotsPanel.MODE_SAVE, "Save Game opens the slot screen")
	check(root.gui_get_focus_owner() == slots.get_slot_button(1), "slot 1 focused")
	await _press(&"ui_accept")
	check(SaveManager.has_save(1), "slot 1 written")
	check(not slots.is_open() and pause.is_open(), "back in the pause menu after saving")
	check(pause.get_status_text().begins_with("Saved to slot 1.\nLast save: slot 1 · CMDR ASEL · Chapter 1 · "),
		"status confirms the save (got \"%s\")" % pause.get_status_text())
	check(not SaveManager.has_unsaved_progress(), "no unsaved progress right after saving")
	check(not (pause.get_node("%LoadButton") as Button).disabled, "Load enabled after saving")
	check(not FileAccess.file_exists(SaveManager.slot_path(1) + ".tmp"), "no temporary file left behind")

	var parsed: Dictionary = SaveManager.parse_save_text(FileAccess.get_file_as_string(SaveManager.slot_path(1)))
	check(parsed["errors"].is_empty(), "written file is valid")
	var data: Dictionary = parsed["data"]
	check(data["player_data"]["position"] == {"x": SAVE_SPOT.x, "y": SAVE_SPOT.y}, "player position saved")
	check(data["quest_data"]["quests"] == [{"quest_id": QUEST_ID, "status": "active", "objectives_done": ["read_log"]}],
		"quest progress saved")
	check(data["relationship_data"]["elias_voss"] == {"trust": 45.0, "bond": 50.0}, "relationships saved")

	tap_action(&"ui_cancel")
	await process_frames(2)
	check(not pause.is_open() and not get_tree().paused, "Esc resumes")


func _test_main_menu_and_continue() -> void:
	section("main menu, then Continue")
	var pause: PauseMenu = get_tree().current_scene.get_node("HUD/PauseMenu")
	tap_action(&"ui_cancel")
	await process_frames(2)
	(pause.get_node("%MainMenuButton") as Button).grab_focus()
	await _press(&"ui_accept")
	check(not pause.get_confirm_dialog().is_open(), "no confirmation when nothing is unsaved")
	check(await wait_for_transition(), "back to the main menu")
	check(not get_tree().paused, "game unpaused")
	check(GameState.player_name == "" and QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_NOT_STARTED
		and RelationshipManager.get_trust("elias_voss") == 40, "leaving to the menu clears the session")

	var menu: MainMenu = get_tree().current_scene as MainMenu
	var continue_button: Button = menu.get_node("%ContinueButton")
	check(continue_button.visible and root.gui_get_focus_owner() == continue_button, "Continue shown and focused")
	check(menu.get_save_info_text().begins_with("CMDR ASEL · Chapter 1 · 0:00:"),
		"save info (got \"%s\")" % menu.get_save_info_text())

	_loaded_slots.clear()
	await _press(&"ui_accept")
	check(await wait_for_transition(), "saved scene loaded")
	check(_loaded_slots == [1], "game_loaded emitted once for slot 1")
	var room: Node = get_tree().current_scene
	var player: PlayerController = room.get_node("Player")
	await physics_frames(3)
	check(player.global_position == SAVE_SPOT, "player back at the saved spot (got %s)" % str(player.global_position))
	check(GameState.player_name == "Asel" and GameState.game_started, "commander restored")
	check((room.get_node("HUD") as GameHud).get_commander_text() == "CMDR ASEL", "HUD shows the name")
	check(QuestManager.is_objective_done(QUEST_ID, "read_log"), "quest progress restored")
	check((room.get_node("HUD/QuestTracker") as QuestTracker).get_lines().has("[x] Read the engineering log terminal"),
		"tracker shows the restored progress")
	check(RelationshipManager.get_trust("elias_voss") == 45, "trust restored")
	check((room.get_node("HUD/RelationshipToast") as RelationshipToast).get_lines().is_empty(),
		"no relationship notices for loaded values")

	# The restored game plays on: report to Elias and finish the quest.
	await _stand_below(room.get_node("EliasVoss"), 25.0)
	await _press(&"interact")
	await _press(&"interact")
	check(_line().begins_with("Back again, Asel?"), "Elias remembers the commander")
	await _press(&"interact")
	await _press(&"interact")
	await _press(&"interact")  # first choice: the 1420 MHz question
	await _close_dialogue()
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_COMPLETED, "quest completed after loading")
	check(RelationshipManager.get_trust("elias_voss") == 60, "reward applied once (45 + 15)")


func _test_load_from_pause_menu_rewinds() -> void:
	section("Load Game from the pause menu rewinds to the save")
	await _wait_cooldown()
	var pause: PauseMenu = get_tree().current_scene.get_node("HUD/PauseMenu")
	var slots: SaveSlotsPanel = pause.get_slots_panel()
	tap_action(&"ui_cancel")
	await process_frames(2)
	(pause.get_node("%LoadButton") as Button).grab_focus()
	_loaded_slots.clear()
	await _press(&"ui_accept")
	check(slots.is_open() and slots.get_mode() == SaveSlotsPanel.MODE_LOAD, "Load Game opens the slot screen")
	check(slots.get_slot_button(2).disabled and slots.get_slot_button(3).disabled, "empty slots cannot be loaded")
	await _press(&"ui_accept")  # slot 1
	var confirm: ConfirmDialog = slots.get_confirm_dialog()
	check(confirm.is_open() and confirm.get_message().begins_with("Load slot 1? Progress since your last save"),
		"loading over the finished quest asks first")
	tap_action(&"ui_right")
	await process_frames(1)
	check(root.gui_get_focus_owner() == confirm.get_node("%YesButton"), "Right moves to Load inside the dialog")
	await _press(&"ui_accept")  # Load
	check(await wait_for_transition(), "scene reloaded")
	check(_loaded_slots == [1], "game_loaded emitted")
	check(not get_tree().paused, "game unpaused after loading")
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE
		and RelationshipManager.get_trust("elias_voss") == 45, "progress after the save is undone")
	var player: PlayerController = get_tree().current_scene.get_node("Player")
	await physics_frames(2)
	check(player.global_position == SAVE_SPOT, "player at the saved spot")
	Input.action_press("move_right")
	await physics_frames(PHYSICS_FPS / 2)
	Input.action_release("move_right")
	check(player.global_position.x > SAVE_SPOT.x + 50.0, "player can move after loading")


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _press(action: StringName) -> void:
	tap_action(action)
	await process_frames(3)


func _close_dialogue() -> void:
	for i: int in 10:
		if not DialogueManager.is_dialogue_active:
			return
		await _press(&"interact")


func _wait_cooldown() -> void:
	await physics_frames(int(PlayerController.INTERACT_COOLDOWN * PHYSICS_FPS) + 2)


func _stand_below(target: Node2D, distance: float) -> void:
	var player: Node2D = get_tree().current_scene.get_node("Player")
	player.global_position = target.global_position + Vector2(0, distance)
	await physics_frames(3)


func _line() -> String:
	return (get_tree().current_scene.get_node("HUD/DialogueBox/VBox/TextLabel") as Label).text
