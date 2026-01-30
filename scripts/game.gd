extends Node
## Game Container - Central game flow manager.
## Loads levels dynamically into LevelSlot, manages state transitions,
## and provides a UILayer CanvasLayer for shared UI.

# --- Signals ---
signal game_state_changed(new_state: int)

# --- Game States ---
enum GameState { MAIN_MENU, PLAYING, GAME_OVER }
var current_state: GameState = GameState.MAIN_MENU

# --- Level Configuration ---
@export var level_scenes: Array[PackedScene] = []
@export var auto_start: bool = true

var _current_level_index: int = 0
var _current_level_instance: Node = null

@onready var level_slot: Node = $LevelSlot

func _ready() -> void:
	GameManager.level_completed.connect(_on_level_completed)

	if auto_start:
		start_game()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# DEBUG: N = advance to next level
	if event.keycode == KEY_N:
		if current_state == GameState.PLAYING:
			print("DEBUG: next level")
			advance_level()

	if event.keycode == KEY_P:
		if current_state == GameState.PLAYING:
			if _current_level_index > 0:
				print("DEBUG: previous level")
				_current_level_index -= 1
				load_level(_current_level_index)

	# DEBUG: Shift+R = restart game
	if event.keycode == KEY_R and event.shift_pressed:
		print("DEBUG: Restarting game")
		restart_game()

# --- State Transitions ---

func start_game() -> void:
	_current_level_index = 0
	_set_state(GameState.PLAYING)
	load_level(_current_level_index)

func advance_level() -> void:
	_current_level_index += 1
	if _current_level_index < level_scenes.size():
		load_level(_current_level_index)
	else:
		game_over()

func game_over() -> void:
	_cleanup_level()
	_set_state(GameState.GAME_OVER)

func return_to_menu() -> void:
	_cleanup_level()
	GameManager.reset_game()
	_current_level_index = 0
	_set_state(GameState.MAIN_MENU)

func restart_game() -> void:
	return_to_menu()
	start_game()

# --- Level Loading ---

func load_level(index: int) -> void:
	if index < 0 or index >= level_scenes.size():
		push_error("Game: Level index %d out of range (0-%d)" % [index, level_scenes.size() - 1])
		game_over()
		return

	_cleanup_level()

	# Wait a frame for deferred frees to complete
	await get_tree().process_frame

	# Clear all GameManager registrations from the previous level
	GameManager.clear_all_registrations()
	GameManager.reset_level(true)
	GameManager.current_level = index + 1

	# Instance and add the new level
	var scene: PackedScene = level_scenes[index]
	_current_level_instance = scene.instantiate()
	level_slot.add_child(_current_level_instance)

	print("Loaded level %d: %s" % [index + 1, scene.resource_path])

func _cleanup_level() -> void:
	if _current_level_instance and is_instance_valid(_current_level_instance):
		_current_level_instance.queue_free()
		_current_level_instance = null

# --- Internal ---

func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)
	print("Game state: %s" % GameState.keys()[new_state])

func _on_level_completed() -> void:
	if current_state == GameState.PLAYING:
		advance_level()
