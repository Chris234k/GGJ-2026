extends Control
## HUD UI - Bitmask display with two modes:
##   Realtime: A/S/D/F directly toggle GameManager bits.
##   Submit:   A/S/D/F compose a local mask, Tab switches OR/AND, Space applies.
##
## Layout (submit mode):
##   [OR] [AND]       <- operation selector
##    A  S  D  F      <- key labels (always saturated bit color)
##    0  0  0  1      <- current GameManager bitmask (always bit color)
##    0  0  0  0      <- user mask bits (bit color if 1, white if 0)
##   ────────────
##    0  0  0  1      <- preview of operation result (bit color if 1, cyan if 0)

# --- Node References ---

@onready var labels: GridContainer = $Panel/VBox/Labels
@onready var current_bits: GridContainer = $Panel/VBox/CurrentBits
@onready var mask: GridContainer = $Panel/VBox/Mask
@onready var separator: HSeparator = $Panel/VBox/Separator
@onready var output: GridContainer = $Panel/VBox/Output
@onready var button_row: HBoxContainer = $Panel/VBox/ButtonRow
@onready var or_button: Button = $Panel/VBox/ButtonRow/OR
@onready var and_button: Button = $Panel/VBox/ButtonRow/AND

# --- Configuration ---

@export var realtime_mode: bool = false

# --- State ---

var user_mask: int = 0
var use_or: bool = true

# --- Constants ---

var _toggle_keys: Array[String] = ["toggle_bit_0", "toggle_bit_1", "toggle_bit_2", "toggle_bit_3"]
var _toggle_key_primary_name: Array[String]

const BIT_FONT_SIZE: int = 22
const LABEL_FONT_SIZE: int = 16
const BIT_CELL_MIN_SIZE: Vector2 = Vector2(28, 0)
const LABEL_CELL_MIN_SIZE: Vector2 = Vector2(28, 0)

# --- Helpers ---

## Convert a display index (0=leftmost) to a bit index, where the leftmost
## display position maps to the highest bit (MSB-first ordering).
func _display_to_bit(display_index: int) -> int:
	return (GameManager.max_bits - 1) - display_index

## Extract a single bit value (0 or 1) from a bitmask at the given display position.
func _get_display_bit(mask_value: int, display_index: int) -> int:
	return (mask_value >> _display_to_bit(display_index)) & 1

# =============================================================================
# Lifecycle
# =============================================================================

## Connect to GameManager signals, wire up buttons, and build the initial UI.
func _ready() -> void:
	# take the primary key from the action and use it as the label
	# "toggle_bit_0" -> "a"
	for i in _toggle_keys.size():
		var action_name = _toggle_keys[i]
		var actions := InputMap.action_get_events(action_name)
		var key_name = actions[0] as InputEventKey
		var keycode := OS.get_keycode_string(key_name.physical_keycode)
		_toggle_key_primary_name.push_back(keycode)

	GameManager.bitmask_updated.connect(_on_bitmask_updated)
	GameManager.max_bits_changed.connect(_on_max_bits_changed)
	or_button.focus_mode = Control.FOCUS_NONE
	and_button.focus_mode = Control.FOCUS_NONE
	or_button.pressed.connect(_on_or_pressed)
	and_button.pressed.connect(_on_and_pressed)
	_rebuild_ui()
	_sync_operation_buttons()

# =============================================================================
# Input
# =============================================================================

## Handle A/S/D/F (toggle bits), Tab (switch OR/AND), and Space (submit).
## In realtime mode, bit keys write directly to GameManager.
## In submit mode, bit keys compose a local mask and Space applies it.
func _process(delta: float) -> void:
	var max_b: int = GameManager.max_bits

	for i in range(mini(_toggle_keys.size(), max_b)):
		if Input.is_action_just_pressed(_toggle_keys[i]):
			if realtime_mode:
				GameManager.toggle_bit(_display_to_bit(i))
			else:
				user_mask ^= (1 << _display_to_bit(i))
				_refresh_row(mask, user_mask, "white")
				_refresh_row(output, _compute_preview(), "cyan")
			return

	if realtime_mode:
		return

	if Input.is_action_just_pressed("toggle_bit_operand"):
		use_or = not use_or
		_sync_operation_buttons()
		_refresh_row(output, _compute_preview(), "cyan")
		return

	if Input.is_action_just_pressed("confirm_bits"):
		_submit()
		return

# =============================================================================
# UI Build
# =============================================================================

## Tear down and regenerate all grid rows for the current max_bits count.
## Resets local state and hides submit-mode UI when in realtime mode.
func _rebuild_ui() -> void:
	var max_b: int = GameManager.max_bits

	_rebuild_grid(labels, max_b, _make_label_cell)
	_rebuild_grid(current_bits, max_b, _make_bit_cell.bind("green"))
	_rebuild_grid(mask, max_b, _make_bit_cell.bind("white"))
	_rebuild_grid(output, max_b, _make_bit_cell.bind("cyan"))

	for grid in [labels, current_bits, mask, output]:
		grid.columns = max_b

	user_mask = 0
	mask.visible = not realtime_mode
	separator.visible = not realtime_mode
	output.visible = not realtime_mode
	button_row.visible = not realtime_mode

	_refresh_all()

## Remove all children from a grid and repopulate using the factory callable.
func _rebuild_grid(grid: GridContainer, count: int, factory: Callable) -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in range(count):
		grid.add_child(factory.call(i))

# =============================================================================
# Cell Factories
# =============================================================================

## Create a key hint label cell (A/S/D/F) with smaller font.
## Each key is colored with its bit's color from GameManager.BIT_COLORS
## so the player can match keys to tilemap objects at a glance.
func _make_label_cell(display_index: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = LABEL_CELL_MIN_SIZE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("normal_font_size", LABEL_FONT_SIZE)
	var max_b: int = GameManager.max_bits
	if display_index < _toggle_keys.size() and display_index < max_b:
		var key_name = _toggle_key_primary_name[display_index]
		var bit_idx := _display_to_bit(display_index)
		var bit_color := GameManager.get_bit_color(bit_idx).to_html(false)
		label.text = "[color=#%s]%s[/color]" % [bit_color, key_name]
	else:
		label.text = "[color=#88888888]-[/color]"
	return label

## Create a bit value cell (0/1) with the given BBCode color for any grid row.
func _make_bit_cell(_display_index: int, color: String = "white") -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = BIT_CELL_MIN_SIZE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("normal_font_size", BIT_FONT_SIZE)
	label.text = "[color=%s]0[/color]" % color
	return label

# =============================================================================
# Refresh
# =============================================================================

## Update all grid rows to reflect current state.
func _refresh_all() -> void:
	_refresh_current_bits()
	_refresh_row(mask, user_mask, "white")
	_refresh_row(output, _compute_preview(), "cyan")

## Update the current bitmask row. Every cell always uses its bit's color
## regardless of value, so the player can always see which bit is which.
func _refresh_current_bits() -> void:
	for i in range(current_bits.get_child_count()):
		var bit_val := _get_display_bit(GameManager.bitmask, i)
		var bit_idx := _display_to_bit(i)
		var hex := GameManager.get_bit_color(bit_idx).to_html(false)
		current_bits.get_child(i).text = "[color=#%s]%d[/color]" % [hex, bit_val]

## Update every cell in a grid row to show the bits of mask_value.
## Active bits (1) are colored with their bit's color from GameManager.
## Inactive bits (0) use the row's default_color (e.g. "white", "cyan").
func _refresh_row(grid: GridContainer, mask_value: int, default_color: String) -> void:
	for i in range(grid.get_child_count()):
		var bit_val := _get_display_bit(mask_value, i)
		if bit_val == 1:
			var bit_idx := _display_to_bit(i)
			var hex := GameManager.get_bit_color(bit_idx).to_html(false)
			grid.get_child(i).text = "[color=#%s]1[/color]" % hex
		else:
			grid.get_child(i).text = "[color=%s]0[/color]" % default_color

# =============================================================================
# Operations & Submit
# =============================================================================

## Compute the result of applying the selected boolean operation (OR or AND)
## between the current GameManager bitmask and the user's local mask.
func _compute_preview() -> int:
	return (GameManager.bitmask | user_mask) if use_or else (GameManager.bitmask & user_mask)

## Apply the preview result to GameManager and reset local mask state.
func _submit() -> void:
	GameManager.bitmask = _compute_preview()
	user_mask = 0
	_refresh_row(mask, user_mask, "white")
	_refresh_row(output, _compute_preview(), "cyan")

# =============================================================================
# Button Styling
# =============================================================================

## Update both OR/AND buttons to reflect the current use_or state.
func _sync_operation_buttons() -> void:
	or_button.button_pressed = use_or
	and_button.button_pressed = not use_or
	_style_toggle_button(or_button, use_or)
	_style_toggle_button(and_button, not use_or)

## Apply active (green) or inactive (gray) styling to an operation button,
## overriding all Godot button states so defaults don't interfere.
func _style_toggle_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	style.set_border_width_all(1)
	if active:
		style.bg_color = Color(0.0, 0.3, 0.15, 0.8)
		style.border_color = Color(0.0, 0.8, 0.4, 0.6)
	else:
		style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
		style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	for state in ["normal", "pressed", "hover", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, style)
	var font_color := Color(0.0, 1.0, 0.4) if active else Color(0.4, 0.4, 0.4)
	var hover_color := Color(0.0, 1.0, 0.5) if active else Color(0.5, 0.5, 0.5)
	for color_name in ["font_color", "font_pressed_color"]:
		btn.add_theme_color_override(color_name, font_color)
	for color_name in ["font_hover_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(color_name, hover_color)

## Select OR operation and refresh the preview.
func _on_or_pressed() -> void:
	use_or = true
	_sync_operation_buttons()
	_refresh_row(output, _compute_preview(), "cyan")

## Select AND operation and refresh the preview.
func _on_and_pressed() -> void:
	use_or = false
	_sync_operation_buttons()
	_refresh_row(output, _compute_preview(), "cyan")

# =============================================================================
# Signal Callbacks
# =============================================================================

## Respond to GameManager bitmask changes by refreshing the top row and preview.
func _on_bitmask_updated(_new_mask: int) -> void:
	_refresh_current_bits()
	_refresh_row(output, _compute_preview(), "cyan")

## Rebuild the entire UI when max_bits changes (e.g. new level loaded).
func _on_max_bits_changed(_new_max: int) -> void:
	_rebuild_ui()
