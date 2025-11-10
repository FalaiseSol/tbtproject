extends CharacterBody2D

const SPEED = 500.0

# Forest rectangle bounds (middle right of floor)
const FOREST_RECT_LEFT = 200.0
const FOREST_RECT_RIGHT = 300.0
const FOREST_RECT_TOP = -50.0
const FOREST_RECT_BOTTOM = 50.0

@onready var interaction_bubble = $InteractionBubble
@onready var bubble_container = $InteractionBubble/Control/BubbleContainer

func _ready():
	# Make sure bubble is hidden initially
	if interaction_bubble:
		interaction_bubble.visible = false

func _physics_process(_delta):
	# Get input direction
	var input_dir = Vector2()
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# Normalize direction for consistent speed
	var direction = input_dir.normalized()
	
	# Apply movement
	if direction:
		velocity = direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
	
	# Handle collisions
	move_and_slide()
	
	# Check if character is over the forest rectangle
	_check_interaction_area()

func _check_interaction_area():
	var char_pos = global_position
	var is_over_forest = (char_pos.x >= FOREST_RECT_LEFT and char_pos.x <= FOREST_RECT_RIGHT and 
	                      char_pos.y >= FOREST_RECT_TOP and char_pos.y <= FOREST_RECT_BOTTOM)
	
	if interaction_bubble:
		interaction_bubble.visible = is_over_forest
		if is_over_forest and bubble_container:
			# Convert world position to screen position using camera
			var camera = get_viewport().get_camera_2d()
			if camera:
				# Get camera transform
				var camera_pos = camera.global_position
				var camera_zoom = camera.zoom
				var viewport_size = get_viewport().get_visible_rect().size
				
				# Convert world position to screen position
				var screen_x = (char_pos.x - camera_pos.x) * camera_zoom.x + viewport_size.x / 2
				var screen_y = (char_pos.y - camera_pos.y) * camera_zoom.y + viewport_size.y / 2
				
				# Position bubble above character (offset by 80 pixels in world space, converted to screen)
				var bubble_offset_y = 80.0 * camera_zoom.y
				bubble_container.position = Vector2(screen_x - bubble_container.size.x / 2, screen_y - bubble_offset_y)
