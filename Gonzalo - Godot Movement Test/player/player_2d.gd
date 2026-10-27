extends CharacterBody2D


const SPEED = 300.0           # Max speed of the player
const JUMP_VELOCITY = -400.0  # Power of the jump (negative y means up in godot)

# How quickly players reaches top speed or stops
# Time to reach top speed or stop: (Speed / Accel or Deccel)
const ACCELERATION = 2400.0
const DECELERATION = 3000.0

const DASH_SPEED = 700.0   # How fast the dash is
const DASH_DURATION = 0.15 # How long the dash lasts

const WALL_SLIDE_SPEED = 100.0         # How quickly (or slowly) you slide down a wall
const WALL_SLIDE_DECELERATION = 2000.0 # How quick fall speed slows down

const WALL_JUMP_HORIZONTAL_SPEED = 350.0 # Horizontal speed of wall jump
const WALL_JUMP_VERTICAL_SPEED = -400.0 # Vertical speed of wall jump
const WALL_JUMP_CONTROL_DELAY = 0.012 # How long until player can move after wall jump

# Initialized player values
var facing_direction: float = 1.0 # Direction player faces (-1: left and 1: right)
var dash_direction: float = 1.0  # Direction player dashes
var dash_time_remaining: float = 0.0 # Timer for a dash
var air_dash_available: bool = true # Tracks if player still has an air dash available

var wall_jump_control_time: float = 0.0 # For wall jump delay


func _physics_process(delta: float) -> void:
	# Makes left = -1 and right = 1
	var direction := Input.get_axis("move_left", "move_right")

	# Remember the last horizontal direction faced
	if direction != 0: # input clicked
		facing_direction = direction # direction updated

	# You can only dash once in the air, resets on floor
	if is_on_floor():
		air_dash_available = true

	# Count down the wall-jump control delay.
	if wall_jump_control_time > 0:
		wall_jump_control_time -= delta

	# Attempt to begin a dash.
	if Input.is_action_just_pressed("shift"):
		try_start_dash(direction)

	if dash_time_remaining > 0:
		handle_dash(delta) # Dashing
	else:
		handle_normal_movement(direction, delta) # Not dashing

	move_and_slide() # Godot movement, handles collisions


func handle_dash(delta: float) -> void:
	dash_time_remaining -= delta # Dash time counts down

	velocity.x = dash_direction * DASH_SPEED # Dash speed
	velocity.y = 0.0


func handle_normal_movement(direction: float, delta: float) -> void:
	# Apply gravity while in air
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Slow player's fall while touching a wall
	if is_on_wall() and not is_on_floor() and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = move_toward(
			velocity.y,
			WALL_SLIDE_SPEED,
			WALL_SLIDE_DECELERATION * delta
		)

	# Handle normal jumps and wall jumps.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			perform_wall_jump()
			air_dash_available = true

	# Normal horizontal movement briefly disabled after a wall jump.
	if wall_jump_control_time <= 0:
		if direction != 0:
			var target_velocity := direction * SPEED

			velocity.x = move_toward(
				velocity.x,
				target_velocity,
				ACCELERATION * delta
			)
		else:
			velocity.x = move_toward(
				velocity.x,
				0.0,
				DECELERATION * delta
			)


func perform_wall_jump() -> void:
	var wall_normal := get_wall_normal()

	velocity.x = wall_normal.x * WALL_JUMP_HORIZONTAL_SPEED
	velocity.y = WALL_JUMP_VERTICAL_SPEED

	wall_jump_control_time = WALL_JUMP_CONTROL_DELAY


func try_start_dash(direction: float) -> void:
	if not is_on_floor() and not air_dash_available:
		return

	if direction != 0:
		dash_direction = direction
	else:
		dash_direction = facing_direction

	dash_time_remaining = DASH_DURATION

	if not is_on_floor():
		air_dash_available = false
