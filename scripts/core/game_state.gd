# GameState
# Central coordinator for all game state, story progress, and system initialization
# Autoload singleton: res://scripts/core/game_state.gd
extends Node
class_name GameStateClass

# ============================================================================
# SIGNALS
# ============================================================================

signal game_started()
signal game_paused()
signal game_resumed()
signal chapter_changed(new_chapter: int)

# ============================================================================
# CONSTANTS
# ============================================================================

const TOTAL_CHAPTERS: int = 7

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var player_name: String = ""
var current_chapter: int = 1
var is_paused: bool = false
var game_started: bool = false

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("GameState: Initializing...")
	initialize_systems()
	print("GameState: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func initialize_systems() -> void:
	"""Verify all manager systems are loaded"""
	assert(SceneManager != null, "SceneManager not loaded")
	assert(DialogueManager != null, "DialogueManager not loaded")
	assert(QuestManager != null, "QuestManager not loaded")
	assert(RelationshipManager != null, "RelationshipManager not loaded")
	assert(StoryFlagManager != null, "StoryFlagManager not loaded")
	assert(SaveManager != null, "SaveManager not loaded")
	assert(AudioManager != null, "AudioManager not loaded")
	assert(CrewTaskManager != null, "CrewTaskManager not loaded")
	assert(EngineeringSimulation != null, "EngineeringSimulation not loaded")
	assert(PuzzleManager != null, "PuzzleManager not loaded")
	print("GameState: All systems verified")

func start_new_game(p_name: String) -> void:
	"""Initialize a new game with player name"""
	if p_name.is_empty():
		push_error("GameState: Cannot start game with empty player name")
		return
	
	player_name = p_name
	current_chapter = 1
	game_started = true
	
	# Reset all managers
	QuestManager.reset()
	RelationshipManager.reset()
	StoryFlagManager.reset()
	
	print("GameState: New game started for player '%s'" % player_name)
	game_started.emit()
	
	# TODO: Load first scene when SceneManager is implemented
	# SceneManager.transition_to("res://scenes/environments/station/residential_deck_01.tscn")

func set_chapter(chapter: int) -> void:
	"""Change current chapter"""
	if chapter < 1 or chapter > TOTAL_CHAPTERS:
		push_error("GameState: Invalid chapter number %d" % chapter)
		return
	
	current_chapter = chapter
	print("GameState: Chapter changed to %d" % current_chapter)
	chapter_changed.emit(current_chapter)

func pause_game() -> void:
	"""Pause the game"""
	if is_paused:
		return
	
	is_paused = true
	get_tree().paused = true
	print("GameState: Game paused")
	game_paused.emit()

func resume_game() -> void:
	"""Resume the game"""
	if not is_paused:
		return
	
	is_paused = false
	get_tree().paused = false
	print("GameState: Game resumed")
	game_resumed.emit()

func quit_game() -> void:
	"""Quit the game"""
	print("GameState: Quitting game...")
	get_tree().quit()
