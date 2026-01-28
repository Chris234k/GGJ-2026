class_name level_config
extends Node

@export var bit_0 := false
@export var bit_1 := false
@export var bit_2 := false
@export var bit_3 := false


func _ready() -> void:
	GameManager.set_bit(0, bit_0)
	GameManager.set_bit(1, bit_1)
	GameManager.set_bit(2, bit_2)
	GameManager.set_bit(3, bit_3)
