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
@export var auto_start: bool = false

var _current_level_index: int = 0
var _current_level_instance: Node = null

@onready var level_slot: Node = $LevelSlot
@onready var hud_ui: Control = $UILayer/HudUi
@onready var start_screen: Control = $UILayer/StartScreen
@onready var level_select_screen: Control = $UILayer/LevelSelectScreen
@onready var pause_screen: Control = $UILayer/PauseScreen
@onready var end_screen: Control = $UILayer/EndScreen

func _ready() -> void:
	GameManager.level_completed.connect(_on_level_completed)
	start_screen.start_requested.connect(_on_start_requested)
	start_screen.level_select_requested.connect(_on_level_select_requested)
	level_select_screen.level_selected.connect(_on_level_selected)
	level_select_screen.back_requested.connect(_on_level_select_back)
	pause_screen.resume_requested.connect(_on_resume_requested)
	pause_screen.quit_requested.connect(_on_quit_requested)
	end_screen.menu_requested.connect(_on_end_menu_requested)

	# Show the correct UI for the initial state. If auto_start is true
	# (useful for debugging), skip the start screen and jump into gameplay.
	if auto_start:
		start_game()
	else:
		_update_ui_for_state(GameState.MAIN_MENU)

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

func start_game(level_index: int = 0) -> void:
	_current_level_index = level_index
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
	# If paused, unpause first so the tree isn't frozen during reset.
	if get_tree().paused:
		pause_screen.unpause()
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
	_update_ui_for_state(new_state)
	game_state_changed.emit(new_state)
	print("Game state: %s" % GameState.keys()[new_state])

## Show/hide UI elements based on the current game state.
## Start screen is only visible in MAIN_MENU; HUD is only visible while PLAYING.
func _update_ui_for_state(state: GameState) -> void:
	# Start screen and end screen use show/hide methods so they can
	# start/stop their pulse tweens cleanly.
	if state == GameState.MAIN_MENU:
		start_screen.show_screen()
	else:
		start_screen.hide_screen()

	# Level select is not tied to a state — it's a sub-screen of MAIN_MENU.
	# Hide it on any state change so it doesn't linger when starting a game
	# or returning to menu.
	level_select_screen.hide_screen()

	if state == GameState.GAME_OVER:
		end_screen.show_screen()
	else:
		end_screen.hide_screen()

	hud_ui.visible = (state == GameState.PLAYING)
	# Disable HUD input processing when not playing so A/S/D/F/Tab/Space
	# don't accidentally toggle bits on menu screens.
	hud_ui.set_process(state == GameState.PLAYING)
	pause_screen.can_pause = (state == GameState.PLAYING)

func _on_start_requested() -> void:
	start_game()

func _on_resume_requested() -> void:
	pause_screen.unpause()

func _on_quit_requested() -> void:
	# Unpause first so the tree isn't frozen when we transition states.
	pause_screen.unpause()
	return_to_menu()

func _on_end_menu_requested() -> void:
	return_to_menu()

func _on_level_select_requested() -> void:
	start_screen.hide_screen()
	level_select_screen.populate_levels(level_scenes.size())
	level_select_screen.show_screen()

func _on_level_selected(index: int) -> void:
	level_select_screen.hide_screen()
	start_game(index)

func _on_level_select_back() -> void:
	level_select_screen.hide_screen()
	start_screen.show_screen()

func _on_level_completed() -> void:
	if current_state == GameState.PLAYING:
		advance_level()
