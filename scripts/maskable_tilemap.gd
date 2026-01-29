class_name gameplay_tilemap
extends TileMapLayer
## Attach to any TileMapLayer that has gameplay-relevant tiles.
##
## This script does two things:
## 1. Auto-registers with GameManager so player can check tile data (is_deadly, jump_force)
## 2. Implements on_bit_changed() so it can be toggled via MaskableBehavior
##
## Usage:
##   - Just attach this script to a TileMapLayer
##   - Add a MaskableBehavior child if you want it toggleable via bitmask

func _ready() -> void:
	GameManager.register_tilemap(self)

func _exit_tree() -> void:
	GameManager.unregister_tilemap(self)

## Called by MaskableBehavior when this tilemap's bit changes
func on_bit_changed(bit_enabled: bool) -> void:
	enabled = bit_enabled
