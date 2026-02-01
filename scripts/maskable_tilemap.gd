class_name gameplay_tilemap
extends TileMapLayer
## Attach to any TileMapLayer that has gameplay-relevant tiles.
##
## This script does three things:
## 1. Auto-registers with GameManager so player can check tile data (is_deadly, jump_force)
## 2. Implements on_bit_changed() so it can be toggled via MaskableBehavior
## 3. Creates a colored overlay (based on bit index) so the player can always
##    see which bit controls this tilemap
##
## When toggled off via bitmask:
##   - Disables collision so the player passes through
##   - Dims tiles via self_modulate
##   - If a greyscale atlas source is configured, also swaps tiles to greyscale art
##
## Usage:
##   - Attach this script to a TileMapLayer
##   - Add a MaskableBehavior child if you want it toggleable via bitmask
##   - (Optional) In your TileSet, add a greyscale atlas as a second source
##     and set source_greyscale in the Inspector to match its source ID

## The source ID in the TileSet for normal (colored) tiles.
@export var source_normal: int = 0

## The source ID in the TileSet for greyscale (disabled) tiles.
## Set to -1 to disable greyscale swapping (modulate dimming is used instead).
@export var source_greyscale: int = -1

## Whether the greyscale source exists in the TileSet.
## Checked once at startup so we don't query every bit change.
var _has_greyscale: bool = false

## Which bit controls this tilemap. Discovered from MaskableBehavior child at startup.
var _bit_index: int = -1

## Container node holding per-tile ColorRect overlays, tinted with this bit's
## color so the player can always see which bit controls this tilemap.
## Always visible — the only difference between enabled/disabled is self_modulate
## dimming and greyscale tile swapping.
var _color_overlay: Node2D = null

func _ready() -> void:
	GameManager.register_tilemap(self)

	# Check if the greyscale atlas source actually exists in the TileSet.
	if source_greyscale >= 0 and tile_set and tile_set.has_source(source_greyscale):
		_has_greyscale = true

	# Find our bit_index from MaskableBehavior child so we can look up our color.
	for child in get_children():
		if child is MaskableBehavior:
			_bit_index = child.bit_index
			break

	# _create_color_overlay()
	_setup_outlines()

func _exit_tree() -> void:
	GameManager.unregister_tilemap(self)

## Create a per-tile ColorRect overlay for each used cell, grouped under a
## single Node2D container. One rect per tile avoids covering empty space
## between scattered tiles.
func _create_color_overlay() -> void:
	var used_cells := get_used_cells()
	if used_cells.is_empty():
		return

	var tile_size := Vector2(tile_set.tile_size)
	var half := tile_size / 2.0
	var bit_color := GameManager.get_bit_color(_bit_index)
	var overlay_color := Color(bit_color.r, bit_color.g, bit_color.b, 0.25)

	_color_overlay = Node2D.new()
	add_child(_color_overlay)

	for cell in used_cells:
		var center := map_to_local(cell)
		var rect := ColorRect.new()
		rect.position = center - half
		rect.size = tile_size
		rect.color = overlay_color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_color_overlay.add_child(rect)

## Called by MaskableBehavior when this tilemap's bit changes.
func on_bit_changed(bit_enabled: bool) -> void:
	collision_enabled = bit_enabled

	if bit_enabled:
		self_modulate = Color.WHITE
		if _has_greyscale:
			_swap_tiles(source_normal)
	else:
		self_modulate = Color(0.5, 0.5, 0.5, 0.4)
		if _has_greyscale:
			_swap_tiles(source_greyscale)

## Swap all tiles to a different atlas source, preserving position and alternatives.
func _swap_tiles(target_source: int) -> void:
	for coords in get_used_cells():
		var atlas_coords = get_cell_atlas_coords(coords)
		var alt = get_cell_alternative_tile(coords)
		set_cell(coords, target_source, atlas_coords, alt)



# tile map outlines

enum Side {
	NONE  = 0,

	TOP   = 1,
	RIGHT = 2,
	BOT   = 4,
	LEFT  = 8,
}

const SHADER_MAX_INTEGERS = 2048

var outline_shader := preload("res://Shaders/tilemap.tres")

func _setup_outlines() -> void:
	material = outline_shader.duplicate()

	var bit_color := GameManager.get_bit_color(_bit_index)
	material.set_shader_parameter("outline_color", bit_color)

	var cells := get_used_cells()
	var sides := PackedInt32Array()
	
	var bounds := get_used_rect()
	var total_size := Vector2i((bounds.position.x)+bounds.size.x, (bounds.position.y)+bounds.size.y)
	sides.resize(SHADER_MAX_INTEGERS)
	
	material.set_shader_parameter("tilemap_width", total_size.x)
	material.set_shader_parameter("tile_size", tile_set.tile_size.x)
	
	#print(name, " ---------------------")
	for i in cells.size():
		var cell := cells[i]
		
		var side_index:int = (cell.x + (cell.y * total_size.x));
		
		# shader max size is 2048 - pass if bigger
		if side_index >= SHADER_MAX_INTEGERS:
			continue
			
		var side_data = sides[side_index];
		#print(cell, " -> ", side_index)

		var t:Vector2i = get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_TOP_SIDE)
		var r:Vector2i = get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_RIGHT_SIDE)
		var l:Vector2i = get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_LEFT_SIDE)
		var b:Vector2i = get_neighbor_cell(cell, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE)

		var t_id := get_cell_source_id(t)
		var r_id := get_cell_source_id(r)
		var l_id := get_cell_source_id(l)
		var b_id := get_cell_source_id(b)

		if t_id == -1:
			sides[side_index] |= Side.TOP

		if r_id == -1:
			sides[side_index] |= Side.RIGHT

		if l_id == -1:
			sides[side_index] |= Side.LEFT

		if b_id == -1:
			sides[side_index] |= Side.BOT

	material.set_shader_parameter("sides", sides)
