extends Control
## Fuse Box UI - Visual bitmask interface using a fuse slot metaphor.
##
## Each bit is represented as a physical fuse slot. Fuses can be "inserted"
## (bit ON) or "pulled" (bit OFF). Two operation modes:
##   INSERT (OR):  bitmask | user_mask -- selected fuses get turned ON
##   KEEP   (AND): bitmask & user_mask -- selected fuses stay, rest turn OFF
##
## Same GameManager API as HUD UI, different visual representation.
## Uses the same input actions: toggle_bit_0-3, toggle_bit_operand, confirm_bits.

# --- Node References ---

@onready var panel: PanelContainer = $Panel
@onready var mode_label: RichTextLabel = $Panel/VBox/ModeRow/ModeLabel
@onready var space_key: PanelContainer = $Panel/VBox/ModeRow/SpaceKey
@onready var space_hint: RichTextLabel = $Panel/VBox/ModeRow/SpaceKey/SpaceHint
@onready var fuse_row: HBoxContainer = $Panel/VBox/FuseRow

# --- Configuration ---

@export var realtime_mode: bool = false

## Scales the entire panel. Pivot is set to top-right so scaling grows leftward
## instead of pushing the panel off-screen.
@export_range(0.5, 3.0, 0.1) var ui_scale: float = 1.0:
	set(value):
		ui_scale = value
		if is_node_ready():
			_apply_ui_scale()

# --- State ---

var user_mask: int = 0
## true = INSERT (OR), false = KEEP (AND)
var use_or: bool = true

# --- Constants ---

var _toggle_keys: Array[String] = ["toggle_bit_0", "toggle_bit_1", "toggle_bit_2", "toggle_bit_3"]
var _toggle_key_primary_name: Array[String]

const CHICAGO_FONT = preload("res://UI/Fonts/ChicagoFLF.ttf")
const KEY_FONT_SIZE: int = 14
const MODE_FONT_SIZE: int = 16
const HINT_FONT_SIZE: int = 12

# Slot dimensions
const SLOT_WIDTH: int = 36
const SLOT_HEIGHT: int = 48
const FUSE_MARGIN: int = 4
const BORDER_WIDTH: int = 2
const SELECTION_BAR_HEIGHT: int = 4

# Mode colors -- INSERT is green, KEEP is red
const INSERT_COLOR := Color(0, 1, 0.4)
const KEEP_COLOR := Color(1, 0.3, 0.2)

# Fuse body colors for various states
const FUSE_DARK := Color(0.08, 0.08, 0.1)         # empty slot (bit OFF, stays OFF)
const FUSE_WARNING := Color(0.6, 0.15, 0.1)        # red tint base for "about to be pulled"
const SELECTION_DIM := Color(0.2, 0.2, 0.22)       # unselected bar
const SLOT_BORDER_DEFAULT := Color(0.15, 0.15, 0.18)
const SLOT_BG := Color(0.06, 0.06, 0.08)

# --- Helpers ---

## Convert a display index (0=leftmost) to a bit index.
## Leftmost display position = highest bit (MSB-first ordering).
func _display_to_bit(display_index: int) -> int:
	return (GameManager.max_bits - 1) - display_index

## Extract a single bit value (0 or 1) from a bitmask at the given display position.
func _get_display_bit(mask_value: int, display_index: int) -> int:
	return (mask_value >> _display_to_bit(display_index)) & 1

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	# Build key name lookup from the input map actions.
	# "toggle_bit_0" -> looks up the first bound key -> "A"
	for i in _toggle_keys.size():
		var action_name = _toggle_keys[i]
		var actions := InputMap.action_get_events(action_name)
		var key_name = actions[0] as InputEventKey
		var keycode := OS.get_keycode_string(key_name.physical_keycode)
		_toggle_key_primary_name.push_back(keycode)

	GameManager.bitmask_updated.connect(_on_bitmask_updated)
	GameManager.max_bits_changed.connect(_on_max_bits_changed)
	_rebuild_ui()
	_apply_ui_scale()

## Apply ui_scale to the Panel node. Pivot is set to top-right corner so
## scaling anchors the panel in place instead of sliding it offscreen.
func _apply_ui_scale() -> void:
	await get_tree().process_frame
	panel.pivot_offset = Vector2(panel.size.x, 0)
	panel.scale = Vector2(ui_scale, ui_scale)

# =============================================================================
# Input
# =============================================================================

## Handle A/S/D/F (toggle bits), Tab (switch INSERT/KEEP), Space (submit).
## In realtime mode, bit keys write directly to GameManager.
## In submit mode, bit keys compose a local mask and Space applies it.
func _process(_delta: float) -> void:
	var max_b: int = GameManager.max_bits

	for i in range(mini(_toggle_keys.size(), max_b)):
		if Input.is_action_just_pressed(_toggle_keys[i]):
			if realtime_mode:
				GameManager.toggle_bit(_display_to_bit(i))
			else:
				user_mask ^= (1 << _display_to_bit(i))
				_refresh_all()
			return

	if realtime_mode:
		return

	if Input.is_action_just_pressed("toggle_bit_operand"):
		use_or = not use_or
		_refresh_all()
		return

	if Input.is_action_just_pressed("confirm_bits"):
		_submit()
		return

# =============================================================================
# UI Build
# =============================================================================

## Tear down and regenerate all fuse slots for the current max_bits count.
## Resets local state and hides submit-mode elements when in realtime mode.
func _rebuild_ui() -> void:
	# Clear existing fuse slots
	for child in fuse_row.get_children():
		child.queue_free()

	# Build a FuseSlot VBoxContainer for each bit position
	for i in range(GameManager.max_bits):
		fuse_row.add_child(_make_fuse_slot(i))

	user_mask = 0

	# Hide mode row in realtime mode (no INSERT/KEEP needed)
	mode_label.visible = not realtime_mode
	space_key.visible = not realtime_mode

	_refresh_all()

## Build one fuse slot: a VBoxContainer with KeyLabel, SlotFrame>FuseBody,
## and SelectionBar. The SlotFrame is a PanelContainer styled as a dark
## recessed rectangle; the FuseBody inside it is the colored fuse.
func _make_fuse_slot(display_index: int) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.name = "FuseSlot_%d" % display_index
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 2)

	# --- Key Label (e.g. "A", "S", "D", "F") ---
	var key_label := RichTextLabel.new()
	key_label.name = "KeyLabel"
	key_label.bbcode_enabled = true
	key_label.fit_content = true
	key_label.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
	key_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("normal_font", CHICAGO_FONT)
	key_label.add_theme_font_size_override("normal_font_size", KEY_FONT_SIZE)

	# Color the key label with its bit's assigned color so the player can
	# visually match keys to the tilemap objects they control.
	if display_index < _toggle_keys.size() and display_index < GameManager.max_bits:
		var key_name = _toggle_key_primary_name[display_index]
		var bit_idx := _display_to_bit(display_index)
		var hex := GameManager.get_bit_color(bit_idx).to_html(false)
		key_label.text = "[center][color=#%s]%s[/color][/center]" % [hex, key_name]
	else:
		key_label.text = "[center][color=#88888888]-[/color][/center]"
	slot.add_child(key_label)

	# --- Slot Frame (dark recessed container for the fuse) ---
	var slot_frame := PanelContainer.new()
	slot_frame.name = "SlotFrame"
	slot_frame.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	var frame_style := StyleBoxFlat.new()
	frame_style.set_corner_radius_all(0)
	frame_style.bg_color = SLOT_BG
	frame_style.set_border_width_all(BORDER_WIDTH)
	frame_style.border_color = SLOT_BORDER_DEFAULT
	frame_style.set_content_margin_all(FUSE_MARGIN)
	slot_frame.add_theme_stylebox_override("panel", frame_style)
	slot.add_child(slot_frame)

	# --- Fuse Body (the colored rectangle representing the fuse) ---
	var fuse_body := ColorRect.new()
	fuse_body.name = "FuseBody"
	fuse_body.color = FUSE_DARK
	fuse_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuse_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_frame.add_child(fuse_body)

	# --- Selection Bar (thin indicator below the slot, shows user_mask) ---
	var selection_bar := ColorRect.new()
	selection_bar.name = "SelectionBar"
	selection_bar.custom_minimum_size = Vector2(SLOT_WIDTH, SELECTION_BAR_HEIGHT)
	selection_bar.color = SELECTION_DIM
	selection_bar.visible = not realtime_mode
	slot.add_child(selection_bar)

	return slot

# =============================================================================
# Refresh
# =============================================================================

## Update all visual elements to reflect current state.
func _refresh_all() -> void:
	_refresh_mode_label()
	_refresh_fuse_slots()

## Update the mode label text and color. INSERT = green, KEEP = red.
func _refresh_mode_label() -> void:
	if realtime_mode:
		return
	var mode_color: Color = INSERT_COLOR if use_or else KEEP_COLOR
	var mode_text: String = "INSERT" if use_or else "KEEP"
	var hex := mode_color.to_html(false)
	mode_label.text = "[center][color=#%s]%s[/color][/center]" % [hex, mode_text]
	# Tint the SPACE key cap text to match the current mode color so the
	# player sees it as the action that will execute INSERT or KEEP.
	var hint_hex := mode_color.darkened(0.3).to_html(false)
	space_hint.text = "[center][color=#%s]SPACE[/color][/center]" % hint_hex

## Update each fuse slot's visual state based on current bitmask, preview,
## and user_mask selection.
##
## Fuse body color logic:
##   ON  -> stays ON  : full bright bit color
##   ON  -> goes OFF  : dimmed + red tint (warning: about to be pulled)
##   OFF -> goes ON   : bit color at half brightness (ghost preview)
##   OFF -> stays OFF : dark/empty
##
## Selection bar color reflects the *outcome* for that fuse after submit:
##   green = fuse will be ON after submit
##   red   = fuse is currently ON but will be turned OFF
##   dim   = unselected / no change
## Slot frame border: subtle glow in bit color if ON, dark default if OFF.
func _refresh_fuse_slots() -> void:
	var preview := _compute_preview()

	for i in range(fuse_row.get_child_count()):
		var slot := fuse_row.get_child(i) as VBoxContainer
		if slot == null:
			continue

		var bit_idx := _display_to_bit(i)
		var bit_color := GameManager.get_bit_color(bit_idx)
		var current_on := _get_display_bit(GameManager.bitmask, i) == 1
		var preview_on := _get_display_bit(preview, i) == 1
		var selected := _get_display_bit(user_mask, i) == 1

		# --- Fuse Body color ---
		var fuse_body := slot.get_node("SlotFrame/FuseBody") as ColorRect

		if current_on and preview_on:
			# Stays ON -- full bright bit color
			fuse_body.color = bit_color
		elif current_on and not preview_on:
			# About to be pulled -- lerp toward red warning tint
			fuse_body.color = bit_color.lerp(FUSE_WARNING, 0.6)
		elif not current_on and preview_on:
			# About to be inserted -- ghost preview at half brightness
			fuse_body.color = bit_color.darkened(0.5)
		else:
			# Stays OFF -- dark/empty
			fuse_body.color = FUSE_DARK

		# --- Slot Frame border glow ---
		# Duplicate the style so each slot gets its own copy (otherwise they'd
		# share the same StyleBoxFlat and all change together).
		var slot_frame := slot.get_node("SlotFrame") as PanelContainer
		var frame_style := slot_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if current_on:
			frame_style.border_color = bit_color.darkened(0.4)
		else:
			frame_style.border_color = SLOT_BORDER_DEFAULT
		slot_frame.add_theme_stylebox_override("panel", frame_style)

		# --- Selection Bar ---
		# Color based on outcome: green if fuse will be ON, red if it's about
		# to be turned OFF, dim gray otherwise.
		var selection_bar := slot.get_node("SelectionBar") as ColorRect
		selection_bar.visible = not realtime_mode
		if not realtime_mode:
			if current_on and preview_on and selected:
				# ON and will stay ON — green (protected in KEEP, or already on in INSERT)
				selection_bar.color = INSERT_COLOR
			elif current_on and not preview_on:
				# Currently ON, about to be pulled — red warning
				selection_bar.color = KEEP_COLOR
			elif not current_on and preview_on and selected:
				# OFF but will turn ON — green (INSERT mode)
				selection_bar.color = INSERT_COLOR
			elif not current_on and selected:
				# OFF and selected but won't turn on (KEEP mode) — red to
				# acknowledge the input and signal "this can't help you"
				selection_bar.color = KEEP_COLOR
			else:
				selection_bar.color = SELECTION_DIM

# =============================================================================
# Operations & Submit
# =============================================================================

## Compute the result of applying the current operation (OR or AND) between
## the GameManager bitmask and the user's local mask.
## In realtime mode, just returns the current bitmask (no user_mask involved).
func _compute_preview() -> int:
	if realtime_mode:
		return GameManager.bitmask
	return (GameManager.bitmask | user_mask) if use_or else (GameManager.bitmask & user_mask)

## Apply the preview result to GameManager and reset the local mask.
func _submit() -> void:
	GameManager.bitmask = _compute_preview()
	user_mask = 0
	_refresh_all()

# =============================================================================
# Signal Callbacks
# =============================================================================

## Respond to GameManager bitmask changes by refreshing all fuse visuals.
func _on_bitmask_updated(_new_mask: int) -> void:
	_refresh_fuse_slots()

## Rebuild the entire UI when max_bits changes (e.g. new level loaded).
func _on_max_bits_changed(_new_max: int) -> void:
	_rebuild_ui()
