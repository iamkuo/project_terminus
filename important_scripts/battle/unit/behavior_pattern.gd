class_name BehaviorPattern
extends Resource

enum PatternType {
	STAY,
	FOLLOW_PLAYER,
	ATTACK_NEAREST_ENEMY,
	ATTACK_NEAREST_TOWER
}

@export var pattern_type: PatternType = PatternType.ATTACK_NEAREST_ENEMY
@export var name: String = "Attack Nearest Enemy"
@export var description: String = "Automatically targets and attacks the nearest enemy unit"

# Returns the target to attack (if any) based on pattern type
func get_target_for(unit: Node2D) -> Node:
	match pattern_type:
		PatternType.STAY:
			# Only attack enemies within attack distance
			return _find_nearest_enemy(unit, unit.stats.attack_distance)
		
		PatternType.FOLLOW_PLAYER, PatternType.ATTACK_NEAREST_ENEMY:
			# Attack enemies within view distance, then towers
			var enemy = _find_nearest_enemy(unit, unit.stats.view_distance)
			return enemy if enemy else _find_nearest_tower(unit)
		
		PatternType.ATTACK_NEAREST_TOWER:
			return _find_nearest_tower(unit)
	
	return null

# Returns the position the unit should move toward based on pattern type
func get_movement_target(unit: Node2D, attack_target: Node = null) -> Vector2:
	match pattern_type:
		PatternType.STAY:
			return unit.global_position  # Don't move
		
		PatternType.FOLLOW_PLAYER:
			return _get_player_position(unit) if _get_player_position(unit) else _get_lane_goal_pos(unit)
		
		PatternType.ATTACK_NEAREST_ENEMY, PatternType.ATTACK_NEAREST_TOWER:
			# If we have an attack target, move toward it (or stop if ranged and in range)
			if attack_target:
				if _should_ranged_stop(unit, attack_target):
					return unit.global_position
				return attack_target.global_position
			
			# No attack target - march toward lane goal
			return _get_lane_goal_pos(unit)
	
	return _get_lane_goal_pos(unit)

# Helper: Check if ranged unit should stop to attack
func _should_ranged_stop(unit: Node2D, target: Node) -> bool:
	if unit.stats.attack_type != UnitStats.AttackType.PROJECTILE:
		return false
	var dist = unit.global_position.distance_to(target.global_position)
	return dist <= unit.stats.attack_distance

# Helper: Get player position if available
func _get_player_position(unit: Node2D) -> Vector2:
	var players = unit.get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0].global_position
	return Vector2.ZERO

static func get_pattern_name(type: PatternType) -> String:
	match type:
		PatternType.STAY:
			return "Stay"
		PatternType.FOLLOW_PLAYER:
			return "Follow Player"
		PatternType.ATTACK_NEAREST_ENEMY:
			return "Attack Nearest Enemy"
		PatternType.ATTACK_NEAREST_TOWER:
			return "Attack Nearest Tower"
	return "Unknown"

# Private helper functions
func _find_nearest_enemy(unit: Node2D, max_range: float) -> Node:
	var all_units = unit.get_tree().get_nodes_in_group("units")
	var nearest: Node = null
	var nearest_dist: float = max_range
	
	for u in all_units:
		if u == unit or u.team == unit.team:
			continue
		var dist = unit.global_position.distance_to(u.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = u
	
	return nearest

func _find_nearest_tower(unit: Node2D) -> Node:
	var towers = unit.get_tree().get_nodes_in_group("towers")
	var nearest: Node = null
	var nearest_dist: float = 1e9
	
	for tower in towers:
		if tower.team == unit.team:
			continue
		if tower is TowerBase and tower.is_destroyed:
			continue
		var dist = unit.global_position.distance_to(tower.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = tower
	
	return nearest

func _get_lane_goal_pos(unit: Node2D) -> Vector2:
	const PLAYER_GOAL_X: float = 1400.0
	const OPPONENT_GOAL_X: float = 200.0
	
	if unit is UnitBase:
		var x = PLAYER_GOAL_X if unit.team == UnitBase.Team.PLAYER else OPPONENT_GOAL_X
		return Vector2(x, unit.global_position.y)
	
	return Vector2(PLAYER_GOAL_X, unit.global_position.y)
