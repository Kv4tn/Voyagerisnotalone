# AudioManager
# Manages music and sound effects
# Autoload singleton: res://scripts/core/audio_manager.gd
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

const DEFAULT_VOLUME: float = 0.8
const DEFAULT_MUSIC_VOLUME: float = 0.6
const DEFAULT_SFX_VOLUME: float = 0.8

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var master_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("AudioManager: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func play_music(music_name: String) -> void:
	"""Play background music"""
	# TODO: Implement in Task 10.1
	print("AudioManager: play_music() - Not yet implemented")
	print("  music_name: %s" % music_name)

func play_sfx(sfx_name: String) -> void:
	"""Play sound effect"""
	# TODO: Implement in Task 10.1
	print("AudioManager: play_sfx() - Not yet implemented")
	print("  sfx_name: %s" % sfx_name)

func set_master_volume(volume: float) -> void:
	"""Set master volume (0.0 to 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)

func set_music_volume(volume: float) -> void:
	"""Set music volume (0.0 to 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)

func set_sfx_volume(volume: float) -> void:
	"""Set SFX volume (0.0 to 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
