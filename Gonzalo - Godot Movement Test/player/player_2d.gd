extends CharacterBody2D


const SPEED = 300.0
const SPRINT_MULTIPLIER = 2.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	# Add gravity while the character is in the air.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jumping.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# New variable for speed so it can be altered
	var current_speed: float = SPEED

	# Increase speed while Shift is held.
	if Input.is_action_pressed("shift"):
		current_speed *= SPRINT_MULTIPLIER

	var direction := Input.get_axis("move_left", "move_right")

	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
