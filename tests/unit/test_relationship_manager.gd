# Unit tests for RelationshipManager: starting values, changes, clamping,
# signals, tiers, checks and validation.
#   tests/run_tests.sh tests/unit/test_relationship_manager.gd
extends "res://tests/support/base_test.gd"

var _changes: Array[String] = []


func run_tests() -> void:
	RelationshipManager.relationship_changed.connect(
		func(npc_id: String, kind: String, old_value: int, new_value: int) -> void:
			_changes.append("%s %s %d->%d" % [npc_id, kind, old_value, new_value]))

	_test_starting_values()
	_test_changes_and_clamping()
	_test_invalid_input()
	_test_tiers_and_status()
	_test_checks()
	_test_validation()
	_test_reset()
	RelationshipManager.reset()


func _test_starting_values() -> void:
	section("starting values")
	RelationshipManager.reset()
	check(RelationshipManager.get_trust("elias_voss") == 40, "Elias trust 40 from data/npcs/elias_voss.json")
	check(RelationshipManager.get_bond("elias_voss") == 50, "Elias bond 50 from data/npcs/elias_voss.json")
	for npc_id: String in ["maya_chen", "nora_reyes", "daniel_kim"]:
		check(RelationshipManager.get_trust(npc_id) == 50 and RelationshipManager.get_bond(npc_id) == 50,
			"%s starts at 50/50 (no metadata file yet)" % npc_id)
	check(RelationshipManager.initial_value_from({"initial_relationships": {"trust": 150}}, "trust") == 100,
		"starting values above 100 are clamped")
	check(RelationshipManager.initial_value_from({"initial_relationships": {"trust": "x"}}, "trust") == 50,
		"non-numeric starting value falls back to 50")


func _test_changes_and_clamping() -> void:
	section("changes and clamping")
	RelationshipManager.reset()
	_changes.clear()
	check(RelationshipManager.modify_trust("elias_voss", 5) == 5, "modify_trust returns the applied change")
	check(RelationshipManager.get_trust("elias_voss") == 45, "trust 40 + 5 = 45")
	check(_changes == ["elias_voss trust 40->45"], "relationship_changed carries old and new value")

	check(RelationshipManager.modify_bond("elias_voss", 80) == 50, "bond +80 from 50 only applies +50")
	check(RelationshipManager.get_bond("elias_voss") == 100, "bond clamped to 100")
	_changes.clear()
	check(RelationshipManager.modify_bond("elias_voss", 5) == 0, "change at the limit returns 0")
	check(_changes.is_empty(), "no signal when the value does not change")

	check(RelationshipManager.modify_trust("elias_voss", -200) == -45, "trust -200 from 45 applies -45")
	check(RelationshipManager.get_trust("elias_voss") == 0, "trust clamped to 0")

	_changes.clear()
	var applied: int = RelationshipManager.apply_change({"npc_id": "maya_chen", "relationship": "bond", "change": 7.0})
	check(applied == 7 and RelationshipManager.get_bond("maya_chen") == 57,
		"apply_change accepts JSON numbers (7.0)")
	check(RelationshipManager.get_trust("maya_chen") == 50, "other value of the same NPC unchanged")
	check(RelationshipManager.get_bond("nora_reyes") == 50, "other NPCs unchanged")


func _test_invalid_input() -> void:
	section("invalid input")
	var logged: Dictionary = capture_log(func() -> int: return RelationshipManager.modify_trust("ghost_unit", 5))
	check(logged["result"] == 0 and has_message(logged["warnings"], ["'ghost_unit' is not a crew member"]),
		"unknown NPC: no change, warning")
	logged = capture_log(func() -> int: return RelationshipManager.change("elias_voss", "mood", 5))
	check(logged["result"] == 0 and has_message(logged["warnings"], ["unknown relationship type 'mood'"]),
		"unknown type: no change, warning")
	logged = capture_log(func() -> int: return RelationshipManager.get_value("ghost_unit", "trust"))
	check(logged["result"] == 50, "unknown NPC reads as 50")
	logged = capture_log(func() -> Dictionary: return RelationshipManager.get_relationship_status("ghost_unit"))
	check(logged["result"].is_empty(), "no status for an unknown NPC")


func _test_tiers_and_status() -> void:
	section("tiers and status")
	var expected: Dictionary = {0: "low", 25: "low", 26: "neutral", 50: "neutral",
		51: "good", 75: "good", 76: "high", 100: "high"}
	for value: int in expected:
		check(RelationshipManager.tier_for(value) == expected[value], "%d is %s" % [value, expected[value]])

	RelationshipManager.reset()
	RelationshipManager.modify_bond("elias_voss", 30)
	var status: Dictionary = RelationshipManager.get_relationship_status("elias_voss")
	check(status == {"trust": 40, "bond": 80, "trust_tier": "neutral", "bond_tier": "high"},
		"get_relationship_status() (got %s)" % str(status))


func _test_checks() -> void:
	section("checks (used by dialogue and quest conditions)")
	RelationshipManager.reset()
	var cases: Array = [
		[{"npc_id": "elias_voss", "type": "trust", "min": 40}, true, "min is inclusive"],
		[{"npc_id": "elias_voss", "type": "trust", "min": 41}, false, "below min fails"],
		[{"npc_id": "elias_voss", "type": "trust", "max": 40}, true, "max is inclusive"],
		[{"npc_id": "elias_voss", "type": "trust", "max": 39}, false, "above max fails"],
		[{"npc_id": "elias_voss", "type": "bond", "min": 50, "max": 60}, true, "inside a range"],
		[{"npc_id": "elias_voss", "type": "bond", "min": 60.0}, false, "JSON float bounds work"],
	]
	for case: Array in cases:
		check(RelationshipManager.check_met(case[0]) == case[1], case[2])


func _test_validation() -> void:
	section("validation")
	var good_check: Dictionary = {"npc_id": "elias_voss", "type": "trust", "min": 60.0}
	check(RelationshipManager.validate_check(good_check) == "", "valid check accepted")
	var bad_checks: Array = [
		[{"npc_id": "elias_voss", "type": "trust"}, "needs min and/or max"],
		[{"npc_id": "elias_voss", "type": "trust", "min": 5.5}, "min must be a whole number"],
		[{"npc_id": "elias_voss", "type": "trust", "max": -1}, "max must be a whole number from 0 to 100"],
		[{"npc_id": "elias_voss", "type": "trust", "min": 1, "above": 2}, "unknown field 'above'"],
		[{"type": "trust", "min": 1}, "npc_id must be a crew member"],
		["text", "must be an object"],
	]
	for case: Array in bad_checks:
		var problem: String = RelationshipManager.validate_check(case[0])
		check(case[1] in problem, "check rejects: %s (got \"%s\")" % [case[1], problem])

	var good_change: Dictionary = {"type": "change_relationship", "npc_id": "maya_chen",
		"relationship": "bond", "change": -3.0}
	check(RelationshipManager.validate_change(good_change) == "", "valid change accepted (negative, JSON float)")
	var bad_changes: Array = [
		[{"npc_id": "maya_chen", "relationship": "bond", "change": 2.5}, "change must be a non-zero whole number"],
		[{"npc_id": "maya_chen", "relationship": "love", "change": 2}, "relationship must be trust or bond"],
		[{"npc_id": "maya_chen", "relationship": "bond"}, "change must be a non-zero whole number"],
	]
	for case: Array in bad_changes:
		var problem: String = RelationshipManager.validate_change(case[0])
		check(case[1] in problem, "change rejects: %s (got \"%s\")" % [case[1], problem])


func _test_reset() -> void:
	section("reset")
	RelationshipManager.modify_trust("elias_voss", 30)
	RelationshipManager.reset()
	check(RelationshipManager.get_trust("elias_voss") == 40, "reset restores starting values")
