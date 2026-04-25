class_name UnitStats
extends Resource

enum AttackType { DIRECT, PROJECTILE }
enum Team { PLAYER = 0, OPPONENT = 1 }

@export_group("Basic Stats")
@export var health: int = 100
@export var defense: int = 0
@export var cost: int = 3
@export var team: Team = Team.PLAYER

@export_group("Combat Stats")
@export var attack_damage: int = 25
@export var attack_speed: float = 1.0
@export var attack_type: AttackType = AttackType.DIRECT

@export_group("Movement Stats")
@export var move_speed: float = 120.0

@export_group("Range Stats")
@export var view_distance: float = 300.0
@export var attack_distance: float = 200.0

@export_group("Visual")
@export var unit_id: String = ""
@export var display_name: String = ""
@export var button_icon: Texture2D = null


func create_runtime_data() -> Dictionary:
	return {
		"max_health": health,
		"current_health": health,
		"defense": defense,
		"attack_damage": attack_damage,
		"attack_speed": attack_speed,
		"attack_type": attack_type,
		"move_speed": move_speed,
		"view_distance": view_distance,
		"attack_distance": attack_distance,
		"cost": cost,
		"button_icon": button_icon,
		"unit_id": unit_id,
		"display_name": display_name
	}

func duplicate_with_values(p_health: int = -1, p_defense: int = -1, p_cost: int = -1, p_damage: int = -1) -> UnitStats:
	var copy = duplicate()
	if p_health >= 0:
		copy.health = p_health
	if p_defense >= 0:
		copy.defense = p_defense
	if p_cost >= 0:
		copy.cost = p_cost
	if p_damage >= 0:
		copy.attack_damage = p_damage
	return copy
