# Save file format

Saves live in `user://saves/slot_<n>.json` (slots 1-3). On macOS that is
`~/Library/Application Support/Godot/app_userdata/Voyagerisnotalone/saves/`;
exported builds use the platform's app-data folder. Implementation:
`scripts/core/save_manager.gd`. Tests write to `user://test_saves/` and never
touch real saves.

## Example (format version 1)

```json
{
	"playtime_seconds": 754.25,
	"player_data": {
		"chapter": 1,
		"current_scene": "res://scenes/prototype/prototype_room.tscn",
		"name": "Asel",
		"position": {"x": 400.0, "y": 250.0}
	},
	"quest_data": {
		"quests": [
			{"objectives_done": ["read_log"], "quest_id": "ch1_main_borrowed_power", "status": "active"}
		]
	},
	"relationship_data": {
		"elias_voss": {"bond": 50, "trust": 45},
		"maya_chen": {"bond": 50, "trust": 50}
	},
	"story_data": {
		"flags": {"engineering_log_read": true, "met_elias": true}
	},
	"timestamp": "2026-11-21T17:15:02",
	"version": 1
}
```

Files are tab-indented with sorted keys so they can be read and diffed.

## Fields

| Field | Meaning |
|---|---|
| `version` | Save format version. Checked before anything else |
| `timestamp` | Local time of saving, shown in slot lists |
| `playtime_seconds` | Total play time |
| `player_data` | Commander name, chapter (1-7), scene path, position |
| `story_data.flags` | Every story flag; values are true/false, numbers or text |
| `quest_data.quests` | Started quests: status (`active`, `completed`, `failed`) and finished objectives. Not-started quests are absent |
| `relationship_data` | Trust and bond (0-100) per crew member |

## Loading rules

- The whole file is validated first; if anything is wrong nothing is
  restored and the player sees the first problem. The log lists all of them.
- Checks: valid JSON object, known version, no unknown or missing fields,
  valid commander name, chapter 1-7, existing `res://` scene, numeric
  position, flag value types, existing quests and objectives, crew members
  only, trust/bond whole numbers 0-100.
- Flags, quests or crew members that a save does not mention keep their
  new-game values, so saves from before a content update still load.
- Loading restores state without signals: no relationship notices and no
  quest rewards are given again.
- Whole numbers come back as integers (JSON stores every number the same way).

## Versions

`SAVE_VERSION` in `save_manager.gd` is 1. A save with a higher version is
refused with "saved by a newer version of the game". When the format
changes: increase `SAVE_VERSION` and add a step to `_migrate()` that converts
the previous version, so old saves keep loading.

## Writing

The file is written to `slot_<n>.json.tmp` and then renamed over the old
save, so a crash while saving leaves the previous save intact.
