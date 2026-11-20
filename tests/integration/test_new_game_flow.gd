# Integration test: main menu -> name entry -> new game -> prototype room.
#   tests/run_tests.sh tests/integration/test_new_game_flow.gd
extends "res://tests/support/base_test.gd"

const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

var _game_state: Node = null
var _scene_manager: Node = null
var _story_flags: Node = null


func run_tests() -> void:
	_game_state = root.get_node("/root/GameState")
	_scene_manager = root.get_node("/root/SceneManager")
	_story_flags = root.get_node("/root/StoryFlagManager")

	check(ProjectSettings.get_setting("application/run/main_scene") == MENU_SCENE,
		"main scene is the main menu")

	get_tree().change_scene_to_file(MENU_SCENE)
	await process_frames(3)
	var menu: MainMenu = get_tree().current_scene as MainMenu
	check(menu != null, "main menu is the current scene")
	if menu == null:
		return

	await _test_menu_navigation(menu)
	await _test_invalid_name_is_rejected(menu)
	await _test_valid_name_starts_game(menu)


func _test_menu_navigation(menu: MainMenu) -> void:
	section("menu navigation")
	var new_game: Button = menu.get_node("%NewGameButton") as Button
	check(root.gui_get_focus_owner() == new_game, "New Game has keyboard focus")

	tap_action(&"ui_accept")
	await process_frames(2)
	check(menu.is_name_entry_open(), "Enter on New Game opens name entry")
	var name_edit: LineEdit = menu.get_node("%NameEdit") as LineEdit
	check(root.gui_get_focus_owner() == name_edit, "name field has focus")
	check(name_edit.is_editing(), "name field accepts typing right away")

	tap_action(&"ui_cancel")
	await process_frames(2)
	check(not menu.is_name_entry_open(), "Esc returns to the menu")
	check(root.gui_get_focus_owner() == new_game, "focus returns to New Game")

	tap_action(&"ui_accept")
	await process_frames(2)


func _test_invalid_name_is_rejected(menu: MainMenu) -> void:
	section("invalid name")
	var name_edit: LineEdit = menu.get_node("%NameEdit") as LineEdit
	check(name_edit.max_length == 20, "name field limited to 20 characters")

	type_text("A")
	tap_key(KEY_ENTER)
	await process_frames(2)
	check(menu.get_error_text() == "Name must be at least 2 characters.",
		"shows the length error (got \"%s\")" % menu.get_error_text())
	check(get_tree().current_scene == menu, "stays on the menu")
	check(not _scene_manager.is_transitioning, "no scene transition started")

	type_text("x")
	await process_frames(1)
	check(name_edit.text == "Ax", "typed character reaches the name field (got \"%s\")" % name_edit.text)
	check(menu.get_error_text() == "", "error clears when the player types")


func _test_valid_name_starts_game(menu: MainMenu) -> void:
	section("valid name starts the game")
	var name_edit: LineEdit = menu.get_node("%NameEdit") as LineEdit
	var started: Array = [0]
	var on_started: Callable = func() -> void: started[0] += 1
	_game_state.new_game_started.connect(on_started)
	var transition_events: Array = []
	var on_begin: Callable = func(path: String) -> void: transition_events.append("started:" + path)
	var on_end: Callable = func(path: String) -> void: transition_events.append("completed:" + path)
	_scene_manager.scene_transition_started.connect(on_begin)
	_scene_manager.scene_transition_completed.connect(on_end)

	# Progress from an earlier game that a new game must clear.
	StoryFlagManager.set_flag("met_elias", true)
	QuestManager.start_quest("ch1_main_borrowed_power")
	check(QuestManager.get_quest_status("ch1_main_borrowed_power") == QuestManager.STATUS_ACTIVE,
		"old game has an active quest")

	name_edit.clear()
	type_text("  Asel Nur  ")
	tap_key(KEY_ENTER)
	tap_key(KEY_ENTER)  # a second Enter must not start a second game
	await process_frames(1)
	check(_scene_manager.is_transitioning, "scene transition started")
	check(started[0] == 1, "new_game_started emitted exactly once (got %d)" % started[0])
	check(_game_state.player_name == "Asel Nur", "player name stored trimmed")
	check(_game_state.game_started, "game_started is true")
	check(_game_state.current_chapter == 1, "chapter is 1")
	check(_story_flags.get_flag("game_started") == true, "story flag game_started set")
	check(_story_flags.get_flag("player_name_set") == true, "story flag player_name_set set")
	check(QuestManager.get_quest_status("ch1_main_borrowed_power") == QuestManager.STATUS_NOT_STARTED,
		"new game resets quests")
	check(_story_flags.get_flag("met_elias") == false, "new game resets story flags from the old game")

	var finished: bool = await wait_for_transition()
	check(finished, "transition finished")
	var first_scene: String = _game_state.FIRST_SCENE_PATH
	check(transition_events == ["started:" + first_scene, "completed:" + first_scene],
		"SceneManager emitted started then completed once each (got %s)" % str(transition_events))
	check(not is_instance_valid(menu), "main menu was freed")
	check(get_tree().current_scene != null and get_tree().current_scene.name == &"PrototypeRoom",
		"prototype room is the current scene")
	if get_tree().current_scene == null:
		return

	var hud: GameHud = get_tree().current_scene.get_node("HUD") as GameHud
	check(hud.get_commander_text() == "CMDR ASEL NUR",
		"HUD shows the commander name (got \"%s\")" % hud.get_commander_text())
	var fade: ColorRect = _scene_manager.get_node("FadeLayer/Fade") as ColorRect
	check(is_zero_approx(fade.modulate.a), "fade overlay is transparent again")
	check(fade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade overlay no longer blocks the mouse")

	_game_state.new_game_started.disconnect(on_started)
	_scene_manager.scene_transition_started.disconnect(on_begin)
	_scene_manager.scene_transition_completed.disconnect(on_end)
