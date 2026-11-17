# Unit tests for GameState: name validation (REQ-3) and pause/resume (task 1.3).
#   tests/run_tests.sh tests/unit/test_game_state.gd
extends "res://tests/support/base_test.gd"

var _game_state: Node = null


func run_tests() -> void:
	_game_state = root.get_node("/root/GameState")
	_test_valid_names()
	_test_invalid_names()
	_test_set_player_name_trims_and_emits()
	await _test_pause_resume()


func _test_valid_names() -> void:
	section("valid names")
	for candidate: String in ["Al", "Asel", "Maya Chen", "Commander 7", "Асель", "Айгерім Нұр",
			"ABCDEFGHIJKLMNOPQRST"]:
		check(_game_state.get_player_name_error(candidate) == "", "'%s' accepted" % candidate)


func _test_invalid_names() -> void:
	section("invalid names and their messages")
	var cases: Dictionary = {
		"": "Enter a name.",
		"A": "Name must be at least 2 characters.",
		"ABCDEFGHIJKLMNOPQRSTU": "Name must be at most 20 characters.",
		"Bob!": "Use only letters, digits and single spaces between words.",
		"Maya  Chen": "Use only letters, digits and single spaces between words.",
		" Maya": "Use only letters, digits and single spaces between words.",
		"Maya_Chen": "Use only letters, digits and single spaces between words.",
	}
	for candidate: String in cases:
		var error: String = _game_state.get_player_name_error(candidate)
		check(error == cases[candidate], "'%s' -> \"%s\" (got \"%s\")" % [candidate, cases[candidate], error])
		check(not _game_state.validate_player_name(candidate), "'%s' fails validate_player_name()" % candidate)


func _test_set_player_name_trims_and_emits() -> void:
	section("set_player_name")
	var received: Array = []
	var on_changed: Callable = func(new_name: String) -> void: received.append(new_name)
	_game_state.player_name_changed.connect(on_changed)

	check(_game_state.set_player_name("  Nora Reyes  "), "accepts a name with outer spaces")
	check(_game_state.player_name == "Nora Reyes", "stores the trimmed name")
	check(received == ["Nora Reyes"], "emits player_name_changed once with the trimmed name")
	check(not _game_state.set_player_name("X"), "rejects an invalid name")
	check(_game_state.player_name == "Nora Reyes", "keeps the previous name after a rejection")

	_game_state.player_name_changed.disconnect(on_changed)


func _test_pause_resume() -> void:
	section("pause and resume")
	_game_state.pause_game()
	check(_game_state.is_paused and get_tree().paused, "pause_game() pauses the scene tree")
	_game_state.resume_game()
	check(not _game_state.is_paused and not get_tree().paused, "resume_game() unpauses the scene tree")
	_game_state.toggle_pause()
	check(get_tree().paused, "toggle_pause() pauses")
	_game_state.toggle_pause()
	check(not get_tree().paused, "toggle_pause() resumes")
	await process_frames(1)
