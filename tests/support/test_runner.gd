# Loads one test script at runtime and adds it under /root.
# Running a scene (instead of `godot -s`) makes the engine register
# autoloads before any game script is compiled, exactly as in the game.
#   godot --headless --path . res://tests/support/test_runner.tscn -- res://tests/unit/test_x.gd
extends Node

const EXIT_SETUP_ERROR: int = 2


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("no test script given; pass it after --")
		return

	var script: GDScript = load(args[0]) as GDScript
	if script == null or not script.can_instantiate():
		_fail("cannot load test script %s" % args[0])
		return

	var test: Node = script.new() as Node
	if test == null:
		_fail("%s does not extend Node" % args[0])
		return
	test.name = "Test"
	get_tree().root.add_child.call_deferred(test)


func _fail(message: String) -> void:
	push_error("test_runner: " + message)
	get_tree().quit(EXIT_SETUP_ERROR)
