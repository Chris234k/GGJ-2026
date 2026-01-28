extends Control
@onready var current_bits: GridContainer = $CurrentBits
@onready var mask: GridContainer = $Mask
@onready var or_button: Button = $OR
@onready var and_button: Button = $AND

var maskBit3 = false
var maskBit2 = false
var maskBit1 = false
var maskBit0 = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_key_pressed(Key.KEY_R):
		for child in current_bits.get_children():
			child.text = str(randi()%2)
			
	if Input.is_key_pressed(Key.KEY_A):
		maskBit3 = !maskBit3
		mask.get_child(0).text = str(int(maskBit3))
		
	if Input.is_key_pressed(Key.KEY_S):
		maskBit2 = !maskBit2
		mask.get_child(1).text = str(int(maskBit2))
		
	if Input.is_key_pressed(Key.KEY_D):
		maskBit1 = !maskBit1
		mask.get_child(2).text = str(int(maskBit1))
		
	if Input.is_key_pressed(Key.KEY_F):
		maskBit0 = !maskBit0
		mask.get_child(3).text = str(int(maskBit0))
		
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	
	
	pass
