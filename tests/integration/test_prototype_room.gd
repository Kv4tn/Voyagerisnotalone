# Headless integration test for the movement + terminal prototype.
# Run from the project root:
#   godot --headless --path . -s res://tests/integration/test_prototype_room.gd
# Exit code 0 = all checks passed, 1 = at least one failed.
extends SceneTree

const ROOM_SCENE: String = "res://scenes/prototype/prototype_room.tscn"
const PHYSICS_FPS: int = 60
const SPEED: float = 120.0

var _failures: int = 0
var _checks: int = 0
var _room: Node = null
var _player: PlayerController = null
var _hud: GameHud = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_input_map()

	_room = (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	_player = _room.get_node("Player") as PlayerController
	_hud = _room.get_node("HUD") as GameHud
	await _physics_frames(2)

	await _test_straight_movement_speed()
	await _test_diagonal_is_normalized()
	await _test_wall_blocks_movement()
	await _test_obstacle_blocks_movement()
	await _test_no_prompt_when_far()
	await _test_terminal_interaction()

	print("")
	print("%d/%d checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


# ----------------------------------------------------------------------------
# Tests
# ----------------------------------------------------------------------------

func _test_input_map() -> void:
	print("-- input map")
	var expected: Dictionary = {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
	}
	for action: String in expected:
		_check(InputMap.has_action(action), "action '%s' exists" % action)
		if not InputMap.has_action(action):
			continue
		var keys: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append((event as InputEventKey).physical_keycode)
		for key: int in expected[action]:
			_check(key in keys, "'%s' bound to %s" % [action, OS.get_keycode_string(key)])


func _test_straight_movement_speed() -> void:
	print("-- straight movement")
	_player.global_position = Vector2(320, 220)
	await _physics_frames(1)
	var start: Vector2 = _player.global_position
	Input.action_press("move_right")
	await _physics_frames(PHYSICS_FPS)
	Input.action_release("move_right")
	var moved: float = _player.global_position.x - start.x
	_check(absf(moved - SPEED) <= 3.0, "moves ~120 px in 1 s (moved %.1f)" % moved)
	_check(absf(_player.global_position.y - start.y) < 0.5, "no vertical drift")
	await _physics_frames(1)
	_check(_player.velocity == Vector2.ZERO, "stops when key released")


func _test_diagonal_is_normalized() -> void:
	print("-- diagonal movement")
	_player.global_position = Vector2(320, 180)
	await _physics_frames(1)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _physics_frames(2)
	var speed: float = _player.velocity.length()
	Input.action_release("move_right")
	Input.action_release("move_down")
	_check(absf(speed - SPEED) < 0.5, "diagonal speed is 120 px/s (got %.2f)" % speed)


func _test_wall_blocks_movement() -> void:
	print("-- wall collision")
	_player.global_position = Vector2(100, 180)
	await _physics_frames(1)
	Input.action_press("move_left")
	await _physics_frames(PHYSICS_FPS * 2)
	Input.action_release("move_left")
	var x: float = _player.global_position.x
	# Left wall inner edge is x=16, player body radius is 6.
	_check(x >= 21.0 and x <= 24.0, "stops at left wall (x=%.1f)" % x)


func _test_obstacle_blocks_movement() -> void:
	print("-- obstacle collision")
	_player.global_position = Vector2(140, 200)
	await _physics_frames(1)
	Input.action_press("move_right")
	await _physics_frames(PHYSICS_FPS * 2)
	Input.action_release("move_right")
	var x: float = _player.global_position.x
	# Crate spans x 184..216, player body radius is 6.
	_check(x >= 176.0 and x <= 179.0, "stops at crate (x=%.1f)" % x)


func _test_no_prompt_when_far() -> void:
	print("-- no prompt away from terminal")
	_player.global_position = Vector2(100, 300)
	await _physics_frames(3)
	_check(_player.current_target == null, "no interaction target")
	_check(_hud.get_prompt_text() == "", "prompt hidden")
	_push_interact()
	await _physics_frames(1)
	_check(not _hud.is_message_open(), "E does nothing with no target")


func _test_terminal_interaction() -> void:
	print("-- terminal interaction")
	var terminal: Terminal = _room.get_node("Terminal") as Terminal
	_player.global_position = terminal.global_position + Vector2(0, 30)
	await _physics_frames(3)
	_check(_player.current_target != null, "terminal detected in range")
	_check(_hud.get_prompt_text() == "[E] Use terminal",
		"prompt shows '[E] Use terminal' (got '%s')" % _hud.get_prompt_text())

	_push_interact()
	await _physics_frames(1)
	_check(_hud.is_message_open(), "E opens the message box")
	var title: Label = _hud.get_node("MessagePanel/Margin/VBox/TitleLabel") as Label
	_check(title.text == terminal.title, "message title is the terminal title")
	_check(_player.input_locked, "player input locked while message open")
	_check(_hud.get_prompt_text() == "", "prompt hidden while message open")

	var before: Vector2 = _player.global_position
	Input.action_press("move_down")
	await _physics_frames(30)
	Input.action_release("move_down")
	_check(_player.global_position.distance_to(before) < 0.5, "player cannot move while message open")

	await _physics_frames(int(PlayerController.INTERACT_COOLDOWN * PHYSICS_FPS) + 2)
	_push_interact()
	await _physics_frames(1)
	_check(not _hud.is_message_open(), "second E closes the message box")
	_check(not _player.input_locked, "player input unlocked after closing")
	_check(_hud.get_prompt_text() == "[E] Use terminal", "prompt returns after closing")

	# The closing press must not immediately reopen the box.
	await _physics_frames(2)
	_check(not _hud.is_message_open(), "closing press does not reopen the box")


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _physics_frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _push_interact() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	root.push_input(press)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	root.push_input(release)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)
