class_name UnitBase
extends CharacterBody2D

enum Team {PLAYER = 0, OPPONENT = 1}

const unit_selection_circle = preload("res://important_scripts/ui/unit_selection_circle.gd")

const ARRIVAL_DISTANCE: float = 5.0
const MOVING_SPEED_THRESHOLD: float = 5.0
const MAX_SEARCH_DISTANCE: float = 1e9
const CLICK_COLLISION_RADIUS: float = 20.0
const PLAYER_GOAL_X: float = 1400.0
const OPPONENT_GOAL_X: float = 200.0
const ATTACK_ANIMATION_DELAY: float = 0.3
const DEATH_ANIMATION_DELAY: float = 0.5

signal health_changed(current: int, max: int)
signal died(unit: UnitBase)
signal dealt_damage(amount: int, target: Node)

enum LifecycleState {ALIVE, DYING, DEAD}

@export var stats: UnitStats

var current_health: int
var lifecycle_state: LifecycleState = LifecycleState.ALIVE
var team: Team = Team.PLAYER
var lane: int = 1
var behavior_pattern: BehaviorPattern = null
var selected: bool = false

var current_target: Node = null
var attack_cooldown: float = 0.0
var is_attacking: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var selection_circle: Node2D = $SelectionCircle if has_node("SelectionCircle") else null
@onready var properties_ui: Control = $PropertiesUI if has_node("PropertiesUI") else null
@onready var _health_bar: ProgressBar = $Control/ProgressBar
func _ready():
	if stats:
		current_health = stats.health
	else:
		current_health = 100
		stats = UnitStats.new()



	current_health = stats.health
	add_to_group("unit")
	emit_signal("health_changed",current_health,current_health)
	
	if not is_instance_valid(_health_bar):
		return
	health_changed.connect(_on_health_bar_changed)
	call_deferred("_on_health_bar_changed", current_health, stats.health)

func _on_health_bar_changed(cur: int, max_hp: int) -> void:
	if not _health_bar:
		return
	if max_hp <= 0:
		_health_bar.value = 0.0
	else:
		_health_bar.value = 100.0 * float(cur) / float(max_hp)


func _physics_process(delta: float):
	if lifecycle_state != LifecycleState.ALIVE:
		return

	var was_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	attack_cooldown = max(0.0, attack_cooldown - delta)
	
	# Find attack target and determine movement
	current_target = _find_target()
	var move_target = _get_movement_target(current_target)
	
	# Handle combat if we have a valid target
	if current_target and is_instance_valid(current_target):
		_handle_combat(current_target, move_target)
	else:
		_move_towards(move_target)

	# Animation sync
	var now_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	if was_moving != now_moving:
		_play_action("walk" if now_moving else "idle")


func _play_action(action: String):
	if not sprite or not sprite.sprite_frames:
		return
	var base_name = stats.unit_id if stats else ""
	var anim_name = base_name + "_" + action
	if anim_name in sprite.sprite_frames.get_animation_names():
		sprite.play(anim_name)
	else:
		if action in sprite.sprite_frames.get_animation_names():
			sprite.play(action)


func _perform_attack(target: Node):
	if is_attacking or not target or not is_instance_valid(target):
		return

	is_attacking = true
	attack_cooldown = 1.0 / stats.attack_speed

	_play_action("attack")

	match stats.attack_type:
		UnitStats.AttackType.DIRECT:
			if target.has_method("take_damage"):
				target.take_damage(stats.attack_damage)
				dealt_damage.emit(stats.attack_damage, target)
		UnitStats.AttackType.PROJECTILE:
			ProjectileManager.spawn_projectile(self, target)

	await get_tree().create_timer(ATTACK_ANIMATION_DELAY).timeout

	is_attacking = false

func take_damage(amount: int) -> void:
	var actual_damage = max(0, amount - stats.defense)
	current_health -= actual_damage
	health_changed.emit(current_health, stats.health)

	if current_health <= 0:
		lifecycle_state = LifecycleState.DYING
		_play_action("die")
		await get_tree().create_timer(DEATH_ANIMATION_DELAY).timeout
		lifecycle_state = LifecycleState.DEAD
		died.emit(self )
		queue_free()


func set_behavior_pattern(pattern: BehaviorPattern):
	behavior_pattern = pattern

func select_unit():
	if team != Team.PLAYER:
		return
	selected = true
	if selection_circle and selection_circle is unit_selection_circle:
		selection_circle.show_for_unit(self )

func deselect_unit():
	selected = false
	if selection_circle and selection_circle is unit_selection_circle:
		selection_circle.hide_circle()

func _handle_combat(target: Node, move_target: Vector2):
	var dist = global_position.distance_to(target.global_position)
	
	if dist <= stats.attack_distance:
		# Target in range - attack and face target
		if sprite:
			sprite.flip_h = (target.global_position.x < global_position.x)
		if attack_cooldown <= 0.0:
			_perform_attack(target)
	
	# Move toward movement target (different from attack target in FOLLOW_PLAYER mode)
	_move_towards(move_target)

# Returns where the unit should move based on behavior pattern
func _get_movement_target(attack_target: Node = null) -> Vector2:
	if behavior_pattern:
		return behavior_pattern.get_movement_target(self, attack_target)
	
	# Fallback: if has attack target, move toward it, else lane goal
	if attack_target:
		return attack_target.global_position
	return _get_lane_goal_pos()

func _move_towards(target_pos: Vector2):
	var dir = target_pos - global_position
	if dir.length() < ARRIVAL_DISTANCE:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * stats.move_speed
		if sprite:
			sprite.flip_h = dir.x < 0
	move_and_slide()


func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if team != Team.PLAYER or lifecycle_state != LifecycleState.ALIVE:
			return
			
		var local_mouse_pos = to_local(get_global_mouse_position())
		# Collision radius check - around 20 pixels
		if local_mouse_pos.length() <= CLICK_COLLISION_RADIUS:
			get_viewport().set_input_as_handled()
			select_unit()
			_show_control_panel()

func _show_control_panel():
	if properties_ui and properties_ui.has_method("show_for_unit"):
		properties_ui.show_for_unit(self)


func _find_target() -> Node:
	if behavior_pattern:
		return behavior_pattern.get_target_for(self)
	
	# Fallback: find any enemy in view distance, then tower
	var enemy = _find_nearest_enemy_fallback()
	if enemy:
		return enemy
	return _find_nearest_tower_fallback()

# Fallback target search when no behavior pattern is set (simple nearest enemy, then tower)
func _find_nearest_enemy_fallback() -> Node:
	var all_units = get_tree().get_nodes_in_group("units")
	var nearest: Node = null
	var nearest_dist: float = stats.view_distance
	
	for u in all_units:
		if u == self or u.team == team:
			continue
		var dist = global_position.distance_to(u.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = u
	
	return nearest

func _find_nearest_tower_fallback() -> Node:
	var towers = get_tree().get_nodes_in_group("towers")
	var nearest: Node = null
	var nearest_dist: float = 1e9
	
	for tower in towers:
		if tower.team == team:
			continue
		if tower is TowerBase and tower.is_destroyed:
			continue
		var dist = global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tower
	
	return nearest

func _get_lane_goal_pos() -> Vector2:
	var x = PLAYER_GOAL_X if team == Team.PLAYER else OPPONENT_GOAL_X
	return Vector2(x, global_position.y)
