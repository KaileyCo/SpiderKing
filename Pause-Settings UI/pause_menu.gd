extends Control

@onready var main = $".." 

func _on_resume_pressed():
	main.PauseMenu()
	

func _on_settings_pressed():
	hide()
	get_parent().get_node("SettingsMenu").show()


func _on_exit_pressed():
	main.PauseMenu()
