class_name hazard_tilemap
extends TileMapLayer

## TileMapLayer that auto-generates Area2D hazard zones for tiles with is_deadly custom data.
## Also creates a colored overlay (based on bit index) so the player can always
## see which bit controls this tilemap.
##
## When toggled off via bitmask:
##   - Disables hazard Area2Ds so they stop killing the player
##   - Dims tiles via self_modulate
##   - If a greyscale atlas source is configured, also swaps tiles to greyscale art

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
var _color_overlay: Node2D = null

func _ready() -> void:
	# Disable tile physics — hazard detection uses generated Area2Ds instead
	collision_enabled = false
	GameManager.register_tilemap(self)
	_generate_hazard_areas()

	# Check if the greyscale atlas source actually exists in the TileSet.
	if source_greyscale >= 0 and tile_set and tile_set.has_source(source_greyscale):
		_has_greyscale = true

	# Find our bit_index from MaskableBehavior child so we can look up our color.
	for child in get_children():
		if child is MaskableBehavior:
			_bit_index = child.bit_index
			break

	_create_color_overlay()

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

func on_bit_changed(bit_enabled: bool) -> void:
	# Toggle hazard Area2Ds so disabled hazards don't kill the player
	for child in get_children():
		if child is Area2D:
			child.monitoring = bit_enabled

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

func _generate_hazard_areas() -> void:
	var used_cells := get_used_cells()
	for cell_coords in used_cells:
		var data := get_cell_tile_data(cell_coords)
		if data == null:
			continue

		var is_deadly = data.get_custom_data("is_deadly")
		if not is_deadly:
			continue

		_create_hazard_area(cell_coords)

func _create_hazard_area(cell_coords: Vector2i) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1  # Detect player (layer 1)
	area.monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var tile_size := tile_set.tile_size
	rect.size = Vector2(tile_size)
	shape.shape = rect

	# Position at the center of the tile in local coords
	var local_pos := map_to_local(cell_coords)
	area.position = local_pos

	area.add_child(shape)
	add_child(area)

	area.body_entered.connect(_on_hazard_body_entered)

func _on_hazard_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
