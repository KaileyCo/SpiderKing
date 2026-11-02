extends CharacterBody2D


const SPEED = 300.0           # Max speed of the player
const JUMP_VELOCITY = -400.0  # Power of the jump (negative y means up in godot)

# How quickly players reaches top speed or stops
# Time to reach top speed or stop: (Speed / Accel or Deccel)
const ACCELERATION = 2400.0
const DECELERATION = 2500.0

const DASH_SPEED = 700.0   # How fast the dash is
const DASH_DURATION = 0.15 # How long the dash lasts

const WALL_SLIDE_SPEED = 100.0         # How quickly (or slowly) you slide down a wall
const WALL_SLIDE_DECELERATION = 2000.0 # How quick fall speed slows down

const WALL_JUMP_HORIZONTAL_SPEED = 350.0 # Horizontal speed of wall jump
const WALL_JUMP_VERTICAL_SPEED = -400.0 # Vertical speed of wall jump
const WALL_JUMP_CONTROL_DELAY = 0.012 # How long until player can move after wall jump

const AFTERIMAGE_SCENE: PackedScene = preload(
	"res://effects/afterimage.tscn"
)

const AFTERIMAGE_INTERVAL = 0.04

const GRAPPLE_MAX_DISTANCE = 2000.0
const GRAPPLE_HOOK_SPEED = 3200.0
const GRAPPLE_PULL_SPEED = 1000.0

const GRAPPLE_SURFACE_OFFSET = 0
const GRAPPLE_ARRIVAL_DISTANCE = 0

const SWING_INPUT_ACCELERATION = 800.0
const SWING_MAX_SPEED = 1200.0

enum GrappleState {IDLE,FIRING,PULLING,SWINGING}

# Initialized player values
var facing_direction: float = 1.0 # Direction player faces (-1: left and 1: right)
var dash_direction: float = 1.0  # Direction player dashes
var dash_time_remaining: float = 0.0 # Timer for a dash
var air_dash_available: bool = true # Tracks if player still has an air dash available

var wall_jump_control_time: float = 0.0 # For wall jump delay

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var afterimage_time_remaining: float = 0.0

@onready var grapple_origin: Marker2D = $GrappleOrigin
@onready var grapple_ray: RayCast2D = $GrappleOrigin/GrappleRay
@onready var grapple_rope: Line2D = $GrappleRope

var grapple_state: int = GrappleState.IDLE
var grapple_hit_point: Vector2
var grapple_destination: Vector2
var hook_position: Vector2
var grapple_should_pull: bool = true
var grapple_rope_length: float = 0.0


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
	
	# When grapple input (alt) is pressed
	if Input.is_action_just_pressed("grapple"):
		if grapple_state == GrappleState.IDLE: # If not currently grappling
			try_start_grapple(true) # True tells it to bring player towards destination
		else: # If currently grappling
			stop_grapple(true) # True keeps momentum from grapple

	# When grapple2 input (ctrl) is pressed
	if Input.is_action_just_pressed("grapple2"):
		if grapple_state == GrappleState.IDLE:
			try_start_grapple(false) # False means Spider-Man web swinging
		else:
			stop_grapple(true)
	
	# Move the hook while it is being fired.
	if grapple_state == GrappleState.FIRING:
		handle_grapple_shot(delta)

	# Attempt to begin a dash.
	if Input.is_action_just_pressed("shift"):
		try_start_dash(direction)

	# All currently possible movement states
	if grapple_state == GrappleState.PULLING:
		handle_grapple_pull() # If being pulled by grapple
	elif grapple_state == GrappleState.SWINGING:
		handle_grapple_swing(direction, delta) # If swing via grapple
		update_swing_rotation(delta)
	elif dash_time_remaining > 0:
		handle_dash(delta) # If dashing
	else:
		handle_normal_movement(direction, delta) # Normal movement

	move_and_slide() # Godot movement, handles collisions
	
	# Bunch of code to keep grapple length the same when swinging
	if grapple_state == GrappleState.SWINGING:
		# Create a vector from the start of the grapple to its collision point
		var rope_vector := (
			grapple_origin.global_position
			- grapple_hit_point
		)

		# Get the length of the vector
		var current_rope_length := rope_vector.length()

		# Make sure grapple doesn't become longer while swinging
		if current_rope_length > grapple_rope_length:
			# Get the difference from current distance to allowed distance
			var extra_distance := (
				current_rope_length - grapple_rope_length
			)

			# Get rid of the extra distance
			global_position -= (
				rope_vector.normalized()
				* extra_distance
			)
	
	update_grapple_rope()

func create_afterimage() -> void:
	var afterimage := AFTERIMAGE_SCENE.instantiate() as Sprite2D

	afterimage.texture = animated_sprite.sprite_frames.get_frame_texture(
		animated_sprite.animation,
		animated_sprite.frame
	)

	afterimage.centered = animated_sprite.centered
	afterimage.offset = animated_sprite.offset
	afterimage.flip_h = animated_sprite.flip_h
	afterimage.flip_v = animated_sprite.flip_v

	afterimage.modulate = Color(0.4, 0.7, 1.0, 0.55)
	afterimage.z_index = animated_sprite.z_index - 1

	get_tree().current_scene.add_child(afterimage)
	afterimage.global_transform = animated_sprite.global_transform

func handle_dash(delta: float) -> void:
	dash_time_remaining -= delta # Dash time counts down
	afterimage_time_remaining -= delta

	velocity.x = dash_direction * DASH_SPEED # Dash speed
	velocity.y = 0.0 # Not falling or rising
	if afterimage_time_remaining <= 0:
		create_afterimage()
		afterimage_time_remaining = AFTERIMAGE_INTERVAL

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
	# Creates that "bounce" off the wall
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
	afterimage_time_remaining = 0.0

	if not is_on_floor():
		air_dash_available = false

func try_start_grapple(should_pull: bool) -> void:
	# Gets direction based on movement inputs
	var aim_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	
	var grapple_origin_offset := (
	grapple_origin.global_position - global_position
	)

	# If no direction is held, grapple horizontally toward
	# the direction the player last faced.
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2(facing_direction, 0.0)

	grapple_ray.target_position = (
		aim_direction.normalized() * GRAPPLE_MAX_DISTANCE
	)

	grapple_ray.force_raycast_update()

	if not grapple_ray.is_colliding():
		return
	
	grapple_should_pull = should_pull

	grapple_hit_point = grapple_ray.get_collision_point()

	var surface_normal := grapple_ray.get_collision_normal()

	grapple_destination = (
	grapple_hit_point
	+ surface_normal * GRAPPLE_SURFACE_OFFSET
	- grapple_origin_offset
	)

	hook_position = grapple_origin.global_position
	grapple_state = GrappleState.FIRING
	grapple_rope.show()

func handle_grapple_shot(delta: float) -> void:
	hook_position = hook_position.move_toward(
		grapple_hit_point,
		GRAPPLE_HOOK_SPEED * delta
	)

	if hook_position.distance_to(grapple_hit_point) <= 1.0:
		hook_position = grapple_hit_point
		dash_time_remaining = 0.0

		if grapple_should_pull:
			grapple_state = GrappleState.PULLING
		else:
			grapple_state = GrappleState.SWINGING

	grapple_rope_length = grapple_origin.global_position.distance_to(
		grapple_hit_point
	)

func handle_grapple_pull() -> void:
	var distance_to_destination := global_position.distance_to(
		grapple_destination
	)

	if distance_to_destination <= GRAPPLE_ARRIVAL_DISTANCE:
		stop_grapple()
		return

	var pull_direction := global_position.direction_to(
		grapple_destination
	)

	velocity = pull_direction * GRAPPLE_PULL_SPEED

func stop_grapple(preserve_velocity: bool = false) -> void:
	grapple_state = GrappleState.IDLE
	grapple_rope.hide()
	
	# Character sprite no longer rotated
	animated_sprite.rotation = 0.0

	if not preserve_velocity:
		velocity = Vector2.ZERO

func update_grapple_rope() -> void:
	if grapple_state == GrappleState.IDLE:
		return

	grapple_rope.points = PackedVector2Array([
		grapple_rope.to_local(grapple_origin.global_position),
		grapple_rope.to_local(hook_position)
	])
	
	
func handle_grapple_swing(direction: float, delta: float) -> void:
	# Gravity creates the pendulum motion.
	velocity += get_gravity() * delta

	# Allow some horizontal input to help pump the swing.
	velocity.x += (
		direction
		* SWING_INPUT_ACCELERATION
		* delta
	)

	var anchor_to_player := (
		grapple_origin.global_position
		- grapple_hit_point
	)

	if anchor_to_player.length() > 0:
		var radial_direction := anchor_to_player.normalized()

		# Find how much velocity points along the rope.
		var radial_velocity := velocity.dot(radial_direction)

		# Remove movement toward or away from the hook,
		# leaving movement around the hook.
		velocity -= radial_direction * radial_velocity

	velocity = velocity.limit_length(SWING_MAX_SPEED)

func update_swing_rotation(delta: float) -> void:
	# Get direction from player to grapple
	var direction_to_hook := (
		grapple_hit_point
		- grapple_origin.global_position
	).normalized()

	# angle() treats right as zero degrees.
	# Adding PI / 2 keeps an upright sprite upright when the hook is above it.
	var target_rotation := direction_to_hook.angle() + PI / 2.0

	# Rotate toward the rope's angle.
	animated_sprite.rotation = lerp_angle(
		animated_sprite.rotation,
		target_rotation,
		12.0 * delta
	)
