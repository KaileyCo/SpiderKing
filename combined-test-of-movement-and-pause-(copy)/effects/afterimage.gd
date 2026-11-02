extends Sprite2D


@export var lifetime: float = 0.2

var time_remaining: float
var starting_color: Color


func _ready() -> void:
	time_remaining = lifetime
	starting_color = modulate


func _process(delta: float) -> void:
	time_remaining -= delta

	var fade_percentage := time_remaining / lifetime
	modulate.a = starting_color.a * fade_percentage

	if time_remaining <= 0:
		queue_free()
