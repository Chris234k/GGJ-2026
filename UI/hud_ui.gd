extends Control
## HUD UI - Three-row bitmask display with submit workflow.
##
## Layout (submit mode):
##   [OR] [AND]       <- operation selector (Tab to toggle)
##    A  S  D  F      <- key labels (light up green when bit is on)
##    0  0  0  1      <- top row: current GameManager bitmask (green)
##    0  0  0  0      <- middle row: user-toggled mask bits (white)
##   ────────────     <- separator
##    0  0  0  1      <- bottom row: real-time preview of operation result (cyan)
##
## In submit mode, A/S/D/F toggle local user_mask bits, preview updates live,
## and Space writes the preview result to GameManager.
## In realtime mode, A/S/D/F directly toggle GameManager bits (no submit step).

# --- Node References ---
# All UI lives inside Panel > VBox in the scene tree

@onready var labels: GridContainer = $Panel/VBox/Labels
@onready var current_bits: GridContainer = $Panel/VBox/CurrentBits
@onready var mask: GridContainer = $Panel/VBox/Mask
@onready var separator: HSeparator = $Panel/VBox/Separator
@onready var output: GridContainer = $Panel/VBox/Output
@onready var button_row: HBoxContainer = $Panel/VBox/ButtonRow
@onready var or_button: Button = $Panel/VBox/ButtonRow/OR
@onready var and_button: Button = $Panel/VBox/ButtonRow/AND

# --- Configuration ---

## When true, A/S/D/F directly toggle GameManager bits (no submit step).
## When false, uses the three-row preview + Space-to-submit workflow.
@export var realtime_mode: bool = false

# --- Local State (not stored in GameManager) ---

var user_mask: int = 0   ## The middle row bits the player is composing
var use_or: bool = true  ## true = OR operation, false = AND operation

# --- Input Mapping ---
# Keys in MSB-first display order: A controls the leftmost (highest) bit,
# F controls the rightmost (lowest) bit.

var _toggle_keys: Array[int] = [KEY_A, KEY_S, KEY_D, KEY_F]

# --- Display Constants ---

const BIT_FONT_SIZE: int = 22
const LABEL_FONT_SIZE: int = 16
const BIT_CELL_MIN_SIZE: Vector2 = Vector2(28, 0)
const LABEL_CELL_MIN_SIZE: Vector2 = Vector2(28, 0)

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	GameManager.bitmask_updated.connect(_on_bitmask_updated)
	GameManager.max_bits_changed.connect(_on_max_bits_changed)
	# Prevent buttons from capturing keyboard focus (Tab/Space should go to gameplay)
	or_button.focus_mode = Control.FOCUS_NONE
	and_button.focus_mode = Control.FOCUS_NONE
	or_button.pressed.connect(_on_or_pressed)
	and_button.pressed.connect(_on_and_pressed)
	_rebuild_ui()
	_sync_operation_buttons()

# =============================================================================
# Input
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var max_b: int = GameManager.max_bits

	# --- Bit toggle keys (A/S/D/F) ---
	# Convert display index i to bit_index: leftmost key = highest bit
	for i in range(mini(_toggle_keys.size(), max_b)):
		if event.keycode == _toggle_keys[i]:
			var bit_index: int = (max_b - 1) - i
			if realtime_mode:
				# Directly flip the bit on GameManager (immediate effect)
				GameManager.toggle_bit(bit_index)
			else:
				# Flip the bit on local user_mask (preview only, no game effect yet)
				user_mask ^= (1 << bit_index)
				_refresh_middle_row()
				_refresh_preview_row()
			return

	# Everything below is submit-mode only
	if realtime_mode:
		return

	# --- Tab: toggle between AND / OR ---
	if event.keycode == KEY_TAB:
		use_or = not use_or
		_sync_operation_buttons()
		_refresh_preview_row()
		return

	# --- Space: submit preview to GameManager ---
	if event.keycode == KEY_SPACE:
		_submit()
		return

# =============================================================================
# UI Rebuild — tears down and regenerates all grid cells.
# Called on startup and whenever max_bits changes (e.g. new level).
# =============================================================================

func _rebuild_ui() -> void:
	var max_b: int = GameManager.max_bits

	# Regenerate each grid row with the correct number of cells
	_rebuild_grid(labels, max_b, _make_label_cell)
	_rebuild_grid(current_bits, max_b, _make_top_cell)
	_rebuild_grid(mask, max_b, _make_middle_cell)
	_rebuild_grid(output, max_b, _make_preview_cell)

	# GridContainer.columns must match the cell count
	labels.columns = max_b
	current_bits.columns = max_b
	mask.columns = max_b
	output.columns = max_b

	# Reset local state on rebuild
	user_mask = 0

	# In realtime mode, hide the submit-workflow UI (middle row, preview, buttons)
	mask.visible = not realtime_mode
	separator.visible = not realtime_mode
	output.visible = not realtime_mode
	button_row.visible = not realtime_mode

	_refresh_all()

## Clear all children from a grid, then populate it using the factory callable.
func _rebuild_grid(grid: GridContainer, count: int, factory: Callable) -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in range(count):
		grid.add_child(factory.call(i))

# =============================================================================
# Cell Factories — create individual RichTextLabel cells for each grid row.
# display_index is the visual position (0 = leftmost).
# =============================================================================

## Key hint labels (A, S, D, F) — smaller font, dimmed until active.
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
		var key_name: String = OS.get_keycode_string(_toggle_keys[display_index])
		label.text = "[color=#88888888]%s[/color]" % key_name
	else:
		label.text = "[color=#88888888]-[/color]"
	return label

## Top row cell — shows current GameManager bitmask in green.
func _make_top_cell(_display_index: int) -> RichTextLabel:
	var label := _make_bit_cell()
	label.text = "[color=green]0[/color]"
	return label

## Middle row cell — shows user_mask bits in white (submit mode only).
func _make_middle_cell(_display_index: int) -> RichTextLabel:
	var label := _make_bit_cell()
	label.text = "0"
	return label

## Preview row cell — shows computed operation result in cyan.
func _make_preview_cell(_display_index: int) -> RichTextLabel:
	var label := _make_bit_cell()
	label.text = "[color=cyan]0[/color]"
	return label

## Shared base for all bit-value cells (top, middle, preview rows).
func _make_bit_cell() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = BIT_CELL_MIN_SIZE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("normal_font_size", BIT_FONT_SIZE)
	return label

# =============================================================================
# Refresh — update cell text from current state without rebuilding the grid.
# =============================================================================

func _refresh_all() -> void:
	_refresh_top_row()
	_refresh_middle_row()
	_refresh_preview_row()

## Top row: read GameManager.bitmask and render each bit in green.
func _refresh_top_row() -> void:
	var max_b: int = GameManager.max_bits
	var gm_mask: int = GameManager.bitmask
	for i in range(current_bits.get_child_count()):
		var bit_index: int = (max_b - 1) - i
		var bit_val: int = (gm_mask >> bit_index) & 1
		current_bits.get_child(i).text = "[color=green]%d[/color]" % bit_val

## Middle row: render user_mask bits as plain 0/1.
## Also refreshes key labels since they track the same state.
func _refresh_middle_row() -> void:
	var max_b: int = GameManager.max_bits
	for i in range(mask.get_child_count()):
		var bit_index: int = (max_b - 1) - i
		var bit_val: int = (user_mask >> bit_index) & 1
		mask.get_child(i).text = str(bit_val)
	_refresh_key_labels()

## Key labels: light up green when their corresponding bit is on, dim gray when off.
## In submit mode, tracks user_mask. In realtime mode, tracks GameManager.bitmask.
func _refresh_key_labels() -> void:
	var max_b: int = GameManager.max_bits
	for i in range(labels.get_child_count()):
		if i >= _toggle_keys.size() or i >= max_b:
			break
		var bit_index: int = (max_b - 1) - i
		var bit_on: bool
		if realtime_mode:
			bit_on = (GameManager.bitmask >> bit_index) & 1 == 1
		else:
			bit_on = (user_mask >> bit_index) & 1 == 1
		var key_name: String = OS.get_keycode_string(_toggle_keys[i])
		if bit_on:
			labels.get_child(i).text = "[color=green]%s[/color]" % key_name
		else:
			labels.get_child(i).text = "[color=#88888888]%s[/color]" % key_name

## Preview row: render the result of applying the selected operation (AND/OR)
## between GameManager.bitmask (top) and user_mask (middle) in cyan.
func _refresh_preview_row() -> void:
	var max_b: int = GameManager.max_bits
	var preview: int = _compute_preview()
	for i in range(output.get_child_count()):
		var bit_index: int = (max_b - 1) - i
		var bit_val: int = (preview >> bit_index) & 1
		output.get_child(i).text = "[color=cyan]%d[/color]" % bit_val

# =============================================================================
# Boolean Operations
# =============================================================================

## Compute the result of applying the selected operation between the current
## GameManager bitmask and the user's local mask.
func _compute_preview() -> int:
	if use_or:
		return GameManager.bitmask | user_mask
	else:
		return GameManager.bitmask & user_mask

# =============================================================================
# Submit — apply the preview result to GameManager and reset local state.
# This is the only place the HUD writes to GameManager.bitmask.
# =============================================================================

func _submit() -> void:
	var preview: int = _compute_preview()
	GameManager.bitmask = preview  # Triggers bitmask_updated -> all maskable objects react
	user_mask = 0
	_refresh_middle_row()
	_refresh_preview_row()

# =============================================================================
# Operation Button Styling
# =============================================================================

## Sync both button states and visuals to match the current use_or value.
func _sync_operation_buttons() -> void:
	or_button.button_pressed = use_or
	and_button.button_pressed = not use_or
	_style_toggle_button(or_button, use_or)
	_style_toggle_button(and_button, not use_or)

## Apply green highlight to the active operation button, dim gray to the inactive one.
## Overrides all button states (normal, pressed, hover) so Godot defaults don't interfere.
func _style_toggle_button(btn: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	if active:
		style.bg_color = Color(0.0, 0.3, 0.15, 0.8)
		style.border_color = Color(0.0, 0.8, 0.4, 0.6)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4))
		btn.add_theme_color_override("font_pressed_color", Color(0.0, 1.0, 0.4))
		btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 0.5))
		btn.add_theme_color_override("font_hover_pressed_color", Color(0.0, 1.0, 0.5))
	else:
		style.bg_color = Color(0.1, 0.1, 0.15, 0.5)
		style.border_color = Color(0.3, 0.3, 0.3, 0.3)
		style.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		btn.add_theme_color_override("font_pressed_color", Color(0.4, 0.4, 0.4))
		btn.add_theme_color_override("font_hover_color", Color(0.5, 0.5, 0.5))
		btn.add_theme_color_override("font_hover_pressed_color", Color(0.5, 0.5, 0.5))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("hover_pressed", style)

func _on_or_pressed() -> void:
	use_or = true
	_sync_operation_buttons()
	_refresh_preview_row()

func _on_and_pressed() -> void:
	use_or = false
	_sync_operation_buttons()
	_refresh_preview_row()

# =============================================================================
# Signal Callbacks — respond to external GameManager state changes.
# =============================================================================

func _on_bitmask_updated(_new_mask: int) -> void:
	_refresh_top_row()
	_refresh_preview_row()
	if realtime_mode:
		_refresh_key_labels()

## When max_bits changes (e.g. new level loaded), rebuild the entire UI.
func _on_max_bits_changed(_new_max: int) -> void:
	_rebuild_ui()
