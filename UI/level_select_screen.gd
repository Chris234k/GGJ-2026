extends Control
## Level Select Screen - Allows the player to pick any level from a grid.
## Dynamically builds one button per level inside a GridContainer.
## Emits `level_selected(index)` when a level is chosen, or `back_requested`
## when the player presses ESC to return to the start screen.

signal level_selected(index: int)
signal back_requested

@onready var level_grid: GridContainer = $Content/LevelGrid
@onready var back_hint: RichTextLabel = $Content/BackHint

var _tween: Tween

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# ESC returns to the start screen. We check the "pause" action because
	# that's what ESC is mapped to in the project input map.
	if event.is_action_pressed("pause"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

## Build the level button grid. Clears any existing buttons first so this
## can be called multiple times safely. Uses immediate free() instead of
## queue_free() so the function is synchronous — callers don't need to await.
func populate_levels(count: int) -> void:
	# Remove old buttons immediately. Collect them first to avoid modifying
	# the children array while iterating.
	var old_buttons := level_grid.get_children()
	for child in old_buttons:
		level_grid.remove_child(child)
		child.free()

	var font := load("res://UI/Fonts/ChicagoFLF.ttf") as Font

	for i in count:
		var btn := Button.new()
		btn.text = "Level %d" % (i + 1)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Style to match the green terminal aesthetic used by pause_screen buttons.
		# Each state shares the same border/margin but varies in color intensity.
		var style_normal := _make_stylebox(Color(0.0, 0.3, 0.15, 0.8), Color(0.0, 0.85, 0.42, 0.7))
		var style_hover := _make_stylebox(Color(0.0, 0.35, 0.18, 0.85), Color(0.0, 0.85, 0.42, 0.7))
		var style_focus := _make_stylebox(Color(0.0, 0.4, 0.2, 0.9), Color(0.0, 1.0, 0.5, 1.0))

		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.add_theme_stylebox_override("focus", style_focus)
		btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 0.5, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.0, 1.0, 0.4, 1.0))
		btn.add_theme_color_override("font_focus_color", Color(0.0, 1.0, 0.5, 1.0))
		btn.add_theme_font_size_override("font_size", 20)

		if font:
			btn.add_theme_font_override("font", font)

		# Connect pressed signal. Use bind() to pass the level index.
		btn.pressed.connect(_on_level_button_pressed.bind(i))

		level_grid.add_child(btn)

	_setup_focus_neighbors()

## Called by game.gd to show the screen. Starts the hint pulse animation.
func show_screen() -> void:
	visible = true
	_start_pulse()
	# Grab focus on the first button so keyboard works immediately.
	if level_grid.get_child_count() > 0:
		level_grid.get_child(0).grab_focus()

func hide_screen() -> void:
	visible = false
	if _tween:
		_tween.kill()
		_tween = null

## Looping tween that pulses the back hint label's opacity,
## same style as start_screen and end_screen.
func _start_pulse() -> void:
	if _tween:
		_tween.kill()
	back_hint.modulate.a = 1.0
	_tween = create_tween().set_loops()
	_tween.tween_property(back_hint, "modulate:a", 0.3, 0.8)
	_tween.tween_property(back_hint, "modulate:a", 1.0, 0.8)

func _on_level_button_pressed(index: int) -> void:
	level_selected.emit(index)

## Create a StyleBoxFlat with a 2px border and standard content margins.
## Only bg_color and border_color vary between button states.
func _make_stylebox(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style

## Configure focus neighbors on buttons so arrow keys navigate the grid
## correctly. Godot's GridContainer doesn't do this automatically —
## we need to tell each button which neighbor to focus when Up/Down/Left/Right
## is pressed. The grid has `columns` columns (set in the scene, default 4).
func _setup_focus_neighbors() -> void:
	var cols: int = level_grid.columns
	var buttons := level_grid.get_children()

	for i in buttons.size():
		var btn: Button = buttons[i] as Button

		# Left/right: simply go to previous/next button (wraps across rows)
		if i > 0:
			btn.focus_neighbor_left = btn.get_path_to(buttons[i - 1])
		if i + 1 < buttons.size():
			btn.focus_neighbor_right = btn.get_path_to(buttons[i + 1])

		# Up neighbor: same column in previous row
		var up_index: int = i - cols
		if up_index >= 0:
			btn.focus_neighbor_top = btn.get_path_to(buttons[up_index])

		# Down neighbor: same column in next row (if it exists)
		var down_index: int = i + cols
		if down_index < buttons.size():
			btn.focus_neighbor_bottom = btn.get_path_to(buttons[down_index])
