# Shared base for headless tests. A test extends this file, overrides
# run_tests() and calls check(). It runs as a node under /root, so it
# survives scene changes, and autoloads (GameState, ...) work as in the game.
# Run one test:  tests/run_tests.sh tests/unit/test_game_state.gd
# Run all tests: tests/run_tests.sh
extends Node

var root: Window = null

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	# Keep running while a test pauses the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = get_tree().root
	_main.call_deferred()


func _main() -> void:
	await run_tests()
	print("")
	print("%d/%d checks passed" % [_checks - _failures, _checks])
	get_tree().quit(1 if _failures > 0 or _checks == 0 else 0)


## Override in the test script. May use await.
func run_tests() -> void:
	pass


func section(title: String) -> void:
	print("-- " + title)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func physics_frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func process_frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


## Sends a press and release of an input action through the root viewport,
## the same path real key presses take to _gui_input()/_unhandled_input().
func tap_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


## Sends a key press and release (needed for controls that only read
## InputEventKey, e.g. Enter in a LineEdit).
func tap_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		root.push_input(event)


## Types text into the focused control one key event per character,
## like a player typing (emits LineEdit.text_changed).
func type_text(text: String) -> void:
	for i: int in text.length():
		for pressed: bool in [true, false]:
			var event: InputEventKey = InputEventKey.new()
			event.unicode = text.unicode_at(i)
			event.pressed = pressed
			root.push_input(event)


## Waits until SceneManager has finished a transition, at most max_frames.
func wait_for_transition(max_frames: int = 180) -> bool:
	for i: int in max_frames:
		await get_tree().process_frame
		if not SceneManager.is_transitioning:
			return true
	return false
