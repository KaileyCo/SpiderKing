extends Node

@onready var score = $"../CanvasLayer/Control/VBoxContainer/Score/Label"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score.text = str(GameState.score)


func add_currency():
	GameState.score += 1
	score.text = str(GameState.score)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
