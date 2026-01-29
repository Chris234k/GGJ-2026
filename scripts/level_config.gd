class_name level_config
extends Node

@export var bit_0 := false
@export var bit_1 := false
@export var bit_2 := false
@export var bit_3 := false

var tilemaps: Array[TileMapLayer]

func _ready() -> void:
	var parent := get_parent()
	tilemaps.append(parent.get_node("tilemap_always"))
	tilemaps.append(parent.get_node("tilemap_0"))
	tilemaps.append(parent.get_node("tilemap_1"))
	tilemaps.append(parent.get_node("tilemap_2"))
	tilemaps.append(parent.get_node("tilemap_3"))

	GameManager.register_tilemaps(tilemaps)

	GameManager.set_bit(0, bit_0)
	GameManager.set_bit(1, bit_1)
	GameManager.set_bit(2, bit_2)
	GameManager.set_bit(3, bit_3)
