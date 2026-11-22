# Integration test: three-slot save screen, confirmations and Continue,
# driven with keys. Covers tasks 9.3 and 10.5 (REQ-31.5, 50.5-6, 51.2).
#   tests/run_tests.sh tests/integration/test_save_slots.gd
extends "res://tests/support/base_test.gd"

var _pause: PauseMenu = null
var _slots: SaveSlotsPanel = null


func run_tests() -> void:
	GameState.reset_game()
	GameState.start_new_game("Asel")
	check(await wait_for_transition(), "new game started")
	_pause = get_tree().current_scene.get_node("HUD/PauseMenu")
	_slots = _pause.get_slots_panel()

	await _test_unsaved_progress_and_leave_confirmation()
	await _test_save_to_empty_slots()
	await _test_overwrite_confirmation()
	await _test_delete_confirmation()
	await _test_focus_stays_in_dialogs()
	await _test_longest_name_fits()
	await _test_leave_without_confirmation_after_saving()
	await _test_main_menu_load()


# ----------------------------------------------------------------------------

func _test_unsaved_progress_and_leave_confirmation() -> void:
	section("unsaved progress asks before leaving")
	check(not SaveManager.has_unsaved_progress(), "a fresh new game has nothing unsaved")
	StoryFlagManager.set_flag("met_elias", true)
	check(SaveManager.has_unsaved_progress(), "a story flag change is unsaved progress")

	await _press(&"ui_cancel")
	check(_pause.is_open(), "pause menu open")
	check(_pause.get_status_text() == "No saved games yet.\nUnsaved progress.", "status warns about unsaved progress")
	var menu_button: Button = _pause.get_node("%MainMenuButton")
	menu_button.grab_focus()
	await _press(&"ui_accept")
	var confirm: ConfirmDialog = _pause.get_confirm_dialog()
	check(confirm.is_open(), "Main Menu asks for confirmation")
	check(confirm.get_message() == "Return to the main menu? Progress since your last save will be lost.",
		"confirmation explains the loss")
	check(root.gui_get_focus_owner() == confirm.get_node("%NoButton"), "Cancel is focused, so Enter is safe")
	await _press(&"ui_cancel")
	check(not confirm.is_open() and _pause.is_open(), "Esc cancels and stays in the pause menu")
	check(get_tree().current_scene.name == &"PrototypeRoom" and not SceneManager.is_transitioning, "still in the game")
	check(root.gui_get_focus_owner() == menu_button, "focus returns to Main Menu")


func _test_save_to_empty_slots() -> void:
	section("save to empty slots")
	(_pause.get_node("%SaveButton") as Button).grab_focus()
	await _press(&"ui_accept")
	check(_slots.is_open() and _slots.get_mode() == SaveSlotsPanel.MODE_SAVE, "save screen open")
	for slot: int in [1, 2, 3]:
		check(_slots.get_slot_button(slot).text == "Slot %d   Empty" % slot, "slot %d shown as empty" % slot)
		check(not _slots.get_slot_button(slot).disabled, "empty slot %d can be saved to" % slot)
		check(not _slots.get_delete_button(slot).visible, "no Delete on empty slot %d" % slot)

	await _press(&"ui_accept")  # slot 1, empty: no confirmation
	check(SaveManager.has_save(1) and not _slots.is_open(), "saved to slot 1 without asking")
	check(_pause.get_status_text().begins_with("Saved to slot 1.\nLast save: slot 1 · CMDR ASEL"), "status confirms")

	await _open_save_screen()
	await _press(&"ui_down")
	check(root.gui_get_focus_owner() == _slots.get_slot_button(2), "Down moves to slot 2")
	await _press(&"ui_accept")
	check(SaveManager.has_save(2), "saved to slot 2")
	check(SaveManager.get_latest_slot() == 2, "slot 2 is now the latest save")


func _test_overwrite_confirmation() -> void:
	section("overwrite asks first")
	await _open_save_screen()
	var row: String = _slots.get_slot_button(2).text
	check(row.begins_with("Slot 2   CMDR ASEL · Ch 1 · 0:") and row.contains(" · 20"),
		"filled slot shows commander, chapter, playtime and date (got \"%s\")" % row)
	check(_slots.text_fits(2), "row text is not clipped")
	check(is_equal_approx(_slots.get_slot_button(1).size.x, _slots.get_slot_button(3).size.x),
		"filled and empty rows have the same width")
	check(_slots.get_delete_button(2).visible, "filled slot has Delete")
	var before: String = FileAccess.get_file_as_string(SaveManager.slot_path(2))

	StoryFlagManager.set_flag("signal_disclosed", true)
	_slots.get_slot_button(2).grab_focus()
	await _press(&"ui_accept")
	var confirm: ConfirmDialog = _slots.get_confirm_dialog()
	check(confirm.is_open() and confirm.get_message() == "Overwrite slot 2?", "overwrite asks")
	await _press(&"ui_accept")  # Cancel is focused
	check(not confirm.is_open() and _slots.is_open(), "Cancel keeps the slot screen open")
	check(FileAccess.get_file_as_string(SaveManager.slot_path(2)) == before, "slot 2 unchanged after Cancel")
	check(root.gui_get_focus_owner() == _slots.get_slot_button(2), "focus back on slot 2")

	await _press(&"ui_accept")
	await _press(&"ui_right")  # Overwrite
	await _press(&"ui_accept")
	var data: Dictionary = SaveManager.parse_save_text(FileAccess.get_file_as_string(SaveManager.slot_path(2)))["data"]
	check(not data.is_empty() and data["story_data"]["flags"]["signal_disclosed"] == true,
		"slot 2 overwritten with the new progress")
	check(not _slots.is_open() and _pause.get_status_text().begins_with("Saved to slot 2."), "back in the pause menu")


func _test_delete_confirmation() -> void:
	section("delete asks first")
	await _open_save_screen()
	_slots.get_slot_button(3).grab_focus()
	await _press(&"ui_accept")  # save to empty slot 3
	check(SaveManager.has_save(3), "slot 3 saved")

	await _open_save_screen()
	_slots.get_slot_button(3).grab_focus()
	await _press(&"ui_right")
	check(root.gui_get_focus_owner() == _slots.get_delete_button(3), "Right moves to Delete")
	await _press(&"ui_accept")
	var confirm: ConfirmDialog = _slots.get_confirm_dialog()
	check(confirm.get_message() == "Delete slot 3? This cannot be undone.", "delete asks")
	await _press(&"ui_cancel")
	check(SaveManager.has_save(3), "Esc keeps slot 3")
	await _press(&"ui_accept")
	await _press(&"ui_right")
	await _press(&"ui_accept")
	check(not SaveManager.has_save(3), "Delete removes slot 3")
	check(_slots.get_slot_button(3).text == "Slot 3   Empty" and not _slots.get_delete_button(3).visible,
		"slot 3 shown as empty again")
	check(_slots.get_status_text() == "Slot 3 deleted.", "status confirms the deletion")
	check(root.gui_get_focus_owner() == _slots.get_slot_button(3), "focus on the emptied slot")
	await _press(&"ui_cancel")
	check(not _slots.is_open() and _pause.is_open(), "Esc closes the slot screen, pause menu stays")
	check(root.gui_get_focus_owner() == _pause.get_node("%ResumeButton"), "focus back on Resume")


func _test_focus_stays_in_dialogs() -> void:
	section("arrows and Tab stay inside dialogs")
	await _open_save_screen()
	var inside_slots: Array = [_slots.get_slot_button(1), _slots.get_slot_button(2), _slots.get_slot_button(3),
		_slots.get_delete_button(1), _slots.get_delete_button(2), _slots.get_node("%BackButton")]
	var escaped: Array[String] = []
	for action: StringName in [&"ui_up", &"ui_up", &"ui_left", &"ui_down", &"ui_down", &"ui_down", &"ui_right",
			&"ui_focus_next", &"ui_focus_next", &"ui_focus_prev", &"ui_down"]:
		await _press(action)
		if not root.gui_get_focus_owner() in inside_slots:
			escaped.append("%s -> %s" % [action, str(root.gui_get_focus_owner())])
	check(escaped.is_empty(), "focus never leaves the slot screen %s" % str(escaped))

	_slots.get_slot_button(1).grab_focus()
	await _press(&"ui_accept")  # overwrite slot 1 -> confirm
	var confirm: ConfirmDialog = _slots.get_confirm_dialog()
	var inside_confirm: Array = [confirm.get_node("%NoButton"), confirm.get_node("%YesButton")]
	escaped.clear()
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		await _press(action)
		if not root.gui_get_focus_owner() in inside_confirm:
			escaped.append("%s -> %s" % [action, str(root.gui_get_focus_owner())])
	check(escaped.is_empty(), "focus never leaves the confirm dialog %s" % str(escaped))
	await _press(&"ui_cancel")
	await _press(&"ui_cancel")


func _test_leave_without_confirmation_after_saving() -> void:
	section("leaving right after a save")
	check(_pause.is_open() and not SaveManager.has_unsaved_progress(), "nothing unsaved")
	(_pause.get_node("%MainMenuButton") as Button).grab_focus()
	await _press(&"ui_accept")
	check(not _pause.get_confirm_dialog().is_open(), "no confirmation")
	check(await wait_for_transition(), "main menu loaded")


func _test_longest_name_fits() -> void:
	section("longest commander name fits")
	GameState.set_player_name("ABCDEFGHIJKLMNOPQRSW")  # 20 characters, the maximum
	GameState.game_time = 35999.0
	await _open_save_screen()
	_slots.get_slot_button(3).grab_focus()
	await _press(&"ui_accept")  # empty slot 3: saves without asking
	check(SaveManager.has_save(3), "saved the long name to slot 3")
	await _open_save_screen()
	await process_frames(2)
	check(_slots.text_fits(3), "a 20-character name with 9:59:59 playtime fits (\"%s\")"
		% _slots.get_slot_button(3).text)
	await _press(&"ui_cancel")
	check(_pause.is_open() and not _slots.is_open(), "back in the pause menu")
	check(SaveManager.delete_save(3), "cleanup")


func _test_main_menu_load() -> void:
	section("main menu: Continue and Load Game")
	# Damage slot 1 to see how the menu copes.
	var file: FileAccess = FileAccess.open(SaveManager.slot_path(1), FileAccess.WRITE)
	file.store_string("{\"version\": 1,")
	file.close()
	await _reload_menu()
	var menu: MainMenu = get_tree().current_scene as MainMenu
	var continue_button: Button = menu.get_node("%ContinueButton")
	var load_button: Button = menu.get_node("%LoadGameButton")
	check(continue_button.visible and load_button.visible, "Continue and Load Game shown")
	check(root.gui_get_focus_owner() == continue_button, "Continue focused")
	check(menu.get_save_info_text() == SaveManager.describe_slot(SaveManager.get_slot_info(2)),
		"info describes the latest valid save, slot 2")

	load_button.grab_focus()
	await _press(&"ui_accept")
	var slots: SaveSlotsPanel = menu.get_node("SaveSlotsPanel")
	check(slots.is_open() and slots.get_mode() == SaveSlotsPanel.MODE_LOAD, "Load Game opens the slot screen")
	check(slots.get_slot_button(1).disabled and slots.get_slot_button(1).text.begins_with("Slot 1   Damaged: not valid JSON"),
		"damaged slot 1 shown and disabled (got \"%s\")" % slots.get_slot_button(1).text)
	check(slots.get_slot_button(3).disabled, "empty slot 3 disabled")
	check(root.gui_get_focus_owner() == slots.get_slot_button(2), "first loadable slot focused")
	await _press(&"ui_cancel")
	check(not slots.is_open() and root.gui_get_focus_owner() == continue_button, "Esc returns to the menu")

	await _press(&"ui_accept")  # Continue
	check(await wait_for_transition(), "Continue loads")
	check(StoryFlagManager.get_flag("signal_disclosed") == true, "Continue loaded slot 2, the latest")
	check(not SaveManager.has_unsaved_progress(), "nothing unsaved right after loading")

	# All saves damaged: Continue disabled, the menu explains.
	for slot: int in [1, 2]:
		file = FileAccess.open(SaveManager.slot_path(slot), FileAccess.WRITE)
		file.store_string("garbage")
		file.close()
	GameState.reset_game()
	await _reload_menu()
	menu = get_tree().current_scene as MainMenu
	check((menu.get_node("%ContinueButton") as Button).disabled, "Continue disabled when every save is damaged")
	check(menu.get_save_info_text() == "All saved games are damaged. Open Load Game for details.", "menu explains")
	check(root.gui_get_focus_owner() == menu.get_node("%NewGameButton"), "New Game focused instead")


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _press(action: StringName) -> void:
	tap_action(action)
	await process_frames(2)


func _open_save_screen() -> void:
	if not _pause.is_open():
		await _press(&"ui_cancel")
	(_pause.get_node("%SaveButton") as Button).grab_focus()
	await _press(&"ui_accept")


func _reload_menu() -> void:
	get_tree().change_scene_to_file(GameState.MAIN_MENU_PATH)
	await process_frames(3)
