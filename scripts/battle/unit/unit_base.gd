class_name UnitBase
extends CharacterBody2D

enum Team {PLAYER = 0, OPPONENT = 1}

const unit_selection_circle = preload("res://scripts/battle/ui/unit_selection_circle.gd")

const ARRIVAL_DISTANCE: float = 5.0
const MOVING_SPEED_THRESHOLD: float = 5.0
const CLICK_COLLISION_RADIUS: float = 20.0
const PLAYER_GOAL_X: float = 1100.0
const OPPONENT_GOAL_X: float = 200.0
const ATTACK_ANIMATION_DELAY: float = 0.3
const DEATH_ANIMATION_DELAY: float = 0.5

signal health_changed(current: int, max: int)
signal died(unit: UnitBase)
signal damage_dealt(amount: int, target: Node)
signal enemy_killed(target: Node)

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

@onready var a_sprite: AnimatedSprite2D = $AnimatedSpriteattack
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_circle: Node2D = $SelectionCircle
@onready var properties_ui: Control = $PropertiesUI

func _ready():
	if stats:
		if team == Team.OPPONENT:
			current_health = int(stats.health * ConfigManager.enemy_multiplyer)
		else:
			current_health = int(stats.health * ConfigManager.allies_multiplyer)
	else:
		current_health = 100
		stats = UnitStats.new()
	# Initialize with correct idle animation for this unit type
	_play_action("idle")
	# Emit health changed signal to initialize UI display
	health_changed.emit(current_health, stats.health)

func _physics_process(delta: float):
	if lifecycle_state != LifecycleState.ALIVE:
		return
	
	# Check if game has ended - stop movement for non-player units
	if BattleManager.is_game_ended():
		# Only allow player movement when game has ended
		if team != Team.PLAYER:
			velocity = Vector2.ZERO
			_play_action("idle")
			return
	
	var was_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	attack_cooldown = max(0.0, attack_cooldown - delta)
	
	# Find attack target and determine movement
	current_target = _find_target()
	var move_target = _get_movement_target(current_target)
	
	# Handle combat if we have a valid target
	if current_target and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		
		if dist <= stats.attack_distance:
			# Target in range - attack and face target
			sprite.flip_h = (current_target.global_position.x < global_position.x)
			if attack_cooldown <= 0.0:
				_perform_attack(current_target)
		
	# Move toward movement target (different from attack target in FOLLOW_PLAYER mode)
	_move_towards(move_target)

	# Animation sync
	var now_moving = velocity.length() > MOVING_SPEED_THRESHOLD
	if was_moving != now_moving:
		_play_action("walk" if now_moving else "idle")


func _play_action(action: String):
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name = (stats.unit_id if stats else "") + "_" + action
	
	# Try to play specific animation for this unit type
	if anim_name in sprite.sprite_frames.get_animation_names():
		sprite.play(anim_name)
		sprite.visible = true
		return
	
	# Fallback: try to find any animation with this action for any unit type
	var available_anims = sprite.sprite_frames.get_animation_names()
	for anim in available_anims:
		if anim.ends_with("_" + action):
			sprite.play(anim)
			sprite.visible = true
			return
	
	# Final fallback: try generic action name (only if it exists and is not fallback)
	if action in available_anims and action != "fallback":
		sprite.play(action)
		sprite.visible = true
		return
	
	# If we reach here, animation system failed - keep fallback animation as visual indicator
	# Don't show sprite for fallback animation

func _perform_attack(target: Node) -> void:
	if is_attacking or not target or not is_instance_valid(target):
		return
	
	is_attacking = true
	attack_cooldown = 1.0 / stats.attack_speed
	var anim_name = stats.unit_id
	
	# Try to play specific animation for this unit type
	a_sprite.visible = true
	a_sprite.play(anim_name)
	
	_play_action("attack")

	match stats.attack_type:
		UnitStats.AttackType.DIRECT:
			if target.has_method("take_damage"):
				var final_damage = stats.attack_damage
				if team == Team.PLAYER:
					final_damage = int(final_damage * ConfigManager.allies_multiplyer)
				else:
					final_damage = int(final_damage * ConfigManager.enemy_multiplyer)
				
				target.take_damage(final_damage, self)
				damage_dealt.emit(final_damage, target)
				if team == Team.PLAYER:
					BattleManager.on_unit_damage_dealt(self, final_damage, target)
		UnitStats.AttackType.PROJECTILE:
			ProjectileManager.spawn_projectile(self , target)

	await get_tree().create_timer(ATTACK_ANIMATION_DELAY).timeout

	is_attacking = false


func take_damage(amount: int, attacker: Node) -> void:
	var actual_damage = max(0, amount - int(stats.defense * _get_multiplier()))
	current_health -= actual_damage
	
	# Only emit health_changed if unit is still alive (not dying or dead)
	if lifecycle_state == LifecycleState.ALIVE:
		health_changed.emit(max(0, current_health), stats.health)
	
	if current_health <= 0 and lifecycle_state == LifecycleState.ALIVE:
		# Notify the attacker so it can emit enemy_killed and update BattleManager
		if attacker and attacker.has_method("_on_killed_target"):
			attacker._on_killed_target(self)
		lifecycle_state = LifecycleState.DYING
		_play_action("die")
		await get_tree().create_timer(DEATH_ANIMATION_DELAY).timeout
		lifecycle_state = LifecycleState.DEAD
		died.emit(self )
		queue_free()


## Called by the victim unit when it is killed by this unit.
## Allows the attacker to emit enemy_killed and update BattleManager.
func _on_killed_target(target: Node) -> void:
	enemy_killed.emit(target)
	BattleManager.on_unit_enemy_killed(self, target)

func set_behavior_pattern(pattern: BehaviorPattern):
	behavior_pattern = pattern

func _get_multiplier() -> float:
	return ConfigManager.allies_multiplyer if team == Team.PLAYER else ConfigManager.enemy_multiplyer

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

# Returns where the unit should move based on behavior pattern
func _get_movement_target(attack_target: Node = null) -> Vector2:
	if behavior_pattern:
		return behavior_pattern.get_movement_target(self , attack_target)
	
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
		properties_ui.show_for_unit(self )


func _find_target() -> Node:
	if behavior_pattern:
		return behavior_pattern.get_target_for(self )
	
	# Fallback: find any enemy in view distance, then tower
	var enemy = _find_nearest_node("units", _is_valid_enemy, stats.view_distance)
	if enemy:
		return enemy
	return _find_nearest_node("towers", _is_valid_tower, 1e9)

## Generic method to find the nearest node in a group that passes the filter function
func _find_nearest_node(group: String, filter: Callable, max_distance: float) -> Node:
	var nodes = get_tree().get_nodes_in_group(group)
	var nearest: Node = null
	var nearest_dist: float = max_distance
	
	for node in nodes:
		if filter.call(node):
			var dist = global_position.distance_to(node.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = node
	
	return nearest

## Filter function for valid enemy units
func _is_valid_enemy(unit: Node) -> bool:
	return unit != self and unit.team != team

## Filter function for valid enemy towers
func _is_valid_tower(tower: Node) -> bool:
	return tower.team != team and not (tower is TowerBase and tower.is_destroyed)

func _get_lane_goal_pos() -> Vector2:
	var fallback_x = PLAYER_GOAL_X if team == Team.PLAYER else OPPONENT_GOAL_X
	
	# Find the nearest enemy tower that is not destroyed
	var nearest_tower = _find_nearest_node("towers", _is_valid_tower, 1e9) as Node2D

	# Return a position just before the tower for attack range, or fallback position if none found
	if nearest_tower:
		var direction = (nearest_tower.global_position - global_position).normalized()
		return nearest_tower.global_position - direction * 50.0
	else:
		return Vector2(fallback_x, global_position.y)
