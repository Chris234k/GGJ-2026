class_name level_config
extends Node
## Optional level configuration node.
## Use this to set initial bit states when the level loads.
## Tilemap registration is now automatic (handled by gameplay_tilemap.gd).

@export var bit_0 := false
@export var bit_1 := false
@export var bit_2 := false
@export var bit_3 := false

func _ready() -> void:
	GameManager.set_bit(0, bit_0)
	GameManager.set_bit(1, bit_1)
	GameManager.set_bit(2, bit_2)
	GameManager.set_bit(3, bit_3)
