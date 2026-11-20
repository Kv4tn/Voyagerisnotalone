# Quest data format

Single source of truth for writing quest files. It describes what the game
supports **today**. Other fields from `design.md` §3.6 (items, location
unlocks, failure conditions, objective types such as `investigate` or
`complete_puzzle`) are planned and are **rejected by the validator** until
their systems exist.

Working example: `data/quests/ch1_main_borrowed_power.json`, given and
finished in `data/dialogues/elias_voss_prologue.json`.

## Checking your files

```
tests/run_tests.sh tests/content/test_dialogue_content.gd
```

The same check covers dialogues, quests, NPCs and NPC scenes.

## File and id

- File: `data/quests/<quest_id>.json`; `quest_id` must equal the file name.
- Format: `ch<chapter>_<main|side|crew>_<name>`, e.g. `ch1_main_borrowed_power`.

## Quest

```json
{
  "version": "1.0",
  "quest_id": "ch1_main_borrowed_power",
  "title": "Borrowed Power",
  "description": "Check the engineering log, then report back.",
  "category": "main",
  "chapter": 1,
  "prerequisites": {
    "story_flags": [{"flag": "met_elias", "value": true}]
  },
  "objectives": [
    {"objective_id": "read_log", "description": "Read the engineering log terminal",
     "type": "story_flag", "flag": "engineering_log_read", "value": true},
    {"objective_id": "report_to_elias", "description": "Tell Elias what the log says",
     "type": "talk_to", "target": "elias_voss"}
  ],
  "rewards": {
    "story_flags": [{"flag": "power_draw_investigated", "value": true}],
    "relationships": [{"npc_id": "elias_voss", "relationship": "trust", "change": 15}]
  }
}
```

| Field | Required | Meaning |
|---|---|---|
| `quest_id` | yes | Equals the file name |
| `title` | yes | Shown in the HUD tracker |
| `description` | no | For the journal (coming later) |
| `category` | no | `main`, `side`, `crew` or `tutorial` |
| `prerequisites` | no | `story_flags`, `quests_completed` (list of quest ids), `relationships` (same shape as the dialogue condition) |
| `objectives` | yes | At least one, and at least one not optional |
| `rewards` | no | `story_flags` set and `relationships` changes applied when the quest completes |
| `version`, `chapter`, `comment`, `$schema` | no | Informational |

Unknown fields are errors.

## Objectives

| Field | Required | Meaning |
|---|---|---|
| `objective_id` | yes | Unique in the quest |
| `description` | yes | Shown in the tracker as `[ ]` / `[x]` |
| `type` | yes | `story_flag` or `talk_to` |
| `flag`, `value` | for `story_flag` | Done when that flag has that value |
| `target` | for `talk_to` | npc_id the player reports to |
| `optional` | no | `true` = not needed to complete the quest |

- **`story_flag`** completes by itself. If the flag already has the value
  when the quest starts (the player read the log first), it counts at once.
  Any terminal, dialogue or puzzle that sets a flag can drive it.
- **`talk_to`** is completed by the dialogue effect `update_quest` in the
  target's dialogue (see below), so the writer decides which line counts.

The quest completes as soon as every non-optional objective is done; reward
flags are set at that moment.

## Connecting quests to dialogue

In a dialogue file (`docs/dialogue-format.md`):

```json
{"type": "start_quest", "quest_id": "ch1_main_borrowed_power"}
{"type": "update_quest", "quest_id": "ch1_main_borrowed_power",
 "objective_id": "report_to_elias", "status": "completed"}
```

and conditions on the quest status (`not_started`, `active`, `completed`,
`failed`):

```json
"conditions": {"quests": [{"quest_id": "ch1_main_borrowed_power", "status": "not_started"}]}
```

Typical pattern (Elias): offer the quest only while it is `not_started`;
show the report line only while it is `active` and complete the `talk_to`
objective there.

## Rules the content check enforces

- Structure as above; no unknown fields; supported types only.
- `quest_id` equals the file name; objective ids unique.
- Every flag in prerequisites, objectives and rewards is in the shared list.
- Relationship prerequisites and rewards name a crew member, `trust` or
  `bond`, and whole numbers in range. A failed quest gives no rewards.
- `talk_to` targets have `data/npcs/<id>.json`; `quests_completed` quests exist.
- Dialogues only reference quests and objectives that exist.
