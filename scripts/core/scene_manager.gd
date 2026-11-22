# SceneManager
# Handles scene transitions with smooth loading and state preservation
# Autoload singleton: res://scripts/core/scene_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal scene_transition_started(scene_path: String)
## The new scene is in the tree and current, but the screen is still dark.
## Use it to place the player before the fade-in.
signal scene_loaded(scene: Node)
signal scene_transition_completed(scene_path: String)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var current_scene: Node = null
var is_transitioning: bool = false

# ============================================================================
# CONSTANTS
# ============================================================================

const FADE_DURATION: float = 0.25
## Drawn above every game layer, including the HUD.
const FADE_LAYER: int = 100
const FADE_COLOR: Color = Color(0.016, 0.027, 0.055, 1.0)

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _fade_rect: ColorRect = null

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	# Keep fading even while the game is paused (e.g. "Return to menu" from pause).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_fade_overlay()
	print("SceneManager: Ready")
	# current_scene is resolved lazily in transition_to(). During autoload
	# _ready() the main scene is not in the tree yet, so the last child of
	# root would be an autoload and freeing it would break the game.

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func transition_to(scene_path: String, transition_type: String = "fade") -> void:
	"""
	Transition to a new scene with optional transition effect
	@param scene_path: Path to the scene to load (e.g., "res://scenes/...")
	@param transition_type: Type of transition ("fade", "wipe", "instant")
	"""
	if is_transitioning:
		push_warning("SceneManager: Already transitioning, ignoring request")
		return
	
	if not ResourceLoader.exists(scene_path):
		push_error("SceneManager: Scene not found: %s" % scene_path)
		return
	
	is_transitioning = true
	scene_transition_started.emit(scene_path)
	print("SceneManager: Transitioning to %s" % scene_path)
	
	# Play transition out animation
	await play_transition_out(transition_type)
	
	# Unload the scene that is current right now. Read it from the tree each
	# time: a cached reference goes stale if anything else changed scenes.
	var old_scene: Node = get_tree().current_scene
	if old_scene != null:
		old_scene.queue_free()
		await old_scene.tree_exited
	
	# Load new scene
	var new_scene_resource: PackedScene = load(scene_path)
	if new_scene_resource == null:
		push_error("SceneManager: Failed to load scene: %s" % scene_path)
		await play_transition_in(transition_type)
		is_transitioning = false
		return
	
	current_scene = new_scene_resource.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	scene_loaded.emit(current_scene)
	
	# Play transition in animation
	await play_transition_in(transition_type)
	
	is_transitioning = false
	scene_transition_completed.emit(scene_path)
	print("SceneManager: Transition complete")

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func play_transition_out(type: String) -> void:
	"""Fade the screen to FADE_COLOR. Mouse input is blocked from here on."""
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if type == "instant":
		_fade_rect.modulate.a = 1.0
		return
	# "wipe" is not implemented yet and falls back to a fade.
	await _tween_fade(1.0)

func play_transition_in(type: String) -> void:
	"""Fade back to the new scene and release mouse input."""
	if type == "instant":
		_fade_rect.modulate.a = 0.0
	else:
		await _tween_fade(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _tween_fade(target_alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", target_alpha, FADE_DURATION)
	await tween.finished

func _create_fade_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = FADE_LAYER
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = FADE_COLOR
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)
