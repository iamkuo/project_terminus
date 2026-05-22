extends Area2D

enum Team {PLAYER = 0, OPPONENT = 1}

@export var speed: float = 700.0
@export var max_travel_distance: float = 3200.0

var damage: int = 20
var target: Node = null
var team: Team = Team.PLAYER
var unit_id: String = ""

var _traveled: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _shooter: WeakRef = null
var dir: Vector2 = Vector2.ZERO
var _draw_delay: float = 0.0  # For archer bow draw animation
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func set_shooter(unit: Node) -> void:
	if unit:
		_shooter = weakref(unit)

func _ready() -> void:
	# Initialize animation
	if anim_sprite and anim_sprite.sprite_frames:
		if unit_id != "" and anim_sprite.sprite_frames.has_animation(unit_id):
			anim_sprite.play(unit_id)
		elif anim_sprite.sprite_frames.has_animation("default"):
			anim_sprite.play("default")
	
	# Capture initial direction and decouple from target
	if is_instance_valid(target):
		dir = (target.global_position - global_position).normalized()
		_velocity = dir * speed
		look_at(global_position + dir)
	
	target = null # Decouple immediately
	
	# Set draw delay for archer bow animation
	if unit_id == "ally_archer" and team == Team.PLAYER:
		_draw_delay = 1.6
	
	# Connect collision signal
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	# Handle archer draw delay
	if _draw_delay > 0.0:
		_draw_delay -= delta
		return
	
	if _velocity == Vector2.ZERO:
		queue_free()
		return
	
	var step = _velocity * delta
	global_position += step
	
	_traveled += step.length()
	if _traveled >= max_travel_distance:
		queue_free()
func _on_hit(hit_obj: Node) -> void:
	# Avoid hitting the shooter
	var shooter = _shooter.get_ref() if _shooter else null
	if hit_obj == shooter:
		return

	# Find the actual entity (Unit or Tower) - might be a collision shape
	var target_entity = hit_obj
	if not target_entity.has_method("take_damage"):
		target_entity = hit_obj.get_parent()
	
	if not target_entity or not target_entity.has_method("take_damage"):
		return
	
	# Friendly fire check
	if "team" in target_entity and target_entity.team == team:
		return
	
	# Apply damage and destroy projectile
	target_entity.take_damage(damage, shooter)
	queue_free()
