# SceneManager
# Handles scene transitions with smooth loading and state preservation
# Autoload singleton: res://scripts/core/scene_manager.gd
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal scene_transition_started(scene_path: String)
signal scene_transition_completed(scene_path: String)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var current_scene: Node = null
var is_transitioning: bool = false

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
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
	
	# Unload current scene
	if current_scene == null:
		current_scene = get_tree().current_scene
	if current_scene != null:
		current_scene.queue_free()
		await current_scene.tree_exited
	
	# Load new scene
	var new_scene_resource: PackedScene = load(scene_path)
	if new_scene_resource == null:
		push_error("SceneManager: Failed to load scene: %s" % scene_path)
		is_transitioning = false
		return
	
	current_scene = new_scene_resource.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Play transition in animation
	await play_transition_in(transition_type)
	
	is_transitioning = false
	scene_transition_completed.emit(scene_path)
	print("SceneManager: Transition complete")

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func play_transition_out(type: String) -> void:
	"""Play transition out animation"""
	# TODO: Implement actual transition animations
	# For now, just wait a short time
	match type:
		"fade":
			await get_tree().create_timer(0.3).timeout
		"wipe":
			await get_tree().create_timer(0.4).timeout
		"instant":
			pass
		_:
			await get_tree().create_timer(0.3).timeout

func play_transition_in(type: String) -> void:
	"""Play transition in animation"""
	# TODO: Implement actual transition animations
	match type:
		"fade":
			await get_tree().create_timer(0.3).timeout
		"wipe":
			await get_tree().create_timer(0.4).timeout
		"instant":
			pass
		_:
			await get_tree().create_timer(0.3).timeout
