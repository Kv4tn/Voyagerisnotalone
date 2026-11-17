# Starfield
# One-pixel star dots for menu backgrounds. Placeholder until final art.
# Deterministic: the same star_seed always draws the same sky.
class_name Starfield
extends Control

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================

@export var star_count: int = 140
@export var star_seed: int = 1420
@export var star_color: Color = Color(0.85, 0.92, 0.95, 1.0)
## Share of stars drawn amber instead of star_color.
@export_range(0.0, 1.0) var warm_ratio: float = 0.08
@export var warm_color: Color = Color(0.88, 0.63, 0.25, 1.0)

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = star_seed
	for i: int in star_count:
		var position_px: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y).floor()
		var brightness: float = rng.randf_range(0.25, 1.0)
		var base: Color = warm_color if rng.randf() < warm_ratio else star_color
		draw_rect(Rect2(position_px, Vector2.ONE), Color(base, brightness))
