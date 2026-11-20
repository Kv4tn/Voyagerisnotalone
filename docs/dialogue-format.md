# Dialogue and NPC data format

This is the single source of truth for writing dialogue and NPC files.
It describes what the game supports **today**. Fields from `design.md` §3.5
that are not listed here (items, sounds, animations) are planned but
**rejected by the validator** until their systems exist. This page is updated
when they land. Quests: `docs/quest-format.md`.

Working example: `data/dialogues/elias_voss_prologue.json` with
`data/npcs/elias_voss.json` and `scenes/npcs/elias_voss.tscn`.

## Checking your files

Run after every change:

```
tests/run_tests.sh tests/content/test_dialogue_content.gd
```

It checks every file in `data/dialogues/`, `data/npcs/` and `scenes/npcs/`
and names the file and node of each problem. The game also refuses to open
an invalid dialogue and logs the same messages.

## IDs and file names

| What | Format | Example |
|---|---|---|
| NPC id | `<firstname>_<lastname>` | `elias_voss` |
| NPC metadata file | `data/npcs/<npc_id>.json` | `data/npcs/elias_voss.json` |
| Dialogue file | `data/dialogues/<dialogue_id>.json` | `data/dialogues/elias_voss_prologue.json` |
| dialogue_id | same as the file name, `<npc_id>_<context>` | `elias_voss_prologue` |
| node_id | `snake_case`, unique inside one file | `greeting_first` |
| Story flag | `snake_case`, must be in the shared list | `met_elias` |

Shared story flags are listed in `scripts/core/story_flag_manager.gd`
(`initialize_default_flags()`) and in `.kiro/steering/collaboration.md`.
To use a new flag, ask Dev 1 to add it to both; the content check fails on
flags that are not registered, which catches typos.

## NPC metadata file

```json
{
  "npc_id": "elias_voss",
  "display_name": "Elias Voss",
  "role": "Chief Engineer",
  "description": "Technically gifted, sarcastic, distrustful of mission leadership.",
  "dialogue_files": {
    "prologue": "res://data/dialogues/elias_voss_prologue.json"
  },
  "initial_relationships": {"trust": 50, "bond": 50}
}
```

| Field | Required | Meaning |
|---|---|---|
| `npc_id` | yes | Must equal the file name |
| `display_name` | yes | Shown as the speaker name and in "[E] Talk to ..." |
| `dialogue_files` | no | Story phase key → `res://` path of a dialogue file that must exist |
| `initial_relationships` | no | Starting `trust` and `bond` for crew members, whole numbers 0-100 (default 50) |
| `role`, `description` | no | Informational for now |

## NPC scene

1. In Godot: Scene → New Inherited Scene → `res://scenes/npcs/npc_base.tscn`.
2. Set `npc_id` on the root (e.g. `elias_voss`). `dialogue_key` defaults to
   `prologue` and selects the entry in `dialogue_files`.
3. Replace the `Placeholder` children with your sprite. Keep the
   `Interactable` and `CollisionShape2D` nodes.
4. Save as `scenes/npcs/<npc_id>.tscn` and place it in a room.

## Dialogue file

```json
{
  "version": "1.0",
  "dialogue_id": "elias_voss_prologue",
  "participants": ["elias_voss"],
  "comment": "Free text for writers.",
  "start_node": "greeting_again",
  "nodes": [ ... ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `dialogue_id` | yes | Equals the file name without `.json` |
| `start_node` | yes | `node_id` of the first node |
| `nodes` | yes | Non-empty list of nodes |
| `version`, `participants`, `metadata`, `comment`, `$schema` | no | Informational |

Any other field is an error, so typos such as `next_nod` are caught.

### Node

```json
{
  "node_id": "status",
  "speaker_id": "elias_voss",
  "text": "Voyager's grid holds at sixty-two percent.",
  "effects": [{"type": "set_flag", "flag": "met_elias", "value": true}],
  "responses": [
    {"text": "I'll find out.", "next_node": "goodbye"}
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `node_id` | yes | Unique in the file |
| `speaker_id` | yes | An NPC id with a metadata file, or `player` for the commander |
| `text` | yes | The line. `{player_name}` and `{npc_name}` are replaced |
| `responses` | no | Choices shown to the player (see below) |
| `next_node` | no | Where E continues when there are no choices. Omit it on the last line |
| `effects` | no | Run when the node is shown |
| `conditions` | no | The node is shown only if all conditions are true |
| `fallback_node` | with `conditions` | Node shown instead when the conditions fail |
| `comment` | no | Free text |

A node has either `responses` or `next_node`, never both. A node with
neither is the last line; E closes the dialogue.

### Response (choice)

| Field | Required | Meaning |
|---|---|---|
| `text` | yes | Choice text, non-empty |
| `next_node` | yes | Node shown after picking it |
| `conditions` | no | The choice is hidden unless all conditions are true |
| `effects` | no | Run when the player picks it |
| `response_id`, `comment` | no | Informational |

Choices are numbered in the order they appear, after hidden ones are
removed. Keep at least one choice without conditions so the player is never
stuck.

### Conditions (supported now)

```json
"conditions": {
  "story_flags": [
    {"flag": "engineering_log_read", "value": true}
  ],
  "quests": [
    {"quest_id": "ch1_main_borrowed_power", "status": "active"}
  ],
  "relationships": [
    {"npc_id": "elias_voss", "type": "trust", "min": 60}
  ]
}
```

Every entry must match. A flag that was never set counts as `false`.
Quest `status` is one of `not_started`, `active`, `completed`, `failed`.
A relationship entry needs `npc_id` (a crew member), `type` (`trust` or
`bond`) and `min` and/or `max` (whole numbers 0-100, both inclusive).

### Effects (supported now)

```json
{"type": "set_flag", "flag": "signal_disclosed", "value": true}
{"type": "start_quest", "quest_id": "ch1_main_borrowed_power"}
{"type": "update_quest", "quest_id": "ch1_main_borrowed_power",
 "objective_id": "report_to_elias", "status": "completed"}
{"type": "change_relationship", "npc_id": "elias_voss", "relationship": "trust", "change": 5}
```

- `set_flag`: `value` may be `true`, `false`, a number or a string.
- `start_quest`: starts the quest if its prerequisites hold.
- `update_quest`: completes one objective; `status` must be `"completed"`.
  Does nothing (with a warning) if the quest is not active, so guard the
  node with a `quests` condition.
- `change_relationship`: adds `change` (a non-zero whole number, may be
  negative) to a crew member's `trust` or `bond`. Values stay within
  0-100. The player sees a notice such as "Elias Voss: Trust +5".

### Trust and bond

Crew members: `maya_chen`, `elias_voss`, `nora_reyes`, `daniel_kim`.

- **Trust**: confidence in the player as commander. Raise it for competent,
  responsible choices; lower it for reckless or dismissive ones.
- **Bond**: personal connection. Raise it for empathy and shared interests.

A character can like the player and still doubt their leadership, so keep
the two separate. Tiers from design.md: 0-25 low, 26-50 neutral, 51-75
good, 76-100 high. Typical changes are ±3 to ±5 per dialogue choice and
±10 to ±15 for finishing a quest; a single choice should not swing a
value by more than 10.

## Patterns

**First visit vs. repeat visit.** Start on the repeat-visit node with a
condition on the "met" flag and fall back to the first-visit node, which
sets that flag:

```json
{"node_id": "greeting_again", "speaker_id": "elias_voss", "text": "Back again?",
 "conditions": {"story_flags": [{"flag": "met_elias", "value": true}]},
 "fallback_node": "greeting_first", "next_node": "status"},
{"node_id": "greeting_first", "speaker_id": "elias_voss", "text": "So you're {player_name}.",
 "effects": [{"type": "set_flag", "flag": "met_elias", "value": true}],
 "next_node": "status"}
```

**Choice unlocked by exploration.** Put a `story_flags` condition on the
response; a terminal or another dialogue sets the flag
(see `ask_signal` in the Elias file).

**Choice unlocked by trust.** Put a `relationships` condition on the
response (see `ask_theory` in the Elias file: trust 60 or more). Elias
starts at 40, so the player has to earn it.

## Rules the content check enforces

- The file parses as JSON (errors give the line number).
- Required fields are present; no unknown fields.
- Every `start_node`, `next_node`, `fallback_node` and response
  `next_node` points to an existing node.
- No duplicate `node_id`.
- Nodes with `conditions` have a `fallback_node`.
- Only supported condition keys and effect types are used.
- Quests and objectives used in conditions and effects exist.
- Relationship conditions and changes name a crew member, `trust` or `bond`,
  and whole numbers in range.
- `initial_relationships` contains only `trust` and `bond`, 0-100.
- `dialogue_id` equals the file name.
- Every `speaker_id` is `player` or has `data/npcs/<id>.json`.
- Every node can be reached from `start_node`.
- Every story flag is in the shared list.
- NPC metadata `npc_id` equals the file name; `dialogue_files` paths exist.
- Every scene in `scenes/npcs/` (except `npc_base.tscn`) is an NPC with
  valid metadata and the dialogue key it uses.

## In game

- E or Enter shows the full line while it is typing, then continues.
- Up/Down move between choices; E or Enter picks the highlighted one.
- The player cannot move while a dialogue is open.
