extends CharacterBody2D

@export var speed: float = 200.0
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var input_vector = Vector2.ZERO
	
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()
	
	if input_vector != Vector2.ZERO:
		anim_sprite.play("walk")
		if input_vector.x < 0:
			anim_sprite.flip_h = true
		elif input_vector.x > 0:
			anim_sprite.flip_h = false
	else:
		anim_sprite.play("idle")
