# Shared base for headless tests. A test extends this file, overrides
# run_tests() and calls check(). It runs as a node under /root, so it
# survives scene changes, and autoloads (GameState, ...) work as in the game.
#
# Errors: every push_error() and script error during a test is recorded.
# Errors a test provokes on purpose must be wrapped in capture_log(); any
# other error makes the test fail. Warnings outside capture_log() are only
# listed in the summary.
#
# Run one test:  tests/run_tests.sh tests/unit/test_game_state.gd
# Run all tests: tests/run_tests.sh
extends Node

var root: Window = null

## Tests never touch the player's real saves in user://saves/.
const TEST_SAVE_DIR: String = "user://test_saves/"

var _failures: int = 0
var _checks: int = 0
var _log: LogRecorder = LogRecorder.new()


## Records engine errors and warnings (Godot 4.5+ Logger API).
class LogRecorder extends Logger:
	const TYPE_WARNING: int = 1

	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = code if rationale.is_empty() else "%s: %s" % [code, rationale]
		# Script errors carry the useful res:// location; push_error() only
		# reports its own C++ file, so that one is left out.
		if file.begins_with("res://"):
			text += " (%s:%d)" % [file, line]
		_mutex.lock()
		if error_type == TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	## Returns and forgets everything recorded so far.
	func take() -> Dictionary:
		_mutex.lock()
		var result: Dictionary = {"errors": errors, "warnings": warnings}
		errors = PackedStringArray()
		warnings = PackedStringArray()
		_mutex.unlock()
		return result


func _ready() -> void:
	# Keep running while a test pauses the scene tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = get_tree().root
	OS.add_logger(_log)
	SaveManager.save_dir = TEST_SAVE_DIR
	clear_test_saves()
	_main.call_deferred()


func _main() -> void:
	await run_tests()
	var leftover: Dictionary = _log.take()
	for message: String in leftover["errors"]:
		check(false, "unexpected error: " + message)
	print("")
	for message: String in leftover["warnings"]:
		print("  note: warning outside capture_log(): " + message)
	print("%d/%d checks passed" % [_checks - _failures, _checks])
	clear_test_saves()
	OS.remove_logger(_log)
	get_tree().quit(1 if _failures > 0 or _checks == 0 else 0)


## Override in the test script. May use await.
func run_tests() -> void:
	pass


func clear_test_saves() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	for file: String in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR + file)


func section(title: String) -> void:
	_fail_on_unexpected_errors()
	print("-- " + title)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


## Runs action and returns {"result": <its return value>, "errors": [...],
## "warnings": [...]}. Logged messages count as expected and do not fail the test.
## GDScript lambdas capture locals by value, so return values from the lambda
## (read logged["result"]) instead of assigning to an outer variable.
func capture_log(action: Callable) -> Dictionary:
	_fail_on_unexpected_errors()
	var result: Variant = action.call()
	var logged: Dictionary = _log.take()
	logged["result"] = result
	return logged


## True when one of the messages contains every given fragment.
func has_message(messages: PackedStringArray, fragments: Array) -> bool:
	for message: String in messages:
		var all_found: bool = true
		for fragment: String in fragments:
			if not fragment in message:
				all_found = false
				break
		if all_found:
			return true
	return false


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


func _fail_on_unexpected_errors() -> void:
	var logged: Dictionary = _log.take()
	for message: String in logged["errors"]:
		check(false, "unexpected error: " + message)
	for message: String in logged["warnings"]:
		print("  note: warning: " + message)
