class_name Wall
extends StaticBody2D
## A simple wall obstacle that can be toggled on/off via bitmask.
## Requires MaskableBehavior child node for bit registration.
##
## When enabled: exists in scene tree.
## When disabled: removed from scene tree (fully deactivated).

## Called by MaskableBehavior when this wall's bit changes
func on_bit_changed(enabled: bool) -> void:
	print("DEBUG Wall: on_bit_changed(", enabled, ")")
	if enabled:
		$MaskableBehavior.reactivate_parent()
	else:
		$MaskableBehavior.deactivate_parent()
