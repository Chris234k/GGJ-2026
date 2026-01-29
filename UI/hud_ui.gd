extends Control
@onready var current_bits: GridContainer = $CurrentBits
@onready var mask: GridContainer = $Mask
@onready var output: GridContainer = $Output
@onready var or_button: Button = $OR
@onready var and_button: Button = $AND

var Or = 0

var maskBit3 = false
var maskBit2 = false
var maskBit1 = false
var maskBit0 = false

var outputBit3 = false
var outputBit2 = false
var outputBit1 = false
var outputBit0 = false


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
		
	if Input.is_key_pressed(Key.KEY_SPACE):
		for child in current_bits.get_children():
			child.text = output.get_child(child.get_index()).text
		
func _update_Output(Toggle: bool) -> void:
	
	if Toggle == false:
			for child in mask.get_children():
				print(child.text)
				if child.text == "1":
					output.get_child(child.get_index()).text = str(0)
				else:
					output.get_child(child.get_index()).text = current_bits.get_child(child.get_index()).text
	else:
			for child in mask.get_children():
				print(child.text)
				if child.text == "1":
					output.get_child(child.get_index()).text = str(1)
					print("ones")
				else:
					output.get_child(child.get_index()).text = current_bits.get_child(child.get_index()).text
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT):
		
		if or_button.is_hovered() == true:
			and_button.button_pressed = false
			Or = 1
			#print("and ", and_button.button_pressed)
			
		if and_button.is_hovered() == true:
			or_button.button_pressed = false
			Or = 0
			
	_update_Output(Or)
	pass
