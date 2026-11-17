# GameState
# Central coordinator for all game state, story progress, and system initialization
# Autoload singleton: res://scripts/core/game_state.gd
extends Node
class_name GameStateClass

# ============================================================================
# SIGNALS
# ============================================================================

# Named new_game_started (not game_started) so it does not clash with the
# game_started bool below; GDScript forbids a signal and a member sharing a name.
signal new_game_started()
signal game_paused()
signal game_resumed()
signal chapter_changed(new_chapter: int)
signal player_name_changed(new_name: String)

# ============================================================================
# CONSTANTS
# ============================================================================

const TOTAL_CHAPTERS: int = 7
const MIN_PLAYER_NAME_LENGTH: int = 2
const MAX_PLAYER_NAME_LENGTH: int = 20
## Scene loaded by start_new_game(). Points at the prototype room until the
## Residential Deck exists.
const FIRST_SCENE_PATH: String = "res://scenes/prototype/prototype_room.tscn"
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu.tscn"

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var player_name: String = ""
var current_chapter: int = 1
var is_paused: bool = false
var game_started: bool = false
var game_time: float = 0.0  # Total game time in seconds
var chapter_start_time: float = 0.0  # Time when current chapter started

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _systems_initialized: bool = false
var _player_name_regex: RegEx = null

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("GameState: Initializing...")
	initialize_systems()
	print("GameState: Ready")

func _process(delta: float) -> void:
	if game_started and not is_paused:
		game_time += delta

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
	
	_systems_initialized = true
	print("GameState: All systems verified")

func start_new_game(p_name: String) -> void:
	"""
	Initialize a new game with player name and load the first scene
	@param p_name: Player's chosen name; surrounding spaces are removed
	"""
	var clean_name: String = p_name.strip_edges()
	if not validate_player_name(clean_name):
		push_error("GameState: Invalid player name: '%s'" % p_name)
		return
	
	player_name = clean_name
	current_chapter = 1
	game_started = true
	game_time = 0.0
	chapter_start_time = 0.0
	
	# Reset all managers
	QuestManager.reset()
	RelationshipManager.reset()
	StoryFlagManager.reset()
	
	# Set initial story flags
	StoryFlagManager.set_flag("game_started", true)
	StoryFlagManager.set_flag("player_name_set", true)
	
	print("GameState: New game started for player '%s'" % player_name)
	new_game_started.emit()
	player_name_changed.emit(player_name)
	
	SceneManager.transition_to(FIRST_SCENE_PATH)

func set_player_name(new_name: String) -> bool:
	"""
	Change player name
	@param new_name: New player name
	@return: True if name was changed successfully
	"""
	var clean_name: String = new_name.strip_edges()
	# validate_player_name() already warns; the caller handles the false.
	if not validate_player_name(clean_name):
		return false
	
	var old_name: String = player_name
	player_name = clean_name
	StoryFlagManager.set_flag("player_name_set", true)
	
	print("GameState: Player name changed from '%s' to '%s'" % [old_name, player_name])
	player_name_changed.emit(player_name)
	return true

func validate_player_name(candidate: String) -> bool:
	"""
	Validate player name meets requirements (REQ-3)
	@param candidate: Name to validate, already trimmed
	@return: True if name is valid
	"""
	var error: String = get_player_name_error(candidate)
	if not error.is_empty():
		push_warning("GameState: " + error)
		return false
	return true

func get_player_name_error(candidate: String) -> String:
	"""
	Explain why a name is invalid, for display on the name entry screen
	@param candidate: Name to check, already trimmed
	@return: Player-facing error text, or "" when the name is valid
	"""
	if candidate.is_empty():
		return "Enter a name."
	if candidate.length() < MIN_PLAYER_NAME_LENGTH:
		return "Name must be at least %d characters." % MIN_PLAYER_NAME_LENGTH
	if candidate.length() > MAX_PLAYER_NAME_LENGTH:
		return "Name must be at most %d characters." % MAX_PLAYER_NAME_LENGTH
	# Any script's letters and digits plus single inner spaces, so names in
	# the planned Russian and Kazakh localizations are accepted too.
	if not _name_regex().search(candidate):
		return "Use only letters, digits and single spaces between words."
	return ""

func _name_regex() -> RegEx:
	if _player_name_regex == null:
		_player_name_regex = RegEx.new()
		_player_name_regex.compile("^[\\p{L}\\p{N}]+( [\\p{L}\\p{N}]+)*$")
	return _player_name_regex

func set_chapter(chapter: int) -> void:
	"""
	Change current chapter
	@param chapter: Chapter number (1-7)
	"""
	if chapter < 1 or chapter > TOTAL_CHAPTERS:
		push_error("GameState: Invalid chapter number %d (must be 1-%d)" % [chapter, TOTAL_CHAPTERS])
		return
	
	if chapter == current_chapter:
		push_warning("GameState: Already in chapter %d" % chapter)
		return
	
	var old_chapter: int = current_chapter
	current_chapter = chapter
	chapter_start_time = game_time
	
	print("GameState: Chapter changed from %d to %d" % [old_chapter, current_chapter])
	chapter_changed.emit(current_chapter)
	
	# Update story flag
	StoryFlagManager.set_flag("current_chapter", current_chapter)

func get_chapter_time() -> float:
	"""
	Get time spent in current chapter
	@return: Time in seconds
	"""
	return game_time - chapter_start_time

func get_formatted_game_time() -> String:
	"""
	Get formatted game time string (HH:MM:SS)
	@return: Formatted time string
	"""
	var total_seconds: int = int(game_time)
	@warning_ignore("integer_division")
	var hours: int = total_seconds / 3600
	@warning_ignore("integer_division")
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func pause_game() -> void:
	"""Pause the game"""
	if is_paused:
		push_warning("GameState: Game already paused")
		return
	
	is_paused = true
	get_tree().paused = true
	print("GameState: Game paused")
	game_paused.emit()

func resume_game() -> void:
	"""Resume the game"""
	if not is_paused:
		push_warning("GameState: Game not paused")
		return
	
	is_paused = false
	get_tree().paused = false
	print("GameState: Game resumed")
	game_resumed.emit()

func toggle_pause() -> void:
	"""Toggle pause state"""
	if is_paused:
		resume_game()
	else:
		pause_game()

func quit_game() -> void:
	"""Quit the game"""
	print("GameState: Quitting game...")
	get_tree().quit()

func reset_game() -> void:
	"""Reset game to initial state"""
	player_name = ""
	current_chapter = 1
	is_paused = false
	game_started = false
	game_time = 0.0
	chapter_start_time = 0.0
	
	# Reset all managers
	QuestManager.reset()
	RelationshipManager.reset()
	StoryFlagManager.reset()
	
	print("GameState: Game reset to initial state")

func get_game_state_data() -> Dictionary:
	"""
	Get current game state as dictionary (for saving)
	@return: Dictionary containing all game state
	"""
	return {
		"player_name": player_name,
		"current_chapter": current_chapter,
		"game_time": game_time,
		"chapter_start_time": chapter_start_time,
		"game_started": game_started
	}

func set_game_state_data(data: Dictionary) -> void:
	"""
	Restore game state from dictionary (for loading)
	@param data: Dictionary containing game state
	"""
	if data.has("player_name"):
		player_name = data["player_name"]
	if data.has("current_chapter"):
		current_chapter = data["current_chapter"]
	if data.has("game_time"):
		game_time = data["game_time"]
	if data.has("chapter_start_time"):
		chapter_start_time = data["chapter_start_time"]
	if data.has("game_started"):
		game_started = data["game_started"]
	
	print("GameState: State restored from save data")
