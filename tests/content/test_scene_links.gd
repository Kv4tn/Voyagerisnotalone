# Content check for room scenes and the doors between them.
# Run it after adding or editing a room in scenes/environments or scenes/prototype:
#   tests/run_tests.sh tests/content/test_scene_links.gd
# Rules are documented in docs/room-setup.md.
extends "res://tests/support/base_test.gd"

const ROOM_DIRS: PackedStringArray = ["res://scenes/prototype/", "res://scenes/environments/"]
const PLAYER_TO_HUD: Array = [&"interaction_target_changed", &"set_prompt"]
const HUD_TO_PLAYER: Array = [[&"message_opened", &"lock_input"], [&"message_closed", &"unlock_input"]]


func run_tests() -> void:
	StoryFlagManager.reset()
	var scenes: PackedStringArray = []
	for directory: String in ROOM_DIRS:
		_collect_scenes(directory, scenes)
	scenes.sort()
	check(not scenes.is_empty(), "at least one scene to check")
	var door_count: int = 0
	for path: String in scenes:
		section(path.trim_prefix("res://"))
		var root: Node = _instantiate(path)
		if root == null:
			continue
		_check_room(path, root)
		for door: Door in _find_all(root, func(node: Node) -> bool: return node is Door):
			_check_door(path, door)
			door_count += 1
		root.free()
	check(door_count > 0, "at least one door was checked (got %d)" % door_count)


# ----------------------------------------------------------------------------
# Rules
# ----------------------------------------------------------------------------

## A scene with a player must be a complete room: one Player, one HUD, wired.
func _check_room(path: String, root: Node) -> void:
	var file: String = path.get_file()
	var players: Array[Node] = _find_all(root, func(node: Node) -> bool: return node is PlayerController)
	if players.is_empty():
		return
	var huds: Array[Node] = _find_all(root, func(node: Node) -> bool: return node is GameHud)
	check(players.size() == 1, "%s: exactly one Player (got %d)" % [file, players.size()])
	check(huds.size() == 1, "%s: exactly one HUD (got %d)" % [file, huds.size()])
	if players.size() != 1 or huds.size() != 1:
		return
	var player: Node = players[0]
	var hud: Node = huds[0]
	check(player.is_connected(PLAYER_TO_HUD[0], Callable(hud, PLAYER_TO_HUD[1])),
		"%s: Player.%s -> HUD.%s" % [file, PLAYER_TO_HUD[0], PLAYER_TO_HUD[1]])
	for link: Array in HUD_TO_PLAYER:
		check(hud.is_connected(link[0], Callable(player, link[1])),
			"%s: HUD.%s -> Player.%s" % [file, link[0], link[1]])


func _check_door(path: String, door: Door) -> void:
	var label: String = "%s/%s" % [path.get_file(), door.name]
	check(not door.destination_name.is_empty(), "%s: destination_name is set" % label)
	if not door.required_flag.is_empty():
		check(StoryFlagManager.has_flag(door.required_flag),
			"%s: required_flag '%s' is in the shared list" % [label, door.required_flag])
		check(not door.locked_message.is_empty(), "%s: locked_message is set" % label)
	if door.target_scene.is_empty() or not ResourceLoader.exists(door.target_scene):
		check(false, "%s: target_scene exists (got '%s')" % [label, door.target_scene])
		return
	check(door.target_scene != path, "%s: target_scene is another room" % label)
	var target: Node = _instantiate(door.target_scene)
	if target == null:
		return
	var marker: Marker2D = SceneManager.find_spawn_point(target, door.spawn_point_name)
	check(marker != null, "%s: %s has a Marker2D named '%s'"
		% [label, door.target_scene.get_file(), door.spawn_point_name])
	check(not _find_all(target, func(node: Node) -> bool: return node is PlayerController).is_empty(),
		"%s: %s has a Player" % [label, door.target_scene.get_file()])
	target.free()


# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

func _collect_scenes(directory: String, into: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "tscn":
			into.append(directory + file)
	for sub: String in DirAccess.get_directories_at(directory):
		_collect_scenes(directory + sub + "/", into)


## Instantiates without adding to the tree, so no _ready() and no autoload side effects.
func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path) as PackedScene
	var root: Node = scene.instantiate() if scene != null else null
	check(root != null, "%s loads and instantiates" % path.get_file())
	return root


func _find_all(root: Node, predicate: Callable) -> Array[Node]:
	var found: Array[Node] = []
	if predicate.call(root):
		found.append(root)
	for child: Node in root.get_children():
		found.append_array(_find_all(child, predicate))
	return found
