# PlayerController
# Top-down astronaut movement and interaction.
# Attached to: res://scenes/player/player.tscn
class_name PlayerController
extends CharacterBody2D

# ============================================================================
# SIGNALS
# ============================================================================

## Emitted when the closest usable Interactable changes (null when none in range).
signal interaction_target_changed(target: Interactable)

# ============================================================================
# CONSTANTS
# ============================================================================

const SPEED: float = 120.0
## Minimum time between two interactions, prevents double-triggers.
const INTERACT_COOLDOWN: float = 0.2

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

## While true the player neither moves nor interacts (message box, dialogue, menus).
var input_locked: bool = false
var last_direction: Vector2 = Vector2.DOWN
var current_target: Interactable = null

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _cooldown_left: float = 0.0

@onready var _interaction_area: Area2D = $InteractionArea

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if input_locked:
		velocity = Vector2.ZERO
	else:
		# get_vector clamps to length 1, so diagonals are already normalized.
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction != Vector2.ZERO:
			last_direction = direction.normalized()
		velocity = direction * SPEED

	move_and_slide()
	_update_interaction_target()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if input_locked or _cooldown_left > 0.0 or current_target == null:
		return

	get_viewport().set_input_as_handled()
	_cooldown_left = INTERACT_COOLDOWN
	current_target.interact(self)

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func lock_input() -> void:
	input_locked = true
	velocity = Vector2.ZERO

func unlock_input() -> void:
	input_locked = false
	_cooldown_left = INTERACT_COOLDOWN

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _update_interaction_target() -> void:
	var closest: Interactable = null
	var closest_distance: float = INF

	for area: Area2D in _interaction_area.get_overlapping_areas():
		var candidate: Interactable = area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate

	if closest != current_target:
		current_target = closest
		interaction_target_changed.emit(current_target)
