# Coding Standards: Voyager Is Not Alone

## GDScript Style Guide

### File Organization

Every GDScript file must follow this structure:

```gdscript
# Brief description of what this script does
extends ParentClass
class_name ClassName

# ============================================================================
# SIGNALS
# ============================================================================

signal signal_name(param: Type)
signal another_signal()

# ============================================================================
# CONSTANTS
# ============================================================================

const MAX_SPEED: float = 120.0
const INTERACTION_RANGE: float = 32.0

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

@export var exported_property: int = 10
@export_category("Movement")
@export var speed: float = 100.0

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var public_variable: String = ""
var another_public: Resource = null

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _private_variable: int = 0
var _internal_state: bool = false

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func public_method(param: String) -> bool:
	return true

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _private_method() -> void:
	pass

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_signal_received(data: Variant) -> void:
	pass
```

### Naming Conventions

**Files and Folders**:
- Scene files: `snake_case.tscn` (e.g., `residential_deck.tscn`)
- Script files: `snake_case.gd` (e.g., `player_controller.gd`)
- Folders: `snake_case/` (e.g., `scripts/core/`)

**Classes and Types**:
- Class names: `PascalCase` (e.g., `class_name PlayerController`)
- Enums: `PascalCase` for enum name, `UPPER_CASE` for values
  ```gdscript
  enum MovementState { IDLE, WALKING, RUNNING }
  ```

**Variables**:
- Public variables: `snake_case` (e.g., `var player_name: String`)
- Private variables: `_snake_case` (e.g., `var _internal_timer: float`)
- Constants: `UPPER_CASE` (e.g., `const MAX_HEALTH: int = 100`)
- Exported variables: `snake_case` (e.g., `@export var movement_speed: float`)

**Functions**:
- Public functions: `snake_case` (e.g., `func get_player_position()`)
- Private functions: `_snake_case` (e.g., `func _update_animation()`)
- Signal handlers: `_on_<emitter>_<signal>` (e.g., `func _on_button_pressed()`)

**Signals**:
- Signal names: `snake_case` (e.g., `signal dialogue_started`)
- Use past tense for completed events: `dialogue_ended`, `quest_completed`
- Use present tense for state changes: `relationship_changed`

### Type Annotations

**Always use type annotations**:

```gdscript
# ✅ CORRECT
var health: int = 100
var player_name: String = ""
var current_scene: Node = null

func calculate_damage(base: float, multiplier: float) -> float:
	return base * multiplier

# ❌ INCORRECT
var health = 100
var player_name = ""

func calculate_damage(base, multiplier):
	return base * multiplier
```

**Collection types**:
```gdscript
var string_array: Array[String] = []
var int_dictionary: Dictionary = {}  # Godot 4.x doesn't support typed Dictionary yet
```

### Code Formatting

**Indentation**: Use tabs (Godot default)

**Line length**: Maximum 100 characters

**Spacing**:
```gdscript
# ✅ CORRECT spacing
var value: int = calculate_value(10, 20)
if condition:
	do_something()

# ❌ INCORRECT spacing
var value:int=calculate_value(10,20)
if condition:do_something()
```

**Blank lines**:
- One blank line between methods
- Two blank lines between major sections
- Use section dividers for clarity

### Error Handling

**Always validate inputs**:
```gdscript
func load_dialogue(dialogue_id: String) -> void:
	if dialogue_id.is_empty():
		push_error("load_dialogue: dialogue_id cannot be empty")
		return
	
	if not _dialogue_data.has(dialogue_id):
		push_warning("load_dialogue: dialogue_id '%s' not found" % dialogue_id)
		return
	
	# Proceed with valid dialogue_id
```

**Use assertions for development-time checks**:
```gdscript
func _ready() -> void:
	assert(DialogueManager != null, "DialogueManager not loaded")
	assert(movement_speed > 0, "movement_speed must be positive")
```

**Prefer early returns**:
```gdscript
# ✅ CORRECT - early return
func process_interaction(target: Node) -> void:
	if target == null:
		return
	
	if not target.has_method("interact"):
		return
	
	target.interact()

# ❌ INCORRECT - nested conditions
func process_interaction(target: Node) -> void:
	if target != null:
		if target.has_method("interact"):
			target.interact()
```

### Comments and Documentation

**File headers**:
```gdscript
# PlayerController
# Handles top-down player movement, animation, and input
# Attached to: res://scenes/player/player.tscn
```

**Function documentation**:
```gdscript
## Calculates the delta-v available for a given fuel mass
## Uses the Tsiolkovsky rocket equation: Δv = ve * ln(m0/mf)
## @param fuel_mass: Current fuel mass in kg
## @return: Available delta-v in m/s
func calculate_delta_v(fuel_mass: float) -> float:
	# Implementation
	pass
```

**Inline comments**:
- Explain **why**, not **what**
- Use `#` for single-line comments
- Keep comments up-to-date with code

```gdscript
# ✅ GOOD comment
# Normalize diagonal movement to prevent faster diagonal speed
velocity = velocity.normalized() * movement_speed

# ❌ BAD comment
# Normalize the velocity
velocity = velocity.normalized() * movement_speed
```

### Constants and Magic Numbers

**Always define magic numbers as constants**:

```gdscript
# ✅ CORRECT
const INTERACTION_RANGE: float = 32.0
const MAX_DIALOGUE_OPTIONS: int = 4

func check_interaction_range(distance: float) -> bool:
	return distance <= INTERACTION_RANGE

# ❌ INCORRECT
func check_interaction_range(distance: float) -> bool:
	return distance <= 32.0
```

### Signal Usage

**Define signals at the top of the file**:
```gdscript
signal dialogue_started(dialogue_id: String)
signal dialogue_ended()
signal relationship_changed(character_id: String, trust: int, bond: int)
```

**Emit signals with type-safe parameters**:
```gdscript
# ✅ CORRECT
dialogue_started.emit("maya_intro_001")

# ❌ INCORRECT
emit_signal("dialogue_started", "maya_intro_001")  # Old syntax
```

**Connect signals using callables**:
```gdscript
# ✅ CORRECT (Godot 4.x)
DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

# ❌ INCORRECT (Old Godot 3.x syntax)
DialogueManager.connect("dialogue_ended", self, "_on_dialogue_ended")
```

### Resource Management

**Preload resources when possible**:
```gdscript
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
```

**Load resources at runtime only when necessary**:
```gdscript
var dialogue_data: Dictionary = {}

func load_dialogue_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open dialogue file: %s" % path)
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		push_error("Failed to parse dialogue JSON: %s" % path)
		return
	
	dialogue_data = json.data
```

**Free resources properly**:
```gdscript
func _exit_tree() -> void:
	# Clean up resources
	if current_scene != null:
		current_scene.queue_free()
```

## JSON Data Standards

### File Structure

All JSON files must be valid and properly formatted:

```json
{
	"version": "1.0",
	"type": "dialogue",
	"metadata": {
		"author": "Dev2",
		"last_modified": "2024-12-01"
	},
	"data": {
		// Content here
	}
}
```

### Naming Conventions

**Keys**: Use `snake_case` for all JSON keys
```json
{
	"dialogue_id": "maya_intro_001",
	"speaker_id": "maya_chen",
	"response_options": []
}
```

**IDs**: Use descriptive, namespaced IDs
- Dialogue: `<character>_<context>_<number>` (e.g., `maya_intro_001`)
- Quest: `<chapter>_<type>_<name>` (e.g., `ch1_main_power_restoration`)
- NPC: `<role>_<name>` (e.g., `crew_maya`, `engineer_elias`)

## Testing Standards

### Unit Test Structure

```gdscript
extends GutTest

# Test file for PlayerController
# Location: res://tests/unit/test_player_controller.gd

var player: PlayerController = null

func before_each() -> void:
	player = PlayerController.new()
	add_child(player)

func after_each() -> void:
	player.queue_free()

func test_movement_speed_normalized() -> void:
	# Arrange
	var diagonal_input := Vector2(1, 1)
	
	# Act
	var velocity := player._calculate_velocity(diagonal_input)
	
	# Assert
	assert_almost_eq(velocity.length(), player.movement_speed, 0.01)

func test_interaction_range_detection() -> void:
	# Arrange
	var target := Node2D.new()
	add_child(target)
	target.position = Vector2(30, 0)
	
	# Act
	var in_range := player.is_in_interaction_range(target)
	
	# Assert
	assert_true(in_range, "Target at 30px should be within 32px range")
	
	# Cleanup
	target.queue_free()
```

### Test Naming

- Test files: `test_<class_name>.gd`
- Test functions: `test_<feature>_<expected_behavior>()`

### Test Coverage Goals

- Core systems: 80%+ coverage
- UI and scenes: Manual testing only
- Critical paths (save/load, engineering simulation): 100% coverage

## Git Commit Standards

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes

**Examples**:
```
feat(player): implement top-down movement with WASD

- Add CharacterBody2D controller
- Implement normalized diagonal movement
- Add collision detection with environment

Closes #15

---

fix(dialogue): prevent null reference in branching logic

The dialogue manager was crashing when conditional responses
referenced non-existent story flags.

Added null checks and default fallback values.

Fixes #23

---

refactor(quest): extract objective validation to separate method

Improves testability and reduces QuestManager complexity.
```

### Commit Frequency

- Commit after completing each subtask
- Minimum: one commit per hour of work
- Keep commits atomic (one logical change per commit)
- Never commit broken code to main branch

## Code Review Checklist

Before submitting code for review or merging:

- [ ] All functions have type annotations
- [ ] No magic numbers (all constants defined)
- [ ] Proper error handling with meaningful messages
- [ ] Code follows naming conventions
- [ ] Comments explain **why**, not **what**
- [ ] No compiler warnings
- [ ] Tests pass (if applicable)
- [ ] Scene references are valid
- [ ] No hardcoded file paths (use res:// paths)
- [ ] Signals are properly connected and disconnected
- [ ] Resources are freed in _exit_tree()
- [ ] Code is formatted consistently
- [ ] No debug print statements left in code

## Performance Guidelines

### Avoid in _process() and _physics_process()

- Expensive calculations (cache results instead)
- Resource loading (preload or load in _ready())
- String operations in hot paths
- Creating/destroying objects every frame

### Prefer

- Object pooling for frequently created/destroyed objects
- Cached references over get_node() calls in loops
- Signals over polling
- TileMapLayer for environments (not individual sprites)

### Example - Object Pooling

```gdscript
# ✅ CORRECT - Object pool for sound effects
var _sfx_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 10

func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.finished.connect(_on_sfx_finished.bind(player))
		_sfx_pool.append(player)

func play_sfx(stream: AudioStream) -> void:
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.play()
			return
```

## Deprecation Policy

When replacing or removing functionality:

1. Mark as deprecated with warning
2. Provide migration path
3. Keep deprecated code for at least 2 weeks
4. Remove after warning users

```gdscript
## @deprecated Use calculate_delta_v_with_exhaust() instead
func calculate_delta_v(fuel: float) -> float:
	push_warning("calculate_delta_v is deprecated. Use calculate_delta_v_with_exhaust instead.")
	return calculate_delta_v_with_exhaust(fuel, DEFAULT_EXHAUST_VELOCITY)
```
