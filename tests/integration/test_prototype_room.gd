# Headless integration test for the movement + terminal prototype.
#   tests/run_tests.sh tests/integration/test_prototype_room.gd
extends "res://tests/support/base_test.gd"

const ROOM_SCENE: String = "res://scenes/prototype/prototype_room.tscn"
const PHYSICS_FPS: int = 60
const SPEED: float = 120.0

var _room: Node = null
var _player: PlayerController = null
var _hud: GameHud = null


func run_tests() -> void:
	_test_input_map()

	_room = (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	_player = _room.get_node("Player") as PlayerController
	_hud = _room.get_node("HUD") as GameHud
	await physics_frames(2)

	await _test_straight_movement_speed()
	await _test_diagonal_is_normalized()
	await _test_wall_blocks_movement()
	await _test_obstacle_blocks_movement()
	await _test_no_prompt_when_far()
	await _test_terminal_interaction()


func _test_input_map() -> void:
	section("input map")
	var expected: Dictionary = {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
	}
	for action: String in expected:
		check(InputMap.has_action(action), "action '%s' exists" % action)
		if not InputMap.has_action(action):
			continue
		var keys: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append((event as InputEventKey).physical_keycode)
		for key: int in expected[action]:
			check(key in keys, "'%s' bound to %s" % [action, OS.get_keycode_string(key)])


func _test_straight_movement_speed() -> void:
	section("straight movement")
	_player.global_position = Vector2(320, 220)
	await physics_frames(1)
	var start: Vector2 = _player.global_position
	Input.action_press("move_right")
	await physics_frames(PHYSICS_FPS)
	Input.action_release("move_right")
	var moved: float = _player.global_position.x - start.x
	check(absf(moved - SPEED) <= 3.0, "moves ~120 px in 1 s (moved %.1f)" % moved)
	check(absf(_player.global_position.y - start.y) < 0.5, "no vertical drift")
	await physics_frames(1)
	check(_player.velocity == Vector2.ZERO, "stops when key released")


func _test_diagonal_is_normalized() -> void:
	section("diagonal movement")
	_player.global_position = Vector2(320, 180)
	await physics_frames(1)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await physics_frames(2)
	var speed: float = _player.velocity.length()
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(absf(speed - SPEED) < 0.5, "diagonal speed is 120 px/s (got %.2f)" % speed)


func _test_wall_blocks_movement() -> void:
	section("wall collision")
	_player.global_position = Vector2(100, 180)
	await physics_frames(1)
	Input.action_press("move_left")
	await physics_frames(PHYSICS_FPS * 2)
	Input.action_release("move_left")
	var x: float = _player.global_position.x
	# Left wall inner edge is x=16, player body radius is 6.
	check(x >= 21.0 and x <= 24.0, "stops at left wall (x=%.1f)" % x)


func _test_obstacle_blocks_movement() -> void:
	section("obstacle collision")
	_player.global_position = Vector2(140, 200)
	await physics_frames(1)
	Input.action_press("move_right")
	await physics_frames(PHYSICS_FPS * 2)
	Input.action_release("move_right")
	var x: float = _player.global_position.x
	# Crate spans x 184..216, player body radius is 6.
	check(x >= 176.0 and x <= 179.0, "stops at crate (x=%.1f)" % x)


func _test_no_prompt_when_far() -> void:
	section("no prompt away from terminal")
	_player.global_position = Vector2(100, 300)
	await physics_frames(3)
	check(_player.current_target == null, "no interaction target")
	check(_hud.get_prompt_text() == "", "prompt hidden")
	tap_action(&"interact")
	await physics_frames(1)
	check(not _hud.is_message_open(), "E does nothing with no target")


func _test_terminal_interaction() -> void:
	section("terminal interaction")
	var terminal: Terminal = _room.get_node("Terminal") as Terminal
	_player.global_position = terminal.global_position + Vector2(0, 30)
	await physics_frames(3)
	check(_player.current_target != null, "terminal detected in range")
	check(_hud.get_prompt_text() == "[E] Use terminal",
		"prompt shows '[E] Use terminal' (got '%s')" % _hud.get_prompt_text())

	tap_action(&"interact")
	await physics_frames(1)
	check(_hud.is_message_open(), "E opens the message box")
	var title: Label = _hud.get_node("MessagePanel/Margin/VBox/TitleLabel") as Label
	check(title.text == terminal.title, "message title is the terminal title")
	check(_player.input_locked, "player input locked while message open")
	check(_hud.get_prompt_text() == "", "prompt hidden while message open")

	var before: Vector2 = _player.global_position
	Input.action_press("move_down")
	await physics_frames(30)
	Input.action_release("move_down")
	check(_player.global_position.distance_to(before) < 0.5, "player cannot move while message open")

	await physics_frames(int(PlayerController.INTERACT_COOLDOWN * PHYSICS_FPS) + 2)
	tap_action(&"interact")
	await physics_frames(1)
	check(not _hud.is_message_open(), "second E closes the message box")
	check(not _player.input_locked, "player input unlocked after closing")
	check(_hud.get_prompt_text() == "[E] Use terminal", "prompt returns after closing")

	# The closing press must not immediately reopen the box.
	await physics_frames(2)
	check(not _hud.is_message_open(), "closing press does not reopen the box")
