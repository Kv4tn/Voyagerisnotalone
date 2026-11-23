# Integration test: doors between the two prototype rooms, played with keys.
# Locked door, travel both ways with spawn markers, state carried across
# scenes, saving and loading in the second room, travel_to() guards.
# Covers tasks 1.4, 2.6 and 4.4.
#   tests/run_tests.sh tests/integration/test_doors.gd
extends "res://tests/support/base_test.gd"

const OFFICE: String = "res://scenes/prototype/prototype_room.tscn"
const REACTOR: String = "res://scenes/prototype/prototype_reactor_room.tscn"
const QUEST_ID: String = "ch1_main_borrowed_power"
const PHYSICS_FPS: int = 60

var _transitions: Array[String] = []


func run_tests() -> void:
	SceneManager.scene_transition_completed.connect(func(path: String) -> void: _transitions.append(path))
	GameState.reset_game()
	GameState.start_new_game("Asel")
	check(await wait_for_transition(), "new game in the office")

	await _test_locked_door()
	await _test_unlock_and_travel()
	await _test_return_trip_keeps_state()
	await _test_save_and_load_in_second_room()
	await _test_travel_guards()


# ----------------------------------------------------------------------------

func _test_locked_door() -> void:
	section("locked until Elias is met")
	var door: Door = get_tree().current_scene.get_node("DoorToReactor")
	var hud: GameHud = get_tree().current_scene.get_node("HUD")
	check(door.is_locked(), "door locked before meeting Elias")
	await _stand_left_of(door)
	check(hud.get_prompt_text() == "[E] Reactor Room (locked)", "prompt says locked (got '%s')" % hud.get_prompt_text())
	await _press(&"interact")
	check(hud.is_message_open(), "E shows a message instead of travelling")
	var body: Label = hud.get_node("MessagePanel/Margin/VBox/BodyLabel")
	check(body.text == "Reactor access needs engineering clearance. Elias Voss has the codes.", "locked message")
	check(not SceneManager.is_transitioning and get_tree().current_scene.scene_file_path == OFFICE, "still in the office")
	await _wait_cooldown()
	await _press(&"interact")
	check(not hud.is_message_open(), "message closes")


func _test_unlock_and_travel() -> void:
	section("talk to Elias, then use the door")
	var room: Node = get_tree().current_scene
	var door: Door = room.get_node("DoorToReactor")
	await _wait_cooldown()
	await _stand_below(room.get_node("EliasVoss"), 25.0)
	await _press(&"interact")
	await _press(&"interact")  # finish typing; met_elias is set on the greeting
	check(not door.is_locked(), "door unlocks when met_elias is set")
	await _press(&"interact")  # ask about the ship
	await _press(&"interact")  # finish typing status
	await _press(&"interact")  # take the quest
	await _close_dialogue()
	check(QuestManager.get_quest_status(QUEST_ID) == QuestManager.STATUS_ACTIVE, "quest active before travelling")

	await _wait_cooldown()
	await _stand_left_of(door)
	var hud: GameHud = room.get_node("HUD")
	check(hud.get_prompt_text() == "[E] Go to Reactor Room", "prompt updated after unlocking")
	_transitions.clear()
	await _press(&"interact")
	check(SceneManager.is_transitioning, "E on the open door starts a transition")
	check(await wait_for_transition(), "transition finished")
	check(_transitions == [REACTOR], "one transition, to the reactor room (got %s)" % str(_transitions))

	var reactor: Node = get_tree().current_scene
	var player: Node2D = reactor.get_node("Player")
	var marker: Marker2D = reactor.get_node("Spawn_from_office")
	check(player.global_position == marker.global_position,
		"player at Spawn_from_office (got %s)" % str(player.global_position))
	check((reactor.get_node("HUD") as GameHud).get_prompt_text() == "",
		"spawn is out of the door's reach, so no prompt right away")
	check((reactor.get_node("HUD") as GameHud).get_commander_text() == "CMDR ASEL", "HUD shows the commander")
	check((reactor.get_node("HUD/QuestTracker") as QuestTracker).get_lines().has("[ ] Read the engineering log terminal"),
		"quest tracker carried over")

	await _stand_below(reactor.get_node("ReactorTerminal"), 30.0)
	await _press(&"interact")
	var reactor_hud: GameHud = reactor.get_node("HUD")
	check(reactor_hud.is_message_open(), "reactor terminal works")
	await _wait_cooldown()
	await _press(&"interact")


func _test_return_trip_keeps_state() -> void:
	section("back to the office")
	var reactor: Node = get_tree().current_scene
	await _wait_cooldown()
	await _stand_right_of(reactor.get_node("DoorToOffice"))
	check((reactor.get_node("HUD") as GameHud).get_prompt_text() == "[E] Go to Engineering Office", "return door prompt")
	await _press(&"interact")
	check(await wait_for_transition(), "travelled back")
	var office: Node = get_tree().current_scene
	check(office.scene_file_path == OFFICE, "in the office again")
	check((office.get_node("Player") as Node2D).global_position == (office.get_node("Spawn_from_reactor") as Marker2D).global_position,
		"player at Spawn_from_reactor, next to the door")
	check(not is_instance_valid(reactor), "reactor room was freed")
	check(get_tree().get_nodes_in_group(PlayerController.GROUP).size() == 1, "exactly one player exists")

	# Elias remembers the first conversation after the round trip.
	await _wait_cooldown()
	await _stand_below(office.get_node("EliasVoss"), 25.0)
	await _press(&"interact")
	await _press(&"interact")
	check(_line().begins_with("Back again, Asel?"), "story flags survived the trip")
	await _close_dialogue()
	check(RelationshipManager.get_trust("elias_voss") == 45, "relationships survived the trip")


func _test_save_and_load_in_second_room() -> void:
	section("save in the reactor room, load from the office")
	await _wait_cooldown()
	await _stand_left_of(get_tree().current_scene.get_node("DoorToReactor"))
	await _press(&"interact")
	check(await wait_for_transition(), "in the reactor room")
	var player: Node2D = get_tree().current_scene.get_node("Player")
	player.global_position = Vector2(200, 260)
	await physics_frames(2)
	check(SaveManager.save_game(2), "saved to slot 2 in the reactor room")
	var info: Dictionary = SaveManager.get_slot_info(2)
	check(info["scene"] == REACTOR, "slot 2 remembers the reactor room")

	await _wait_cooldown()
	await _stand_right_of(get_tree().current_scene.get_node("DoorToOffice"))
	await _press(&"interact")
	check(await wait_for_transition(), "back in the office")
	check(SaveManager.load_game(2), "load slot 2")
	check(await wait_for_transition(), "loaded")
	check(get_tree().current_scene.scene_file_path == REACTOR, "loading returns to the reactor room")
	await physics_frames(2)
	check((get_tree().current_scene.get_node("Player") as Node2D).global_position == Vector2(200, 260),
		"saved position wins over the spawn marker")


func _test_travel_guards() -> void:
	section("travel_to guards")
	var logged: Dictionary = capture_log(func() -> bool:
		return SceneManager.travel_to("res://scenes/nowhere.tscn", "Spawn_x"))
	check(logged["result"] == false and has_message(logged["errors"], ["Scene not found", "nowhere.tscn"]),
		"missing scene refused with an error")
	check(not SceneManager.is_transitioning, "no transition started")

	check(SceneManager.travel_to(OFFICE, "Spawn_from_reactor"), "first travel starts")
	check(not SceneManager.travel_to(REACTOR, "Spawn_from_office"), "second travel during a transition refused")
	check(await wait_for_transition(), "first travel finished")
	check(get_tree().current_scene.scene_file_path == OFFICE, "the first destination won")

	# The marker warning is logged while the new scene loads, after travel_to()
	# returned, so the capture spans the whole transition.
	var travel: Dictionary = await capture_log_async(func() -> Array:
		var started: bool = SceneManager.travel_to(REACTOR, "No_such_marker")
		var arrived: bool = await wait_for_transition()
		return [started, arrived])
	check(travel["result"] == [true, true], "travel with a missing marker still goes and arrives")
	check(has_message(travel["warnings"], ["no Marker2D 'No_such_marker'", "prototype_reactor_room.tscn"]),
		"missing marker is reported with the scene (got %s)" % str(travel["warnings"]))
	var reactor: Node = get_tree().current_scene
	check((reactor.get_node("Player") as Node2D).global_position == Vector2(52, 180),
		"player keeps the scene's default position when the marker is missing")


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


func _place_player(position: Vector2) -> void:
	var player: Node2D = get_tree().current_scene.get_node("Player")
	player.global_position = position
	await physics_frames(3)


func _stand_below(target: Node2D, distance: float) -> void:
	await _place_player(target.global_position + Vector2(0, distance))


func _stand_left_of(target: Node2D) -> void:
	await _place_player(target.global_position + Vector2(-22, 0))


func _stand_right_of(target: Node2D) -> void:
	await _place_player(target.global_position + Vector2(22, 0))


func _line() -> String:
	return (get_tree().current_scene.get_node("HUD/DialogueBox/VBox/TextLabel") as Label).text
