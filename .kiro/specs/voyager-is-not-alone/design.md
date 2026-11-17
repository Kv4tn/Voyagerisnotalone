# Technical Design Document

## Overview

This document provides the complete technical design for **Voyager Is Not Alone**, a narrative-driven 2D pixel-art space RPG built in Godot 4.7. The game is designed for both a 30-45 minute hackathon MVP and eventual expansion to an 8-10 hour complete experience across seven chapters.

For detailed project goals, features, and story context, see the Executive Summary (section 1) below.

## Architecture

The game follows a modular, data-driven architecture with clear separation between core engine systems and content. The architecture supports a two-developer workflow with distinct responsibilities and uses Godot's singleton pattern for manager systems.

For complete architectural details, see System Architecture Overview (section 2) below.

## Components and Interfaces

The system is composed of multiple interconnected components including player control, NPC behavior, dialogue management, quest tracking, relationship systems, and more. Each component has well-defined interfaces and communication patterns.

For detailed component specifications, see Core Systems Design (section 3), Developer Collaboration Contracts (section 6), and Implementation Dependencies (section 8) below.

## Data Models

All game content is defined through JSON schemas including dialogues, quests, NPC metadata, puzzles, and save files. This data-driven approach enables content expansion without code changes.

For complete schema definitions and examples, see Data Schemas (section 4) below.

---

## 1. Executive Summary

**Voyager Is Not Alone** is a narrative-driven 2D pixel-art space RPG built in Godot 4.7, designed for both a 30-45 minute hackathon MVP and eventual expansion to an 8-10 hour complete experience across seven chapters.

### Architecture Philosophy

- **Data-Driven**: Dialogues, quests, puzzles, and narrative content are defined in external JSON files, enabling content expansion without code changes
- **Modular Systems**: Clean separation between core engine systems (player, NPC, dialogue, quests) and content (environments, assets, data files)
- **Two-Developer Workflow**: Clear boundaries between systems programming (Developer 1/Kiro-assisted) and content creation (Developer 2/Dias)
- **Scalable & Maintainable**: Typed GDScript, signal-based communication, composition over inheritance, testable architecture
- **Performance-Conscious**: 60 FPS target, object pooling, efficient scene management

### Technical Stack

- **Engine**: Godot 4.7
- **Language**: Typed GDScript with strict typing
- **Resolution**: 640×360 internal, scaled to display
- **Target Platforms**: Windows, macOS
- **Version Control**: Git with feature branch workflow

### Two-Developer Workflow

**Developer 1 (Kiro-Assisted)**:
- Core architecture and systems
- Player controller, interaction system
- Dialogue and quest engines
- Relationship and crew management
- Engineering simulation
- Puzzle framework
- Save/load system
- Testing and builds

**Developer 2 (Dias)**:
- Station environments and tilemaps
- Room layouts and decoration
- NPC placement and visual design
- Dialogue content (JSON files)
- Quest content (JSON files)
- Pixel art assets
- Environmental storytelling
- Scene assembly


## 2. System Architecture Overview

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                         GameState                           │
│         (Singleton - Autoload: res://scripts/core/)        │
│  • Story flags, chapter progress, persistent state          │
│  • Coordinates system initialization and shutdown           │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴───────────┬──────────────────────────┐
        │                      │                          │
┌───────▼──────┐    ┌──────────▼──────┐    ┌─────────────▼─────────┐
│ SceneManager │    │  AudioManager   │    │  SaveManager          │
│ (Singleton)  │    │  (Singleton)    │    │  (Singleton)          │
└──────┬───────┘    └─────────────────┘    └───────────────────────┘
       │
       │ manages
       ▼
┌──────────────────────────────────────────────────────────────┐
│                     Active Scene                             │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │  PlayerNode    │  │   NPCs       │  │  Environment     │ │
│  │ (CharacterBody2D)│  │ (NPCController)│  │  (TileMapLayer)  │ │
│  └────────┬───────┘  └──────┬───────┘  └──────────────────┘ │
│           │                 │                                │
│   ┌───────▼─────────────────▼──────┐                        │
│   │     InteractionSystem          │                        │
│   └───────┬────────────────────────┘                        │
└───────────┼─────────────────────────────────────────────────┘
            │
     ┌──────┴─────────┬──────────────┬─────────────────┐
     │                │              │                 │
┌────▼────────┐ ┌─────▼──────┐ ┌────▼──────────┐ ┌────▼──────────┐
│DialogueManager│ │QuestManager│ │RelationshipMgr│ │StoryFlagMgr │
│  (Singleton)  │ │ (Singleton)│ │  (Singleton)  │ │ (Singleton)  │
└───────────────┘ └────────────┘ └───────────────┘ └──────────────┘
```

### System Communication Patterns

**Singleton Autoloads** (for global state and managers):
- `GameState` - Master coordinator
- `SceneManager` - Scene transitions
- `DialogueManager` - Conversation system
- `QuestManager` - Quest tracking
- `RelationshipManager` - Trust/Bond tracking
- `StoryFlagManager` - Global story flags
- `SaveManager` - Persistence
- `AudioManager` - Sound and music
- `CrewTaskManager` - Crew assignments
- `EngineeringSimulation` - Physics/resources
- `PuzzleManager` - Puzzle state

**Signal-Based Communication** (for decoupled events):
- `dialogue_started`, `dialogue_ended`
- `quest_updated`, `quest_completed`
- `relationship_changed`
- `story_flag_set`
- `interaction_available`, `interaction_triggered`
- `scene_transition_started`, `scene_transition_completed`

**Direct Calls** (for immediate responses):
- Player input → PlayerController
- Collision detection → physics engine
- UI button presses → UI handlers

### Developer Boundaries

| System | Developer 1 | Developer 2 |
|--------|-------------|-------------|
| Core architecture | ✓ Owns | Uses |
| Player controller | ✓ Owns | Uses |
| NPC controller base | ✓ Owns | Extends |
| Dialogue engine | ✓ Owns | Provides data |
| Quest engine | ✓ Owns | Provides data |
| Environment scenes | Uses | ✓ Owns |
| Dialogue content (JSON) | - | ✓ Owns |
| Quest content (JSON) | - | ✓ Owns |
| Pixel art assets | - | ✓ Owns |
| Prefabs (doors, terminals) | ✓ Owns | Uses |


## 3. Core Systems Design

### 3.1 GameState & Scene Management

#### GameState Singleton

**Purpose**: Central coordinator for all game state, story progress, and system initialization.

**Location**: `res://scripts/core/game_state.gd` (Autoload as `GameState`)

**Responsibilities**:
- Initialize all manager systems on game start
- Track current chapter and story progress
- Provide global access to player name and profile
- Coordinate save/load operations
- Handle game-wide events (pause, resume, quit)

**Structure**:
```gdscript
# res://scripts/core/game_state.gd
extends Node
class_name GameStateClass

# Player data
var player_name: String = ""
var current_chapter: int = 1

# Game state
var is_paused: bool = false
var game_started: bool = false

# Initialization
func _ready() -> void:
	initialize_systems()

func initialize_systems() -> void:
	# Systems initialize themselves via autoload
	# GameState just confirms they're ready
	assert(DialogueManager != null, "DialogueManager not loaded")
	assert(QuestManager != null, "QuestManager not loaded")
	assert(RelationshipManager != null, "RelationshipManager not loaded")
	# ... other managers

func start_new_game(p_name: String) -> void:
	player_name = p_name
	current_chapter = 1
	game_started = true
	
	# Reset all managers
	QuestManager.reset()
	RelationshipManager.reset()
	StoryFlagManager.reset()
	
	# Load first scene
	SceneManager.transition_to("res://scenes/environments/station/residential_deck_01.tscn")

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
```

#### SceneManager Singleton

**Purpose**: Handle scene transitions with smooth loading and state preservation.

**Location**: `res://scripts/core/scene_manager.gd` (Autoload as `SceneManager`)

**Responsibilities**:
- Load and unload scenes
- Animated transitions (fade, wipe)
- Preserve player state across scenes
- Track scene history for debugging

**Structure**:
```gdscript
# res://scripts/core/scene_manager.gd
extends Node

signal scene_transition_started(scene_path: String)
signal scene_transition_completed(scene_path: String)

var current_scene: Node = null
var is_transitioning: bool = false

func transition_to(scene_path: String, transition_type: String = "fade") -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	scene_transition_started.emit(scene_path)
	
	# Play transition animation (fade out)
	await play_transition_out(transition_type)
	
	# Unload current scene
	if current_scene != null:
		current_scene.queue_free()
		await current_scene.tree_exited
	
	# Load new scene
	var new_scene_resource: PackedScene = load(scene_path)
	current_scene = new_scene_resource.instantiate()
	get_tree().root.add_child(current_scene)
	
	# Play transition animation (fade in)
	await play_transition_in(transition_type)
	
	is_transitioning = false
	scene_transition_completed.emit(scene_path)

func play_transition_out(type: String) -> void:
	# TODO: Implement fade/wipe animations
	await get_tree().create_timer(0.3).timeout

func play_transition_in(type: String) -> void:
	# TODO: Implement fade/wipe animations
	await get_tree().create_timer(0.3).timeout
```



### 3.2 Player Controller

**Purpose**: Handle player character movement, animation, and input.

**Location**: `res://scripts/player/player_controller.gd`

**Scene Setup**: Player node is a `CharacterBody2D` with:
- `CollisionShape2D` (circular, radius 8px)
- `AnimatedSprite2D` (4-directional animations)
- `InteractionArea` (Area2D for detecting interactables)

**Responsibilities**:
- Accept WASD/arrow key input
- Move at 120 px/s with normalized diagonal movement
- Animate based on movement direction
- Trigger interactions on E key
- Respect collision boundaries

**Implementation**:

```gdscript
# res://scripts/player/player_controller.gd
extends CharacterBody2D
class_name PlayerController

const SPEED: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

var last_direction: Vector2 = Vector2.DOWN
var is_in_dialogue: bool = false

func _ready() -> void:
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _physics_process(delta: float) -> void:
	if is_in_dialogue:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return
	
	# Get input direction
	var input_direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	
	# Normalize diagonal movement
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		last_direction = input_direction
		
		velocity = input_direction * SPEED
		play_walk_animation(input_direction)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()
	
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not is_in_dialogue:
		attempt_interaction()

func play_walk_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("walk_right")
		else:
			animated_sprite.play("walk_left")
	else:
		if direction.y > 0:
			animated_sprite.play("walk_down")
		else:
			animated_sprite.play("walk_up")

func play_idle_animation() -> void:
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			animated_sprite.play("idle_right")
		else:
			animated_sprite.play("idle_left")
	else:
		if last_direction.y > 0:
			animated_sprite.play("idle_down")
		else:
			animated_sprite.play("idle_up")

func attempt_interaction() -> void:
	var interactables = interaction_area.get_overlapping_areas()
	if interactables.size() > 0:
		var closest = interactables[0]
		if closest.has_method("interact"):
			closest.interact()

func _on_dialogue_started() -> void:
	is_in_dialogue = true

func _on_dialogue_ended() -> void:
	is_in_dialogue = false
```

**Input Map Configuration**:
```
move_left: A, Left Arrow
move_right: D, Right Arrow
move_up: W, Up Arrow
move_down: S, Down Arrow
interact: E
```


### 3.3 Interaction System

**Purpose**: Detect and execute interactions between player and world objects (NPCs, terminals, doors, items).

**Architecture**: Uses Godot's Area2D overlap detection with a common interface pattern.

**Components**:
1. **InteractionArea** (on Player): Area2D with 32px radius detecting interactables
2. **Interactable Interface**: Objects implement `interact()` method
3. **Context Prompt UI**: Shows "Press E to..." when near interactables

**Interactable Interface Pattern**:

```gdscript
# res://scripts/interfaces/interactable.gd
extends Area2D
class_name Interactable

signal interaction_triggered

@export var interaction_prompt: String = "Interact"

var player_in_range: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_interaction"):
		player_in_range = true
		show_prompt()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player_interaction"):
		player_in_range = false
		hide_prompt()

func interact() -> void:
	# Override in child classes
	interaction_triggered.emit()

func show_prompt() -> void:
	# Signal UI to show prompt
	InteractionUI.show_prompt(interaction_prompt)

func hide_prompt() -> void:
	InteractionUI.hide_prompt()
```

**Example: NPC Interactable**:

```gdscript
# res://scripts/npcs/npc_interactable.gd
extends Interactable
class_name NPCInteractable

@export var npc_id: String = "maya_chen"
@export var dialogue_file: String = "res://data/dialogues/maya_chen_prologue.json"

func _ready() -> void:
	super._ready()
	interaction_prompt = "Talk"

func interact() -> void:
	super.interact()
	DialogueManager.start_dialogue(dialogue_file, npc_id)
```

**Context Prompt UI**:

```gdscript
# res://scripts/ui/interaction_ui.gd
extends CanvasLayer

@onready var prompt_label: Label = $PromptPanel/PromptLabel

func show_prompt(text: String) -> void:
	prompt_label.text = "Press E to " + text
	$PromptPanel.visible = true

func hide_prompt() -> void:
	$PromptPanel.visible = false
```


### 3.4 NPC Behavior System

**Purpose**: Manage NPC state, movement, scheduling, and interactions.

**Architecture**: Base NPCController class with state machine pattern.

**NPCController Base Class**:

```gdscript
# res://scripts/npcs/npc_controller.gd
extends CharacterBody2D
class_name NPCController

enum State {
	IDLE,
	WALKING,
	DIALOGUE,
	WORKING
}

@export var npc_id: String = "maya_chen"
@export var display_name: String = "Maya Chen"
@export var walk_speed: float = 80.0
@export var schedule_file: String = ""

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var path_follow: PathFollow2D = null
@onready var interactable: NPCInteractable = $Interactable

var current_state: State = State.IDLE
var target_position: Vector2 = Vector2.ZERO
var path_points: Array[Vector2] = []
var current_path_index: int = 0
var schedule: Array = []

func _ready() -> void:
	if schedule_file != "":
		load_schedule(schedule_file)
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			play_idle_animation()
		
		State.WALKING:
			process_walking(delta)
		
		State.DIALOGUE:
			play_idle_animation()
		
		State.WORKING:
			play_working_animation()

func process_walking(delta: float) -> void:
	if path_points.is_empty():
		change_state(State.IDLE)
		return
	
	var target = path_points[current_path_index]
	var direction = (target - global_position).normalized()
	
	velocity = direction * walk_speed
	move_and_slide()
	
	play_walk_animation(direction)
	
	# Check if reached waypoint
	if global_position.distance_to(target) < 5.0:
		current_path_index += 1
		if current_path_index >= path_points.size():
			path_points.clear()
			current_path_index = 0
			change_state(State.IDLE)

func change_state(new_state: State) -> void:
	current_state = new_state

func walk_to(target: Vector2) -> void:
	target_position = target
	path_points = [target]
	current_path_index = 0
	change_state(State.WALKING)

func follow_path(points: Array[Vector2]) -> void:
	path_points = points
	current_path_index = 0
	if not path_points.is_empty():
		change_state(State.WALKING)

func load_schedule(file_path: String) -> void:
	# TODO: Load schedule JSON with time-based waypoints
	pass

func play_idle_animation() -> void:
	animated_sprite.play("idle_down")

func play_walk_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		animated_sprite.play("walk_right" if direction.x > 0 else "walk_left")
	else:
		animated_sprite.play("walk_down" if direction.y > 0 else "walk_up")

func play_working_animation() -> void:
	animated_sprite.play("working")

func _on_dialogue_started() -> void:
	change_state(State.DIALOGUE)

func _on_dialogue_ended() -> void:
	change_state(State.IDLE)
```

**Schedule System Concept**:

NPCs can have scheduled behaviors defined in JSON:

```json
{
  "npc_id": "maya_chen",
  "schedule": [
    {
      "time_start": "08:00",
      "time_end": "12:00",
      "location": "navigation_station",
      "activity": "working",
      "waypoints": [
        {"x": 320, "y": 180},
        {"x": 400, "y": 180}
      ]
    },
    {
      "time_start": "12:00",
      "time_end": "13:00",
      "location": "cafeteria",
      "activity": "idle"
    }
  ]
}
```


### 3.5 Dialogue System

**Purpose**: Present branching conversations with conditional logic and narrative effects.

**Architecture**: JSON-driven dialogue trees loaded and presented by DialogueManager singleton.

#### Dialogue JSON Schema

**Complete Schema with Field Descriptions**:

```json
{
  "$schema": "VoyagerDialogueTree",
  "version": "1.0",
  "dialogue_id": "unique_identifier",
  "participants": ["npc_id_1", "npc_id_2"],
  "start_node": "node_id_to_start_from",
  "nodes": [
    {
      "node_id": "unique_node_identifier",
      "speaker_id": "npc_id_or_player",
      "text": "Dialogue text with {player_name} variable support",
      "animation": "idle|thinking|concerned|happy (optional)",
      "conditions": {
        "story_flags": [
          {"flag": "flag_name", "value": true}
        ],
        "relationships": [
          {"npc_id": "maya_chen", "type": "trust", "min": 50}
        ],
        "quests": [
          {"quest_id": "inspect_sensors", "status": "active|completed"}
        ],
        "items": [
          {"item_id": "access_card", "count": 1}
        ]
      },
      "effects": [
        {"type": "set_flag", "flag": "met_maya", "value": true},
        {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": 5},
        {"type": "start_quest", "quest_id": "inspect_sensors"},
        {"type": "update_quest", "quest_id": "talk_to_crew", "objective_id": "talk_maya", "status": "completed"},
        {"type": "give_item", "item_id": "access_card", "count": 1},
        {"type": "play_sound", "sound": "notification_beep"}
      ],
      "responses": [
        {
          "response_id": "choice_1",
          "text": "Response text shown to player",
          "next_node": "node_id_to_jump_to",
          "conditions": {
            "story_flags": [{"flag": "knows_about_signal", "value": true}]
          },
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "bond", "change": -3}
          ]
        },
        {
          "response_id": "choice_2",
          "text": "Alternative response",
          "next_node": "different_node_id"
        }
      ],
      "auto_advance": false,
      "next_node": "node_if_no_responses"
    }
  ]
}
```

**Field Descriptions**:

- **dialogue_id**: Unique identifier for this dialogue tree
- **participants**: Array of NPC IDs involved in conversation
- **start_node**: Node ID where dialogue begins
- **nodes**: Array of dialogue nodes
  - **node_id**: Unique identifier within this tree
  - **speaker_id**: ID of speaking character ("player" for protagonist)
  - **text**: Dialogue text; supports {player_name}, {npc_name} variables
  - **animation**: Optional sprite animation to play during line
  - **conditions**: Requirements for node to be shown (all must be true)
    - **story_flags**: Check global story flags
    - **relationships**: Check Trust/Bond values
    - **quests**: Check quest status
    - **items**: Check player inventory
  - **effects**: Actions executed when node is displayed
  - **responses**: Player dialogue choices (empty for NPC monologues)
    - **response_id**: Unique identifier for this choice
    - **text**: Choice text shown to player
    - **next_node**: Node to jump to if chosen
    - **conditions**: Requirements for choice to appear
    - **effects**: Actions executed if chosen
  - **auto_advance**: If true, automatically continues to next_node
  - **next_node**: Node to continue to if no responses

#### Full Dialogue Example

```json
{
  "dialogue_id": "maya_first_meeting_prologue",
  "participants": ["maya_chen"],
  "start_node": "maya_greeting",
  "nodes": [
    {
      "node_id": "maya_greeting",
      "speaker_id": "maya_chen",
      "text": "Oh, you must be {player_name}! I'm Maya Chen, Navigator for the Voyager mission. Welcome to Asterion.",
      "animation": "happy",
      "effects": [
        {"type": "set_flag", "flag": "met_maya", "value": true}
      ],
      "responses": [
        {
          "response_id": "polite",
          "text": "Nice to meet you, Maya. I'm looking forward to working with you.",
          "next_node": "maya_enthusiastic",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "bond", "change": 5}
          ]
        },
        {
          "response_id": "professional",
          "text": "Navigator Chen. I'd like a status report on our departure timeline.",
          "next_node": "maya_professional",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": 3}
          ]
        },
        {
          "response_id": "curious",
          "text": "How did you end up as navigator for this mission?",
          "next_node": "maya_backstory"
        }
      ]
    },
    {
      "node_id": "maya_enthusiastic",
      "speaker_id": "maya_chen",
      "text": "Likewise! I've been running trajectory simulations for weeks. The flight path to our destination is... well, challenging, but I'm confident we'll make it.",
      "animation": "thinking",
      "responses": [
        {
          "response_id": "ask_challenge",
          "text": "What makes it challenging?",
          "next_node": "maya_explains_trajectory"
        },
        {
          "response_id": "express_confidence",
          "text": "I trust your expertise. What do you need from me?",
          "next_node": "maya_appreciates_trust",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": 5}
          ]
        }
      ]
    },
    {
      "node_id": "maya_professional",
      "speaker_id": "maya_chen",
      "text": "Of course. Our launch window opens in 72 hours. I've plotted three optimal trajectories based on current stellar positions. Before I can finalize our course, I need you to check the sensor array on Deck 3.",
      "animation": "idle",
      "effects": [
        {"type": "start_quest", "quest_id": "inspect_sensor_array"}
      ],
      "responses": [
        {
          "response_id": "accept_task",
          "text": "I'll inspect them immediately.",
          "next_node": "maya_thanks",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": 3}
          ]
        },
        {
          "response_id": "ask_details",
          "text": "What specifically should I be looking for?",
          "next_node": "maya_sensor_details"
        }
      ]
    },
    {
      "node_id": "maya_backstory",
      "speaker_id": "maya_chen",
      "text": "I studied astrodynamics at Caltech, then spent five years at NASA's JPL working on deep-space navigation. When they announced Voyager, I knew I had to be part of it. Some journeys define your entire life, you know?",
      "animation": "thinking",
      "effects": [
        {"type": "set_flag", "flag": "knows_maya_background", "value": true},
        {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "bond", "change": 8}
      ],
      "responses": [
        {
          "response_id": "share_motivation",
          "text": "I feel the same way. That's why I'm here.",
          "next_node": "maya_connects",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "bond", "change": 5}
          ]
        },
        {
          "response_id": "return_to_business",
          "text": "That's impressive. Now, what's our current status?",
          "next_node": "maya_professional"
        }
      ]
    },
    {
      "node_id": "maya_explains_trajectory",
      "speaker_id": "maya_chen",
      "text": "We're threading through a debris field left by a comet collision three centuries ago. Precision is everything - one degree off and we could add months to our journey, or worse.",
      "animation": "concerned",
      "effects": [
        {"type": "set_flag", "flag": "knows_about_debris_field", "value": true}
      ],
      "responses": [
        {
          "response_id": "express_concern",
          "text": "That sounds dangerous. Can we find another route?",
          "next_node": "maya_no_alternative",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": -2}
          ]
        },
        {
          "response_id": "trust_maya",
          "text": "If anyone can navigate it, it's you.",
          "next_node": "maya_appreciates_trust",
          "effects": [
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "trust", "change": 5},
            {"type": "change_relationship", "npc_id": "maya_chen", "relationship": "bond", "change": 3}
          ]
        }
      ]
    },
    {
      "node_id": "maya_no_alternative",
      "speaker_id": "maya_chen",
      "text": "I've analyzed every alternative. They all add at least six months to our journey, and we don't have the life support reserves for that. Don't worry - I've done this calculation a hundred times.",
      "animation": "idle",
      "auto_advance": true,
      "next_node": "maya_conversation_end"
    },
    {
      "node_id": "maya_appreciates_trust",
      "speaker_id": "maya_chen",
      "text": "Thank you. That means a lot. I won't let you down.",
      "animation": "happy",
      "auto_advance": true,
      "next_node": "maya_conversation_end"
    },
    {
      "node_id": "maya_connects",
      "speaker_id": "maya_chen",
      "text": "I had a feeling about you. We're going to make a great team, {player_name}.",
      "animation": "happy",
      "auto_advance": true,
      "next_node": "maya_conversation_end"
    },
    {
      "node_id": "maya_sensor_details",
      "speaker_id": "maya_chen",
      "text": "The long-range sensors should be showing green status lights. If any are amber or red, run a level-2 diagnostic from the control terminal. The system will guide you through it.",
      "animation": "idle",
      "effects": [
        {"type": "update_quest", "quest_id": "inspect_sensor_array", "objective_id": "get_instructions", "status": "completed"}
      ],
      "responses": [
        {
          "response_id": "acknowledge",
          "text": "Understood. I'll get it done.",
          "next_node": "maya_thanks"
        }
      ]
    },
    {
      "node_id": "maya_thanks",
      "speaker_id": "maya_chen",
      "text": "Great! Once the sensors are verified, come find me. I'll show you the navigation charts.",
      "animation": "happy",
      "auto_advance": true,
      "next_node": "maya_conversation_end"
    },
    {
      "node_id": "maya_conversation_end",
      "speaker_id": "maya_chen",
      "text": "I should get back to work. See you later!",
      "animation": "idle",
      "responses": []
    }
  ]
}
```

#### DialogueManager Implementation

```gdscript
# res://scripts/managers/dialogue_manager.gd
extends Node

signal dialogue_started
signal dialogue_ended
signal dialogue_node_changed(node_data: Dictionary)
signal dialogue_choices_presented(choices: Array)

var current_dialogue: Dictionary = {}
var current_node_id: String = ""
var is_dialogue_active: bool = false

func start_dialogue(dialogue_file: String, npc_id: String = "") -> void:
	var file = FileAccess.open(dialogue_file, FileAccess.READ)
	if file == null:
		push_error("Failed to load dialogue file: " + dialogue_file)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse dialogue JSON: " + dialogue_file)
		return
	
	current_dialogue = json.data
	current_node_id = current_dialogue.get("start_node", "")
	
	if current_node_id == "":
		push_error("Dialogue has no start_node")
		return
	
	is_dialogue_active = true
	dialogue_started.emit()
	
	process_node(current_node_id)

func process_node(node_id: String) -> void:
	var node = find_node(node_id)
	if node == null:
		push_error("Node not found: " + node_id)
		end_dialogue()
		return
	
	# Check conditions
	if not check_conditions(node.get("conditions", {})):
		# Node conditions not met, try next_node or end
		if node.has("next_node"):
			process_node(node["next_node"])
		else:
			end_dialogue()
		return
	
	# Apply effects
	apply_effects(node.get("effects", []))
	
	# Substitute variables in text
	var text = substitute_variables(node.get("text", ""))
	node["text"] = text
	
	# Emit node data for UI
	current_node_id = node_id
	dialogue_node_changed.emit(node)
	
	# Handle responses or auto-advance
	var responses = node.get("responses", [])
	if responses.is_empty():
		if node.get("auto_advance", false) and node.has("next_node"):
			# Auto-advance after delay
			await get_tree().create_timer(1.5).timeout
			process_node(node["next_node"])
		else:
			# No responses and no auto-advance means end
			end_dialogue()
	else:
		# Filter responses by conditions
		var available_responses = []
		for response in responses:
			if check_conditions(response.get("conditions", {})):
				available_responses.append(response)
		
		if available_responses.is_empty():
			# No valid responses, try next_node or end
			if node.has("next_node"):
				process_node(node["next_node"])
			else:
				end_dialogue()
		else:
			dialogue_choices_presented.emit(available_responses)

func select_response(response_id: String) -> void:
	var node = find_node(current_node_id)
	if node == null:
		return
	
	for response in node.get("responses", []):
		if response.get("response_id") == response_id:
			# Apply response effects
			apply_effects(response.get("effects", []))
			
			# Move to next node
			if response.has("next_node"):
				process_node(response["next_node"])
			else:
				end_dialogue()
			return

func find_node(node_id: String) -> Dictionary:
	for node in current_dialogue.get("nodes", []):
		if node.get("node_id") == node_id:
			return node
	return {}

func check_conditions(conditions: Dictionary) -> bool:
	# Check story flags
	for flag_cond in conditions.get("story_flags", []):
		var flag = flag_cond.get("flag")
		var value = flag_cond.get("value")
		if StoryFlagManager.get_flag(flag) != value:
			return false
	
	# Check relationships
	for rel_cond in conditions.get("relationships", []):
		var npc_id = rel_cond.get("npc_id")
		var type = rel_cond.get("type")
		var min_value = rel_cond.get("min", 0)
		var current_value = RelationshipManager.get_relationship(npc_id, type)
		if current_value < min_value:
			return false
	
	# Check quests
	for quest_cond in conditions.get("quests", []):
		var quest_id = quest_cond.get("quest_id")
		var required_status = quest_cond.get("status")
		var current_status = QuestManager.get_quest_status(quest_id)
		if current_status != required_status:
			return false
	
	return true

func apply_effects(effects: Array) -> void:
	for effect in effects:
		var type = effect.get("type")
		match type:
			"set_flag":
				StoryFlagManager.set_flag(effect.get("flag"), effect.get("value"))
			
			"change_relationship":
				var npc_id = effect.get("npc_id")
				var relationship = effect.get("relationship")
				var change = effect.get("change")
				RelationshipManager.change_relationship(npc_id, relationship, change)
			
			"start_quest":
				QuestManager.start_quest(effect.get("quest_id"))
			
			"update_quest":
				QuestManager.update_objective(
					effect.get("quest_id"),
					effect.get("objective_id"),
					effect.get("status")
				)
			
			"play_sound":
				AudioManager.play_sfx(effect.get("sound"))

func substitute_variables(text: String) -> String:
	text = text.replace("{player_name}", GameState.player_name)
	# Add more variable substitutions as needed
	return text

func end_dialogue() -> void:
	is_dialogue_active = false
	current_dialogue = {}
	current_node_id = ""
	dialogue_ended.emit()
```

#### Dialogue UI Implementation

```gdscript
# res://scripts/ui/dialogue_ui.gd
extends CanvasLayer

@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var text_label: RichTextLabel = $DialoguePanel/TextLabel
@onready var responses_container: VBoxContainer = $DialoguePanel/ResponsesContainer
@onready var continue_button: Button = $DialoguePanel/ContinueButton

var response_button_scene = preload("res://scenes/ui/response_button.tscn")

func _ready() -> void:
	dialogue_panel.visible = false
	
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.dialogue_node_changed.connect(_on_node_changed)
	DialogueManager.dialogue_choices_presented.connect(_on_choices_presented)
	
	continue_button.pressed.connect(_on_continue_pressed)

func _on_dialogue_started() -> void:
	dialogue_panel.visible = true

func _on_dialogue_ended() -> void:
	dialogue_panel.visible = false
	clear_responses()

func _on_node_changed(node_data: Dictionary) -> void:
	# Update speaker
	var speaker_id = node_data.get("speaker_id", "")
	if speaker_id == "player":
		speaker_label.text = GameState.player_name
	else:
		speaker_label.text = get_npc_display_name(speaker_id)
	
	# Update text
	text_label.text = node_data.get("text", "")
	
	# Hide responses initially
	clear_responses()
	continue_button.visible = false

func _on_choices_presented(choices: Array) -> void:
	clear_responses()
	
	for choice in choices:
		var button = response_button_scene.instantiate()
		button.text = choice.get("text", "")
		button.pressed.connect(func(): _on_response_selected(choice.get("response_id")))
		responses_container.add_child(button)

func _on_response_selected(response_id: String) -> void:
	DialogueManager.select_response(response_id)

func clear_responses() -> void:
	for child in responses_container.get_children():
		child.queue_free()

func _on_continue_pressed() -> void:
	# For NPC monologues with no responses
	pass

func get_npc_display_name(npc_id: String) -> String:
	match npc_id:
		"maya_chen": return "Maya Chen"
		"elias_voss": return "Elias Voss"
		"nora_reyes": return "Nora Reyes"
		"daniel_kim": return "Daniel Kim"
		_: return npc_id
```


### 3.6 Quest System

**Purpose**: Track player objectives, quest progress, and provide journal UI.

**Architecture**: JSON-driven quest definitions loaded by QuestManager singleton.

#### Quest JSON Schema

**Complete Schema with Field Descriptions**:

```json
{
  "$schema": "VoyagerQuestDefinition",
  "version": "1.0",
  "quest_id": "unique_quest_identifier",
  "title": "Quest Display Title",
  "description": "Brief description shown in journal",
  "category": "main|side|tutorial",
  "chapter": 1,
  "prerequisites": {
    "story_flags": [
      {"flag": "met_maya", "value": true}
    ],
    "quests_completed": ["previous_quest_id"],
    "relationships": [
      {"npc_id": "maya_chen", "type": "trust", "min": 20}
    ]
  },
  "objectives": [
    {
      "objective_id": "unique_objective_identifier",
      "description": "What the player needs to do",
      "type": "talk_to|investigate|collect|complete_puzzle|reach_location|crew_task",
      "target": "npc_id|object_id|item_id|puzzle_id|location_id",
      "count": 1,
      "optional": false,
      "hidden": false
    }
  ],
  "rewards": {
    "story_flags": [
      {"flag": "completed_sensor_check", "value": true}
    ],
    "relationships": [
      {"npc_id": "maya_chen", "relationship": "trust", "change": 10}
    ],
    "items": [
      {"item_id": "access_card_level_2", "count": 1}
    ],
    "unlock_location": "engineering_deck"
  },
  "failure_conditions": {
    "time_limit": 3600,
    "story_flags": [
      {"flag": "mission_departed", "value": true}
    ]
  }
}
```

**Field Descriptions**:

- **quest_id**: Unique identifier for this quest
- **title**: Display name in quest journal
- **description**: Brief overview of quest goal
- **category**: Quest type (main, side, tutorial)
- **chapter**: Which story chapter quest belongs to
- **prerequisites**: Requirements before quest can be started
- **objectives**: Array of sub-goals
  - **objective_id**: Unique identifier within quest
  - **description**: Text shown in journal
  - **type**: Objective category determining completion logic
  - **target**: ID of target entity (NPC, object, item, etc.)
  - **count**: Required completion count (for collect/crew_task types)
  - **optional**: If true, not required for quest completion
  - **hidden**: If true, not shown in journal until revealed
- **rewards**: Benefits granted on quest completion
- **failure_conditions**: Optional conditions causing quest failure

#### Full Quest Example

```json
{
  "quest_id": "inspect_sensor_array",
  "title": "Sensor Array Inspection",
  "description": "Maya needs you to verify the long-range sensor array on Deck 3 before finalizing navigation calculations.",
  "category": "main",
  "chapter": 1,
  "prerequisites": {
    "story_flags": [
      {"flag": "met_maya", "value": true}
    ]
  },
  "objectives": [
    {
      "objective_id": "get_instructions",
      "description": "Talk to Maya about sensor inspection",
      "type": "talk_to",
      "target": "maya_chen",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "reach_deck_3",
      "description": "Travel to Deck 3 Sensor Bay",
      "type": "reach_location",
      "target": "deck_3_sensor_bay",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "inspect_sensor_1",
      "description": "Inspect Forward Sensor Array",
      "type": "investigate",
      "target": "sensor_array_forward",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "inspect_sensor_2",
      "description": "Inspect Starboard Sensor Array",
      "type": "investigate",
      "target": "sensor_array_starboard",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "inspect_sensor_3",
      "description": "Inspect Port Sensor Array",
      "type": "investigate",
      "target": "sensor_array_port",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "run_diagnostic",
      "description": "Run level-2 diagnostic from control terminal",
      "type": "complete_puzzle",
      "target": "sensor_diagnostic_puzzle",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "report_to_maya",
      "description": "Report findings to Maya",
      "type": "talk_to",
      "target": "maya_chen",
      "count": 1,
      "optional": false,
      "hidden": false
    },
    {
      "objective_id": "optional_check_logs",
      "description": "Review sensor maintenance logs",
      "type": "investigate",
      "target": "sensor_log_terminal",
      "count": 1,
      "optional": true,
      "hidden": false
    }
  ],
  "rewards": {
    "story_flags": [
      {"flag": "sensor_array_verified", "value": true}
    ],
    "relationships": [
      {"npc_id": "maya_chen", "relationship": "trust", "change": 10},
      {"npc_id": "maya_chen", "relationship": "bond", "change": 5}
    ],
    "unlock_location": "navigation_station_advanced"
  },
  "failure_conditions": {
    "story_flags": [
      {"flag": "sensor_array_damaged", "value": true}
    ]
  }
}
```

#### QuestManager Implementation

```gdscript
# res://scripts/managers/quest_manager.gd
extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal objective_updated(quest_id: String, objective_id: String, status: String)

var active_quests: Dictionary = {}  # quest_id -> quest_data
var completed_quests: Array[String] = []
var failed_quests: Array[String] = []

func reset() -> void:
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()

func load_quest_definition(quest_id: String) -> Dictionary:
	var file_path = "res://data/quests/" + quest_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to load quest: " + quest_id)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse quest JSON: " + quest_id)
		return {}
	
	return json.data

func start_quest(quest_id: String) -> bool:
	if active_quests.has(quest_id) or completed_quests.has(quest_id):
		return false
	
	var quest_data = load_quest_definition(quest_id)
	if quest_data.is_empty():
		return false
	
	# Check prerequisites
	if not check_prerequisites(quest_data.get("prerequisites", {})):
		return false
	
	# Initialize objective statuses
	for objective in quest_data.get("objectives", []):
		objective["status"] = "active"
		objective["progress"] = 0
	
	active_quests[quest_id] = quest_data
	quest_started.emit(quest_id)
	return true

func check_prerequisites(prerequisites: Dictionary) -> bool:
	# Check story flags
	for flag_req in prerequisites.get("story_flags", []):
		if StoryFlagManager.get_flag(flag_req.get("flag")) != flag_req.get("value"):
			return false
	
	# Check completed quests
	for required_quest in prerequisites.get("quests_completed", []):
		if not completed_quests.has(required_quest):
			return false
	
	# Check relationships
	for rel_req in prerequisites.get("relationships", []):
		var npc_id = rel_req.get("npc_id")
		var type = rel_req.get("type")
		var min_value = rel_req.get("min", 0)
		if RelationshipManager.get_relationship(npc_id, type) < min_value:
			return false
	
	return true

func update_objective(quest_id: String, objective_id: String, status: String) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	for objective in quest.get("objectives", []):
		if objective.get("objective_id") == objective_id:
			objective["status"] = status
			objective_updated.emit(quest_id, objective_id, status)
			
			# Check if quest is complete
			check_quest_completion(quest_id)
			return

func progress_objective(quest_id: String, objective_id: String, progress_amount: int = 1) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	for objective in quest.get("objectives", []):
		if objective.get("objective_id") == objective_id:
			objective["progress"] = objective.get("progress", 0) + progress_amount
			
			var required_count = objective.get("count", 1)
			if objective["progress"] >= required_count:
				update_objective(quest_id, objective_id, "completed")
			else:
				objective_updated.emit(quest_id, objective_id, "progress")
			return

func check_quest_completion(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	var all_required_complete = true
	
	for objective in quest.get("objectives", []):
		if objective.get("optional", false):
			continue
		
		if objective.get("status") != "completed":
			all_required_complete = false
			break
	
	if all_required_complete:
		complete_quest(quest_id)

func complete_quest(quest_id: String) -> void:
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	
	# Apply rewards
	apply_rewards(quest.get("rewards", {}))
	
	# Move to completed
	active_quests.erase(quest_id)
	completed_quests.append(quest_id)
	
	quest_completed.emit(quest_id)

func apply_rewards(rewards: Dictionary) -> void:
	# Apply story flags
	for flag in rewards.get("story_flags", []):
		StoryFlagManager.set_flag(flag.get("flag"), flag.get("value"))
	
	# Apply relationship changes
	for rel_change in rewards.get("relationships", []):
		RelationshipManager.change_relationship(
			rel_change.get("npc_id"),
			rel_change.get("relationship"),
			rel_change.get("change")
		)
	
	# Give items
	for item in rewards.get("items", []):
		# TODO: Implement inventory system
		pass
	
	# Unlock locations
	if rewards.has("unlock_location"):
		StoryFlagManager.set_flag("unlock_" + rewards["unlock_location"], true)

func get_quest_status(quest_id: String) -> String:
	if active_quests.has(quest_id):
		return "active"
	elif completed_quests.has(quest_id):
		return "completed"
	elif failed_quests.has(quest_id):
		return "failed"
	else:
		return "not_started"

func get_active_quests() -> Array:
	return active_quests.values()

func get_quest_data(quest_id: String) -> Dictionary:
	if active_quests.has(quest_id):
		return active_quests[quest_id]
	return {}
```


### 3.7 Relationship System

**Purpose**: Track Trust and Bond values between protagonist and crew members, affecting dialogue options and story outcomes.

**Architecture**: RelationshipManager singleton maintains two values (Trust, Bond) per crew member.

**Relationship Types**:
- **Trust**: Professional confidence, competence, decision-making (0-100)
- **Bond**: Personal connection, friendship, emotional support (0-100)

**Thresholds**:
- **0-25**: Low - Negative reactions, limited dialogue options
- **26-50**: Neutral - Standard interactions
- **51-75**: Good - Positive responses, unlock some personal dialogues
- **76-100**: High - Deep trust/bond, unlock special dialogues and endings

**RelationshipManager Implementation**:

```gdscript
# res://scripts/managers/relationship_manager.gd
extends Node

signal relationship_changed(npc_id: String, relationship_type: String, old_value: int, new_value: int)
signal threshold_crossed(npc_id: String, relationship_type: String, threshold: int)

const CREW_MEMBERS = ["maya_chen", "elias_voss", "nora_reyes", "daniel_kim"]

var relationships: Dictionary = {}
# Structure: { "npc_id": { "trust": 50, "bond": 50 } }

func _ready() -> void:
	reset()

func reset() -> void:
	relationships.clear()
	for crew_id in CREW_MEMBERS:
		relationships[crew_id] = {
			"trust": 50,
			"bond": 50
		}

func get_relationship(npc_id: String, type: String) -> int:
	if not relationships.has(npc_id):
		return 50
	return relationships[npc_id].get(type, 50)

func set_relationship(npc_id: String, type: String, value: int) -> void:
	if not relationships.has(npc_id):
		relationships[npc_id] = {"trust": 50, "bond": 50}
	
	var old_value = relationships[npc_id].get(type, 50)
	var new_value = clampi(value, 0, 100)
	
	relationships[npc_id][type] = new_value
	
	relationship_changed.emit(npc_id, type, old_value, new_value)
	
	# Check threshold crossings
	check_thresholds(npc_id, type, old_value, new_value)

func change_relationship(npc_id: String, type: String, change: int) -> void:
	var current = get_relationship(npc_id, type)
	set_relationship(npc_id, type, current + change)

func check_thresholds(npc_id: String, type: String, old_value: int, new_value: int) -> void:
	var thresholds = [25, 50, 75]
	
	for threshold in thresholds:
		# Crossing upward
		if old_value < threshold and new_value >= threshold:
			threshold_crossed.emit(npc_id, type, threshold)
			unlock_threshold_content(npc_id, type, threshold)
		# Crossing downward
		elif old_value >= threshold and new_value < threshold:
			threshold_crossed.emit(npc_id, type, -threshold)

func unlock_threshold_content(npc_id: String, type: String, threshold: int) -> void:
	# Set story flags for unlocking dialogue/content
	var flag_name = npc_id + "_" + type + "_" + str(threshold)
	StoryFlagManager.set_flag(flag_name, true)

func get_relationship_tier(npc_id: String, type: String) -> String:
	var value = get_relationship(npc_id, type)
	if value >= 76:
		return "high"
	elif value >= 51:
		return "good"
	elif value >= 26:
		return "neutral"
	else:
		return "low"

func get_all_relationships() -> Dictionary:
	return relationships.duplicate(true)

func save_data() -> Dictionary:
	return {
		"relationships": relationships.duplicate(true)
	}

func load_data(data: Dictionary) -> void:
	if data.has("relationships"):
		relationships = data["relationships"].duplicate(true)
```


### 3.8 Crew Management System

**Purpose**: Manage crew task assignments during shipboard operations (post-prologue).

**Architecture**: CrewTaskManager singleton tracks crew assignments, fatigue, and skill effectiveness.

**Crew Skills**:
- Navigation (Maya specialty)
- Engineering (Elias specialty)
- Research (Nora specialty)
- Medical (Daniel specialty)
- Communications (general)
- Damage Control (general)

**Brief Implementation**:

```gdscript
# res://scripts/managers/crew_task_manager.gd
extends Node

var crew_assignments: Dictionary = {}
# Structure: { "maya_chen": { "task": "navigation", "duration": 120.0, "fatigue": 15 } }

func assign_task(crew_id: String, task: String, duration: float) -> bool:
	if crew_assignments.has(crew_id):
		return false  # Already assigned
	
	crew_assignments[crew_id] = {
		"task": task,
		"duration": duration,
		"time_remaining": duration,
		"fatigue": 0
	}
	return true

func update_tasks(delta: float) -> void:
	for crew_id in crew_assignments.keys():
		var assignment = crew_assignments[crew_id]
		assignment["time_remaining"] -= delta
		
		if assignment["time_remaining"] <= 0:
			complete_task(crew_id)

func complete_task(crew_id: String) -> void:
	crew_assignments.erase(crew_id)
```


### 3.9 Engineering Simulation

**Purpose**: Calculate spacecraft physics (delta-v, fuel consumption, power usage) based on Tsiolkovsky rocket equation.

**Architecture**: EngineeringSimulation singleton performs calculations and tracks resources.

**Key Formulas**:
- **Tsiolkovsky Equation**: Δv = v_exhaust * ln(m_initial / m_final)
- **Fuel Consumption**: m_fuel = m_ship * (e^(Δv/v_exhaust) - 1)
- **Power Usage**: Watts consumed per system

**Brief Implementation**:

```gdscript
# res://scripts/managers/engineering_simulation.gd
extends Node

var ship_stats: Dictionary = {
	"dry_mass": 50000.0,  # kg
	"fuel_mass": 30000.0,  # kg
	"exhaust_velocity": 4500.0,  # m/s
	"power_available": 100000.0,  # Watts
	"power_used": 20000.0  # Watts
}

func calculate_delta_v() -> float:
	var m_initial = ship_stats["dry_mass"] + ship_stats["fuel_mass"]
	var m_final = ship_stats["dry_mass"]
	var v_exhaust = ship_stats["exhaust_velocity"]
	
	return v_exhaust * log(m_initial / m_final)

func calculate_fuel_needed(target_delta_v: float) -> float:
	var v_exhaust = ship_stats["exhaust_velocity"]
	var m_ship = ship_stats["dry_mass"]
	
	return m_ship * (exp(target_delta_v / v_exhaust) - 1.0)

func consume_fuel(amount: float) -> void:
	ship_stats["fuel_mass"] = max(0, ship_stats["fuel_mass"] - amount)
```


### 3.10 Puzzle System

**Purpose**: Provide reusable framework for 5 puzzle types with validation.

**Puzzle Types**:
1. **Diagnostic Terminal**: Select correct sequence of options
2. **Wire Routing**: Connect input/output nodes correctly
3. **Resource Allocation**: Distribute limited resources optimally
4. **Signal Analysis**: Match waveform patterns
5. **Access Code**: Deduce code from scattered clues

**Brief Implementation**:

```gdscript
# res://scripts/managers/puzzle_manager.gd
extends Node

signal puzzle_started(puzzle_id: String)
signal puzzle_completed(puzzle_id: String)
signal puzzle_failed(puzzle_id: String)

var active_puzzle: String = ""
var puzzle_solutions: Dictionary = {}

func load_puzzle(puzzle_id: String) -> Dictionary:
	var file_path = "res://data/puzzles/" + puzzle_id + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	return json if json else {}

func start_puzzle(puzzle_id: String) -> void:
	var puzzle_data = load_puzzle(puzzle_id)
	active_puzzle = puzzle_id
	puzzle_solutions[puzzle_id] = puzzle_data.get("solution", {})
	puzzle_started.emit(puzzle_id)

func validate_solution(puzzle_id: String, player_solution: Variant) -> bool:
	if not puzzle_solutions.has(puzzle_id):
		return false
	
	var correct_solution = puzzle_solutions[puzzle_id]
	if player_solution == correct_solution:
		puzzle_completed.emit(puzzle_id)
		return true
	else:
		puzzle_failed.emit(puzzle_id)
		return false
```


### 3.11 Story State Management

**Purpose**: Track global story flags and conditions throughout the game.

**Implementation**:

```gdscript
# res://scripts/managers/story_flag_manager.gd
extends Node

signal flag_set(flag_name: String, value: Variant)

var flags: Dictionary = {}

func set_flag(flag_name: String, value: Variant) -> void:
	flags[flag_name] = value
	flag_set.emit(flag_name, value)

func get_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return flags.get(flag_name, default_value)

func has_flag(flag_name: String) -> bool:
	return flags.has(flag_name)

func clear_flag(flag_name: String) -> void:
	flags.erase(flag_name)

func reset() -> void:
	flags.clear()

func save_data() -> Dictionary:
	return {"flags": flags.duplicate(true)}

func load_data(data: Dictionary) -> void:
	if data.has("flags"):
		flags = data["flags"].duplicate(true)
```


### 3.12 Save/Load System

**Purpose**: Persist game state to disk and restore on load.

#### Complete Save File JSON Schema

```json
{
  "$schema": "VoyagerSaveFile",
  "version": "1.0.0",
  "timestamp": "2026-03-15T14:23:45Z",
  "save_name": "Player-chosen save name",
  "playtime_seconds": 3847,
  "player_data": {
    "name": "Commander Shepard",
    "current_scene": "res://scenes/environments/station/deck_3_sensor_bay.tscn",
    "position": {"x": 320.0, "y": 180.0},
    "chapter": 1
  },
  "story_data": {
    "flags": {
      "met_maya": true,
      "met_elias": true,
      "met_nora": false,
      "met_daniel": true,
      "sensor_array_verified": false,
      "knows_about_debris_field": true
    }
  },
  "quest_data": {
    "active_quests": [
      {
        "quest_id": "inspect_sensor_array",
        "objectives": [
          {"objective_id": "get_instructions", "status": "completed", "progress": 1},
          {"objective_id": "reach_deck_3", "status": "completed", "progress": 1},
          {"objective_id": "inspect_sensor_1", "status": "active", "progress": 0}
        ]
      }
    ],
    "completed_quests": ["tutorial_movement", "meet_the_crew"],
    "failed_quests": []
  },
  "relationship_data": {
    "maya_chen": {"trust": 65, "bond": 58},
    "elias_voss": {"trust": 50, "bond": 45},
    "nora_reyes": {"trust": 50, "bond": 50},
    "daniel_kim": {"trust": 55, "bond": 52}
  },
  "crew_data": {
    "assignments": {},
    "fatigue": {
      "maya_chen": 5,
      "elias_voss": 0,
      "nora_reyes": 0,
      "daniel_kim": 3
    }
  },
  "engineering_data": {
    "ship_stats": {
      "dry_mass": 50000.0,
      "fuel_mass": 30000.0,
      "power_available": 100000.0,
      "power_used": 20000.0
    },
    "equipment": ["fusion_reactor", "ion_drive", "sensor_array_basic"]
  },
  "inventory_data": {
    "items": [
      {"item_id": "access_card_level_1", "count": 1},
      {"item_id": "maintenance_tool", "count": 1}
    ]
  },
  "puzzle_data": {
    "completed_puzzles": ["tutorial_terminal"],
    "puzzle_states": {}
  }
}
```

**SaveManager Implementation**:

```gdscript
# res://scripts/managers/save_manager.gd
extends Node

const SAVE_DIR = "user://saves/"
const SAVE_VERSION = "1.0.0"

func save_game(save_name: String) -> bool:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	
	var save_data = compile_save_data(save_name)
	
	var file_path = SAVE_DIR + save_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: " + file_path)
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_game(save_name: String) -> bool:
	var file_path = SAVE_DIR + save_name + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: " + file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var save_data = JSON.parse_string(json_text)
	if save_data == null:
		push_error("Failed to parse save file")
		return false
	
	apply_save_data(save_data)
	return true

func compile_save_data(save_name: String) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"save_name": save_name,
		"playtime_seconds": 0,  # TODO: Track playtime
		"player_data": {
			"name": GameState.player_name,
			"current_scene": get_tree().current_scene.scene_file_path,
			"position": {"x": 0.0, "y": 0.0},  # TODO: Get player position
			"chapter": GameState.current_chapter
		},
		"story_data": StoryFlagManager.save_data(),
		"quest_data": {
			"active_quests": compile_quest_data(),
			"completed_quests": QuestManager.completed_quests.duplicate(),
			"failed_quests": QuestManager.failed_quests.duplicate()
		},
		"relationship_data": RelationshipManager.save_data()["relationships"],
		"crew_data": {},  # TODO: CrewTaskManager save data
		"engineering_data": {},  # TODO: EngineeringSimulation save data
		"inventory_data": {"items": []},  # TODO: Inventory system
		"puzzle_data": {"completed_puzzles": [], "puzzle_states": {}}
	}

func compile_quest_data() -> Array:
	var active = []
	for quest in QuestManager.get_active_quests():
		var objectives_data = []
		for obj in quest.get("objectives", []):
			objectives_data.append({
				"objective_id": obj.get("objective_id"),
				"status": obj.get("status"),
				"progress": obj.get("progress", 0)
			})
		
		active.append({
			"quest_id": quest.get("quest_id"),
			"objectives": objectives_data
		})
	return active

func apply_save_data(data: Dictionary) -> void:
	# Reset all systems
	GameState.player_name = data["player_data"]["name"]
	GameState.current_chapter = data["player_data"]["chapter"]
	
	StoryFlagManager.load_data(data.get("story_data", {}))
	RelationshipManager.load_data({"relationships": data.get("relationship_data", {})})
	
	# Restore quests
	QuestManager.reset()
	for quest_data in data.get("quest_data", {}).get("active_quests", []):
		var quest_id = quest_data.get("quest_id")
		QuestManager.start_quest(quest_id)
		
		for obj_data in quest_data.get("objectives", []):
			QuestManager.update_objective(
				quest_id,
				obj_data.get("objective_id"),
				obj_data.get("status")
			)
	
	QuestManager.completed_quests = data.get("quest_data", {}).get("completed_quests", []).duplicate()
	
	# Load scene
	SceneManager.transition_to(data["player_data"]["current_scene"])

func list_saves() -> Array[String]:
	var saves: Array[String] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				saves.append(file_name.trim_suffix(".json"))
			file_name = dir.get_next()
		dir.list_dir_end()
	return saves
```


### 3.13 Audio System

**Purpose**: Manage music tracks, ambient audio, and sound effects.

**Audio Buses**:
- Master
- Music
- SFX
- Ambient
- UI

**AudioManager Implementation**:

```gdscript
# res://scripts/managers/audio_manager.gd
extends Node

var current_music: AudioStreamPlayer = null
var music_tracks: Dictionary = {
	"main_menu": "res://audio/music/main_menu.ogg",
	"station_ambient": "res://audio/music/station_ambient.ogg",
	"exploration": "res://audio/music/exploration.ogg",
	"tension": "res://audio/music/tension.ogg"
}

func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if current_music and current_music.playing:
		fade_out_music(fade_duration)
	
	var track_path = music_tracks.get(track_name)
	if track_path:
		current_music = AudioStreamPlayer.new()
		current_music.stream = load(track_path)
		current_music.bus = "Music"
		add_child(current_music)
		current_music.play()

func fade_out_music(duration: float) -> void:
	if current_music:
		var tween = create_tween()
		tween.tween_property(current_music, "volume_db", -80, duration)
		tween.tween_callback(current_music.queue_free)

func play_sfx(sfx_name: String) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load("res://audio/sfx/" + sfx_name + ".ogg")
	sfx.bus = "SFX"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
```


## 4. Data Schemas

### 4.1 Complete Dialogue Tree Schema

See section 3.5 for the complete dialogue tree schema with full field descriptions and the 11-node example dialogue for Maya's first meeting.

**Key Features**:
- Variable substitution (`{player_name}`)
- Conditional branching (story flags, relationships, quests)
- Effects system (modify flags, relationships, quests)
- Response filtering based on conditions
- Auto-advance for cinematic sequences


### 4.2 Complete Quest Definition Schema

See section 3.6 for the complete quest schema with full field descriptions and the multi-objective sensor inspection quest example.

**Key Features**:
- Multiple objective types (talk_to, investigate, collect, complete_puzzle, reach_location, crew_task)
- Optional and hidden objectives
- Prerequisite system (flags, quests, relationships)
- Comprehensive reward system
- Failure conditions


### 4.3 NPC Metadata Schema

```json
{
  "$schema": "VoyagerNPCMetadata",
  "npc_id": "maya_chen",
  "display_name": "Maya Chen",
  "role": "Navigator",
  "description": "Expert in astrodynamics and flight planning",
  "sprite_path": "res://assets/sprites/characters/maya_chen.png",
  "dialogue_files": {
    "prologue": "res://data/dialogues/maya_chen_prologue.json",
    "chapter_2": "res://data/dialogues/maya_chen_chapter_2.json"
  },
  "spawn_locations": [
    {
      "scene": "res://scenes/environments/station/navigation_deck.tscn",
      "position": {"x": 320, "y": 180},
      "chapter": 1,
      "conditions": {
        "story_flags": [{"flag": "mission_not_departed", "value": true}]
      }
    }
  ],
  "schedule": [
    {
      "time_start": "08:00",
      "time_end": "12:00",
      "location": "navigation_station",
      "activity": "working",
      "waypoints": [
        {"x": 320, "y": 180},
        {"x": 400, "y": 180}
      ]
    }
  ],
  "initial_relationships": {
    "trust": 50,
    "bond": 50
  },
  "skills": {
    "navigation": 95,
    "engineering": 40,
    "research": 60,
    "medical": 20,
    "communications": 75,
    "damage_control": 45
  }
}
```


### 4.4 Complete Save File Schema

See section 3.12 for the comprehensive save file schema including player data, story flags, quests, relationships, crew assignments, engineering stats, inventory, and puzzle states.


### 4.5 Puzzle Definition Schema Example

```json
{
  "$schema": "VoyagerPuzzleDefinition",
  "puzzle_id": "sensor_diagnostic_puzzle",
  "title": "Sensor Diagnostic Sequence",
  "description": "Run a level-2 diagnostic to verify sensor calibration",
  "type": "diagnostic_terminal",
  "difficulty": "medium",
  "time_limit": 300,
  "instructions": "Select the correct sequence of diagnostic tests in order.",
  "options": [
    {"id": "power_check", "text": "Power Supply Check"},
    {"id": "calibration", "text": "Calibration Verification"},
    {"id": "signal_test", "text": "Signal Integrity Test"},
    {"id": "network_test", "text": "Network Connectivity Test"},
    {"id": "firmware_check", "text": "Firmware Version Check"}
  ],
  "solution": ["power_check", "firmware_check", "calibration", "signal_test", "network_test"],
  "hints": [
    "Always verify power and firmware before testing functionality.",
    "Calibration must be checked before signal tests.",
    "Network connectivity is tested last."
  ],
  "rewards": {
    "story_flags": [
      {"flag": "sensor_diagnostic_complete", "value": true}
    ]
  }
}
```


## 5. Scene Hierarchy & Project Structure

### Complete Directory Tree

```
voyagerisnotalone/
│
├── .godot/                          # Godot engine cache (gitignored)
├── .kiro/                           # Kiro specs and configuration
│   └── specs/
│       └── voyager-is-not-alone/
│           ├── requirements.md
│           ├── design.md
│           └── tasks.md
│
├── assets/                          # All game assets (Dev 2 primary)
│   ├── sprites/
│   │   ├── characters/              # Character sprites
│   │   │   ├── player/
│   │   │   │   ├── idle_down.png
│   │   │   │   ├── idle_up.png
│   │   │   │   ├── idle_left.png
│   │   │   │   ├── idle_right.png
│   │   │   │   ├── walk_down_01.png
│   │   │   │   ├── walk_down_02.png
│   │   │   │   └── ...
│   │   │   ├── maya_chen/
│   │   │   ├── elias_voss/
│   │   │   ├── nora_reyes/
│   │   │   └── daniel_kim/
│   │   ├── environment/             # Tileset sprites
│   │   │   ├── station_floor.png
│   │   │   ├── station_walls.png
│   │   │   ├── furniture.png
│   │   │   └── terminals.png
│   │   └── ui/                      # UI elements
│   │       ├── dialogue_box.png
│   │       ├── buttons.png
│   │       └── journal.png
│   │
│   ├── audio/
│   │   ├── music/
│   │   │   ├── main_menu.ogg
│   │   │   ├── station_ambient.ogg
│   │   │   ├── exploration.ogg
│   │   │   └── tension.ogg
│   │   ├── sfx/
│   │   │   ├── footstep.ogg
│   │   │   ├── door_open.ogg
│   │   │   ├── terminal_beep.ogg
│   │   │   └── notification.ogg
│   │   └── ambient/
│   │       ├── station_hum.ogg
│   │       └── ventilation.ogg
│   │
│   └── fonts/
│       ├── main_font.ttf
│       └── terminal_font.ttf
│
├── data/                            # Game content data (Dev 2 primary)
│   ├── dialogues/                   # Dialogue JSON files
│   │   ├── maya_chen_prologue.json
│   │   ├── elias_voss_prologue.json
│   │   ├── nora_reyes_prologue.json
│   │   └── daniel_kim_prologue.json
│   │
│   ├── quests/                      # Quest JSON files
│   │   ├── inspect_sensor_array.json
│   │   ├── meet_the_crew.json
│   │   └── prepare_voyager.json
│   │
│   ├── npcs/                        # NPC metadata JSON
│   │   ├── maya_chen.json
│   │   ├── elias_voss.json
│   │   ├── nora_reyes.json
│   │   └── daniel_kim.json
│   │
│   ├── puzzles/                     # Puzzle definitions
│   │   ├── sensor_diagnostic_puzzle.json
│   │   ├── power_routing_puzzle.json
│   │   └── access_code_puzzle.json
│   │
│   └── config/                      # Game configuration
│       ├── ship_stats.json
│       └── game_balance.json
│
├── scenes/                          # Godot scene files
│   ├── main.tscn                    # Main game entry point
│   ├── main_menu.tscn               # Main menu scene
│   │
│   ├── environments/                # Environment scenes (Dev 2 primary)
│   │   └── station/
│   │       ├── residential_deck_01.tscn
│   │       ├── residential_deck_02.tscn
│   │       ├── navigation_deck.tscn
│   │       ├── engineering_deck.tscn
│   │       ├── deck_3_sensor_bay.tscn
│   │       ├── cafeteria.tscn
│   │       └── airlock.tscn
│   │
│   ├── characters/                  # Character prefabs (Dev 1 base, Dev 2 instances)
│   │   ├── player.tscn
│   │   ├── maya_chen.tscn
│   │   ├── elias_voss.tscn
│   │   ├── nora_reyes.tscn
│   │   └── daniel_kim.tscn
│   │
│   ├── ui/                          # UI scenes (Dev 1 primary)
│   │   ├── dialogue_ui.tscn
│   │   ├── quest_journal.tscn
│   │   ├── interaction_prompt.tscn
│   │   ├── pause_menu.tscn
│   │   └── response_button.tscn
│   │
│   ├── prefabs/                     # Reusable prefabs (Dev 1 primary)
│   │   ├── door.tscn
│   │   ├── terminal.tscn
│   │   ├── interactable_object.tscn
│   │   └── puzzle_terminal.tscn
│   │
│   └── puzzles/                     # Puzzle UI scenes (Dev 1 primary)
│       ├── diagnostic_terminal.tscn
│       ├── wire_routing.tscn
│       └── resource_allocation.tscn
│
├── scripts/                         # GDScript files (Dev 1 primary)
│   ├── core/                        # Core systems
│   │   ├── game_state.gd
│   │   └── scene_manager.gd
│   │
│   ├── player/                      # Player controller
│   │   └── player_controller.gd
│   │
│   ├── npcs/                        # NPC systems
│   │   ├── npc_controller.gd
│   │   └── npc_interactable.gd
│   │
│   ├── managers/                    # Manager singletons
│   │   ├── dialogue_manager.gd
│   │   ├── quest_manager.gd
│   │   ├── relationship_manager.gd
│   │   ├── story_flag_manager.gd
│   │   ├── save_manager.gd
│   │   ├── audio_manager.gd
│   │   ├── crew_task_manager.gd
│   │   ├── engineering_simulation.gd
│   │   └── puzzle_manager.gd
│   │
│   ├── ui/                          # UI controllers
│   │   ├── dialogue_ui.gd
│   │   ├── quest_journal_ui.gd
│   │   ├── interaction_ui.gd
│   │   └── pause_menu.gd
│   │
│   ├── interfaces/                  # Interface patterns
│   │   └── interactable.gd
│   │
│   └── puzzles/                     # Puzzle logic
│       ├── diagnostic_terminal.gd
│       ├── wire_routing.gd
│       └── resource_allocation.gd
│
├── tests/                           # Test scripts
│   ├── unit/
│   │   ├── test_relationship_manager.gd
│   │   ├── test_quest_manager.gd
│   │   └── test_engineering_simulation.gd
│   └── integration/
│       └── test_dialogue_flow.gd
│
├── .gitignore                       # Git ignore rules
├── .gitattributes                   # Git attributes
├── project.godot                    # Godot project file
├── icon.svg                         # Project icon
├── export_presets.cfg               # Export configurations
└── README.md                        # Project documentation
```


## 6. Developer Collaboration Contracts

### 6.1 Folder Ownership

| Folder/System | Developer 1 (Kiro) | Developer 2 (Dias) | Notes |
|---------------|--------------------|--------------------|-------|
| `scripts/core/` | ✓ Own | Read-only | Core architecture |
| `scripts/player/` | ✓ Own | Read-only | Player controller |
| `scripts/npcs/` | ✓ Own base class | Extend for specific NPCs | Base NPCController owned by Dev 1 |
| `scripts/managers/` | ✓ Own | Read-only | All manager singletons |
| `scripts/ui/` | ✓ Own | Use/feedback | UI logic and controllers |
| `scripts/interfaces/` | ✓ Own | Read-only | Interface patterns |
| `scripts/puzzles/` | ✓ Own | Read-only | Puzzle implementations |
| `data/dialogues/` | - | ✓ Own | Dialogue JSON files |
| `data/quests/` | - | ✓ Own | Quest JSON files |
| `data/npcs/` | - | ✓ Own | NPC metadata JSON |
| `data/puzzles/` | - | ✓ Own | Puzzle definitions JSON |
| `scenes/environments/` | - | ✓ Own | All environment scenes |
| `scenes/characters/` | ✓ Own prefabs | ✓ Place instances | Dev 1 creates prefabs, Dev 2 places in scenes |
| `scenes/ui/` | ✓ Own | Read-only | UI scene structure |
| `scenes/prefabs/` | ✓ Own | Use in scenes | Reusable components |
| `assets/sprites/` | - | ✓ Own | All pixel art |
| `assets/audio/` | - | ✓ Own | All audio files |
| `tests/` | ✓ Own | - | Test scripts |


### 6.2 Naming Conventions

#### Scene Files
```
location_area_variant.tscn
```
Examples:
- `residential_deck_01.tscn`
- `navigation_deck.tscn`
- `deck_3_sensor_bay.tscn`

#### Script Files
```
snake_case.gd
```
Examples:
- `player_controller.gd`
- `dialogue_manager.gd`
- `npc_controller.gd`

#### Asset Files

**Sprites**:
```
character_state_frame.png
```
Examples:
- `player_idle_down.png`
- `maya_walk_right_01.png`
- `elias_working.png`

**Audio**:
```
descriptive_name.ogg
```
Examples:
- `station_ambient.ogg`
- `door_open.ogg`
- `notification_beep.ogg`

#### Data Files

**Dialogues**:
```
npc_id_chapter.json
```
Examples:
- `maya_chen_prologue.json`
- `elias_voss_chapter_2.json`

**Quests**:
```
quest_identifier.json
```
Examples:
- `inspect_sensor_array.json`
- `meet_the_crew.json`

#### Node Names in Scenes
```
PascalCase
```
Examples:
- `PlayerSpawn`
- `MayaChen`
- `SensorTerminal`
- `DoorToNavigationDeck`


### 6.3 Integration Interfaces

#### How Dias Creates NPCs

1. **Create NPC metadata JSON** in `data/npcs/`:
```json
{
  "npc_id": "new_character",
  "display_name": "New Character",
  "sprite_path": "res://assets/sprites/characters/new_character.png",
  "dialogue_files": {
    "prologue": "res://data/dialogues/new_character_prologue.json"
  }
}
```

2. **Create dialogue JSON** in `data/dialogues/`:
```json
{
  "dialogue_id": "new_character_prologue",
  "start_node": "greeting",
  "nodes": [...]
}
```

3. **Place NPC instance** in environment scene:
   - Open scene in Godot
   - Instance `scenes/characters/npc_base.tscn` (created by Dev 1)
   - Set exported properties: `npc_id`, `display_name`, `dialogue_file`
   - Position in scene
   - Assign sprite

#### How Dias Creates Environments

1. **Create scene** `scenes/environments/station/new_area.tscn`
2. **Add TileMapLayer** for floor/walls using tileset
3. **Place NPCs** from character prefabs
4. **Place doors** from `scenes/prefabs/door.tscn`
   - Set `target_scene` property to destination
   - Set `spawn_point_name` for player spawn
5. **Place terminals** from `scenes/prefabs/terminal.tscn`
6. **Add PlayerSpawn** Marker2D node for player entry
7. **Add collision shapes** for walls/boundaries

#### How Dias Creates Quests

1. **Create quest JSON** in `data/quests/`:
```json
{
  "quest_id": "new_quest",
  "title": "Quest Title",
  "objectives": [...]
}
```

2. **Reference quest** in dialogue effects:
```json
{
  "effects": [
    {"type": "start_quest", "quest_id": "new_quest"}
  ]
}
```

3. **Set objective completion** in dialogue or interactable effects:
```json
{
  "effects": [
    {"type": "update_quest", "quest_id": "new_quest", "objective_id": "obj_1", "status": "completed"}
  ]
}
```


### 6.4 Git Workflow

#### Branch Strategy
```
main                    # Stable, tested code
├── dev-1/feature-x     # Dev 1 feature branches
├── dev-1/system-y      # Dev 1 system branches
├── dev-2/content-a     # Dev 2 content branches
└── dev-2/environment-b # Dev 2 environment branches
```

#### Folder Ownership Rules
- **Dev 1 owns**: `scripts/`, `tests/`, `scenes/ui/`, `scenes/prefabs/`
- **Dev 2 owns**: `data/`, `assets/`, `scenes/environments/`, `scenes/characters/` (instances only)

#### Merge Strategy
1. **Dev 1 merges to main**: Systems, managers, player controller, UI
2. **Dev 2 merges to main**: Content (dialogues, quests, NPCs), environments, assets
3. **Conflict resolution**: If both edit same file:
   - Scene files: Dev 2 takes precedence (environments)
   - Script files: Dev 1 takes precedence (systems)
   - Data files: Dev 2 takes precedence (content)

#### Commit Message Format
```
[category] Brief description

Details if needed.

Examples:
[system] Add RelationshipManager with Trust/Bond tracking
[content] Create Maya Chen prologue dialogue
[environment] Build navigation deck scene
[bugfix] Fix player collision with doors
```


## 7. MVP vs Full Game Roadmap

| Feature | MVP (Hackathon) | Post-MVP Phase 1 | Post-MVP Phase 2 |
|---------|-----------------|------------------|------------------|
| **Story Content** | Prologue (30-45 min) | Chapters 1-3 (3-4 hours) | Chapters 4-7 (full 8-10 hours) |
| **Environments** | 5-6 station rooms | 15+ station rooms, Voyager interior | Planet Eidolon, abandoned spacecraft |
| **NPCs** | 4 main crew (basic) | 4 crew (full personalities) + 2 minor NPCs | All NPCs + dynamic encounters |
| **Dialogues** | 8-10 dialogue trees | 30+ dialogue trees | 60+ dialogue trees |
| **Quests** | 3-4 linear quests | 10 quests (main + side) | 25+ quests with branching |
| **Relationship System** | Trust/Bond tracking | Relationship thresholds unlock content | Deep relationships affect endings |
| **Crew Management** | Concept only | Basic task assignment | Full fatigue, skills, scheduling |
| **Engineering Sim** | Display-only stats | Interactive ship configuration | Full physics simulation |
| **Puzzles** | 2 puzzle types, 3 instances | 4 puzzle types, 10 instances | 5 puzzle types, 20+ instances |
| **Save/Load** | Single save slot | 3 save slots | Unlimited saves + autosave |
| **Endings** | 1 ending (prologue conclusion) | 2 possible endings | 5+ endings based on choices |
| **Audio** | Basic music/SFX | Full soundtrack | Dynamic music system |
| **Polish** | Functional UI | Polished UI/animations | Particle effects, screenshake |
| **Testing** | Manual testing | Unit tests for systems | Full integration testing |


## 8. Implementation Dependencies

```
Foundation Layer (Week 1)
│
├── GameState & SceneManager
├── PlayerController
├── Basic Interaction System
└── StoryFlagManager
      │
      ▼
Parallel Systems (Week 2-3)
│
├── DialogueManager ──┬── RelationshipManager
├── QuestManager      │
├── NPCController     │
├── SaveManager       │
└── AudioManager      │
      │               │
      ▼               ▼
Integration Layer (Week 3-4)
│
├── Dialogue ↔ Quests ↔ Relationships
├── NPCs ↔ Dialogue ↔ Story Flags
└── Save ↔ All Systems
      │
      ▼
Content Production (Week 4-6)
│
├── Environment Scenes (Dev 2)
├── Dialogue Trees (Dev 2)
├── Quest Definitions (Dev 2)
├── NPC Placement (Dev 2)
└── Asset Integration (Dev 2)
      │
      ▼
Polish & Testing (Week 6-7)
│
├── UI Polish
├── Audio Integration
├── Bug Fixes
├── Playtesting
└── Build & Export
```

**Critical Path**:
1. GameState + SceneManager (foundation)
2. PlayerController + Interaction (player can move and interact)
3. DialogueManager + NPCController (conversations work)
4. QuestManager (objectives track)
5. Environment scenes (places to explore)
6. Dialogue content (conversations to have)
7. Integration testing (everything works together)


## 9. Technical Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **JSON dialogue parsing errors** | High | Medium | Validate JSON schemas, provide clear error messages, test with malformed data |
| **Save/load data corruption** | High | Low | Version saves, validate on load, backup before save |
| **Performance issues with many NPCs** | Medium | Low | Object pooling, limit active NPCs per scene, optimize pathfinding |
| **Dialogue condition logic bugs** | High | Medium | Comprehensive testing, logging for condition checks, debug UI |
| **Quest state desync** | High | Medium | Centralized state management, event-driven updates, thorough testing |
| **Two-developer merge conflicts** | Medium | High | Clear folder ownership, small frequent commits, communication |
| **Scope creep beyond MVP** | High | High | Strict MVP feature list, defer post-MVP features, focus on core loop |
| **Time constraints (hackathon)** | High | High | Prioritize core features, have fallback simplified features, start early |
| **Asset creation bottleneck** | Medium | Medium | Use placeholder art initially, parallel content creation, reuse assets |
| **Complex engineering simulation** | Low | Medium | Simplify for MVP (display-only), polish post-MVP |


## 10. Testing Strategy

### Unit Testing

**Focus Areas**:
- RelationshipManager: Trust/Bond calculations, thresholds
- QuestManager: Objective tracking, completion logic
- EngineeringSimulation: Physics calculations
- StoryFlagManager: Flag setting/getting

**Example Test**:
```gdscript
# tests/unit/test_relationship_manager.gd
extends GutTest

func test_trust_increase():
	RelationshipManager.reset()
	RelationshipManager.set_relationship("maya_chen", "trust", 50)
	RelationshipManager.change_relationship("maya_chen", "trust", 10)
	assert_eq(RelationshipManager.get_relationship("maya_chen", "trust"), 60)

func test_trust_clamped_at_100():
	RelationshipManager.set_relationship("maya_chen", "trust", 95)
	RelationshipManager.change_relationship("maya_chen", "trust", 10)
	assert_eq(RelationshipManager.get_relationship("maya_chen", "trust"), 100)
```

### Integration Testing

**Focus Areas**:
- Dialogue → Quest activation
- Quest completion → Relationship changes
- Story flags → Dialogue branches
- Save → Load → State restoration

**Manual Test Cases**:
1. Complete a quest, verify relationship increase
2. Save game mid-dialogue, reload, verify state
3. Trigger dialogue condition, verify correct branch
4. Complete all objectives, verify quest completion

### Manual Playtesting

**Test Scenarios**:
- Complete prologue start-to-finish (30-45 min)
- Test all dialogue branches with each NPC
- Verify quest journal updates correctly
- Save/load at various points
- Check all environment transitions


## 11. Performance Considerations

### Optimization Patterns

**Scene Management**:
- Unload scenes when transitioning to conserve memory
- Use instance pooling for frequently created/destroyed objects
- Limit active NPCs per scene to 6-8

**Dialogue System**:
- Cache parsed JSON after first load
- Lazy-load dialogue trees only when needed
- Clear dialogue cache after scene transitions

**Rendering**:
- Use TileMapLayer efficiently (merge adjacent tiles)
- Limit AnimatedSprite2D frame count (8-12 frames max)
- Use viewport scaling (640×360 → display) for consistent pixel art

**Audio**:
- Stream long music tracks
- Load sound effects into memory (< 1MB each)
- Limit simultaneous sound effects to 16

**Save/Load**:
- Compress save files (if > 100KB)
- Async save (don't block game thread)
- Limit autosave frequency (every 5 minutes max)

### Performance Targets

- **FPS**: 60 on minimum spec (Intel i5, 8GB RAM, integrated GPU)
- **Load times**: < 2 seconds per scene transition
- **Save time**: < 1 second
- **Memory**: < 512MB total usage


## 12. Build & Deployment

### Export Presets

**Windows Export**:
- Platform: Windows Desktop
- Architecture: x86_64
- Executable: VoyagerIsNotAlone.exe
- Include: All resources, embedded PCK

**macOS Export**:
- Platform: macOS
- Architecture: Universal (x86_64 + arm64)
- Bundle: VoyagerIsNotAlone.app
- Code signing: Developer ID (for distribution)

### Build Automation

**GitHub Actions Workflow** (future):
```yaml
name: Build Game
on: [push, pull_request]
jobs:
  build-windows:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Export Windows
        uses: firebelley/godot-export@v5
        with:
          godot_version: 4.7
          export_preset: Windows
```

### Distribution

**MVP (Hackathon)**:
- Itch.io upload (Windows + macOS builds)
- GitHub release with binaries
- README with instructions

**Post-MVP**:
- Steam (if expanded)
- GOG (if expanded)
- Press kit with screenshots/trailer


---

## Implementation Notes for Developer 2 (Dias)

### Getting Started

1. **Familiarize with JSON schemas** in sections 3.5, 3.6, 4.1-4.5
2. **Start with one NPC dialogue** (Maya Chen recommended)
3. **Create one environment scene** (residential_deck_01)
4. **Place NPCs in scene** using prefabs from Dev 1
5. **Test dialogue flow** by playing the scene
6. **Create quest JSON** that references dialogue
7. **Iterate and expand**

### Content Creation Workflow

**For each environment**:
1. Create .tscn file in `scenes/environments/station/`
2. Add TileMapLayer with station tileset
3. Place walls, floors, furniture
4. Add doors (link to other scenes)
5. Add terminals/interactables
6. Place NPC instances
7. Set PlayerSpawn marker

**For each NPC conversation**:
1. Create JSON in `data/dialogues/`
2. Follow schema from section 3.5
3. Start with greeting node
4. Add 2-3 response branches
5. Include relationship effects
6. Link to quest start/update
7. Test in-game

**For each quest**:
1. Create JSON in `data/quests/`
2. Define 3-5 objectives
3. Link objectives to dialogue nodes
4. Set rewards (flags, relationships)
5. Test completion flow

### Tools & Resources

- **JSON Validator**: Use online JSON validator to check syntax
- **Godot Scene Editor**: Visual editor for environment layout
- **Asset Organization**: Keep sprites organized by character/category
- **Dialogue Flowchart**: Sketch dialogue trees on paper before JSON
- **Quest Tracker**: Use checklist to track quest implementation status

---

**End of Technical Design Document**

*Version 1.0 - Complete specification for two-developer Godot 4.7 implementation*
*Total sections: 12 major sections + subsections*
*Estimated document length: ~2100 lines*
