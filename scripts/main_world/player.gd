extends CharacterBody2D


@export var speed: float = 200.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: Vector2 = Vector2.DOWN  # Track last movement direction

func _physics_process(_delta: float) -> void:
	var input_vector = Vector2.ZERO
	
	input_vector.x = Input.get_axis("ui_left","ui_right")
	input_vector.y = Input.get_axis("ui_up","ui_down")
	input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()
	
	 # --- 動畫控制 ---
	if input_vector != Vector2.ZERO:
		# Update last direction when moving
		last_direction = input_vector
		
		# Prioritize horizontal direction when both X and Y are present (diagonal movement)
		if input_vector.x != 0:
			if input_vector.x > 0:
				anim_sprite.flip_h = false   # 朝右
				anim_sprite.play("walk_right")
			else:
				anim_sprite.flip_h = true   # 朝左
				anim_sprite.play("walk_right")
		else:
			# Pure vertical movement
			if input_vector.y > 0:
				anim_sprite.play("walk_down")
			else:
				anim_sprite.play("walk_up")
	else:
		# Use last direction to determine idle animation
		if abs(last_direction.x) > abs(last_direction.y):
			# Last movement was horizontal - use idle_down but flip based on direction
			anim_sprite.flip_h = last_direction.x < 0  # Face left if moving left
			anim_sprite.play("idle_down")  # Only idle_down animation available
		else:
			# Last movement was vertical
			if last_direction.y > 0:
				anim_sprite.flip_h = false
				anim_sprite.play("idle_down")
			else:
				anim_sprite.flip_h = false
				anim_sprite.play("idle_down")  # Use idle_down for up too since idle_up doesn't exist
		
