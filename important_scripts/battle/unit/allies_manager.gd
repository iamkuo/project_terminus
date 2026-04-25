extends Node2D

enum Team { PLAYER = 0, OPPONENT = 1 }

signal unit_spawned(unit: Node, spawn_info: Dictionary)
signal spawn_failed(reason: String)

const SPAWN_LANES: int = 3
const UNIT_SCENES_PATH: String = "res://scenes/unit.tscn"

# Default behavior pattern for newly spawned units
const DEFAULT_BEHAVIOR = preload("res://important_scripts/unit/behavior_pattern.gd")

var local_team: Team = Team.PLAYER

func spawn_unit(stats: UnitStats, pos: Vector2, lane: int) -> void:
	if not stats or lane < 0 or lane >= SPAWN_LANES:
		spawn_failed.emit("Invalid spawn parameters")
		return
		
	var packed_scene = load(UNIT_SCENES_PATH)
	if not packed_scene:
		spawn_failed.emit("Scene not found")
		return
		
	var unit: Node = packed_scene.instantiate()
	unit.global_position = pos
	unit.team = local_team
	unit.lane = lane
	unit.stats = stats.duplicate()
	
	# Set default behavior pattern (ATTACK_NEAREST_ENEMY)
	var default_pattern = DEFAULT_BEHAVIOR.new()
	default_pattern.pattern_type = DEFAULT_BEHAVIOR.PatternType.ATTACK_NEAREST_ENEMY
	unit.set_behavior_pattern(default_pattern)
	
	add_child(unit)
	
	unit.add_to_group("units")
	unit.add_to_group("ally_units")
	
	var sprite = unit.get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.flip_h = false
		
	unit_spawned.emit(unit, {"unit": unit, "position": pos, "team": local_team, "lane": lane, "cost": stats.cost})
