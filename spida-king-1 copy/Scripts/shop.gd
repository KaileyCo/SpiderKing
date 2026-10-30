extends CanvasLayer


func _on_close_pressed():
	get_node("Anim").play("TransOut")
	await get_node("Anim").animation_finished
	get_tree().paused = false
