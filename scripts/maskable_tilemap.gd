class_name gameplay_tilemap
extends TileMapLayer
## Attach to any TileMapLayer that has gameplay-relevant tiles.
##
## This script does two things:
## 1. Auto-registers with GameManager so player can check tile data (is_deadly, jump_force)
## 2. Implements on_bit_changed() so it can be toggled via MaskableBehavior
##
## When toggled off, swaps all tiles from the normal atlas source to a greyscale
## atlas source so the player can still see where disabled tiles are. Collision
## is also disabled so the player passes through.
##
## Usage:
##   - Attach this script to a TileMapLayer
##   - Add a MaskableBehavior child if you want it toggleable via bitmask
##   - In your TileSet, add the greyscale atlas as a second source
##   - Set source_normal and source_greyscale in the Inspector to match
##     the source IDs shown in the TileSet editor

## The source ID in the TileSet for normal (colored) tiles.
@export var source_normal: int = 0

## The source ID in the TileSet for greyscale (disabled) tiles.
## Set to -1 to disable greyscale swapping (falls back to hiding the layer).
@export var source_greyscale: int = -1

## Whether the greyscale source exists in the TileSet.
## Checked once at startup so we don't query every bit change.
var _has_greyscale: bool = false

func _ready() -> void:
	GameManager.register_tilemap(self)
	# Check if the greyscale atlas source actually exists in the TileSet.
	# If not, we fall back to the old show/hide behavior until it's added.
	if source_greyscale >= 0 and tile_set and tile_set.has_source(source_greyscale):
		_has_greyscale = true

func _exit_tree() -> void:
	GameManager.unregister_tilemap(self)

## Called by MaskableBehavior when this tilemap's bit changes.
## If a greyscale atlas source is configured, swaps tiles between normal and
## greyscale. Otherwise falls back to simply hiding the layer.
func on_bit_changed(bit_enabled: bool) -> void:
	collision_enabled = bit_enabled

	if _has_greyscale:
		# Swap tiles between normal and greyscale atlas sources.
		# The layer stays visible so the player can see disabled tiles.
		var target_source = source_normal if bit_enabled else source_greyscale
		for coords in get_used_cells():
			var atlas_coords = get_cell_atlas_coords(coords)
			var alt = get_cell_alternative_tile(coords)
			set_cell(coords, target_source, atlas_coords, alt)
	else:
		# No greyscale source yet — just hide/show the whole layer
		visible = bit_enabled
