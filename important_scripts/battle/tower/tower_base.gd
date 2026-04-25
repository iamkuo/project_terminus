class_name TowerBase
extends Node2D

enum Team { PLAYER = 0, OPPONENT = 1 }
signal tower_destroyed(tower: TowerBase)
signal health_changed(current: int, max: int)

@export var max_health: int = 1000
@export var defense: int = 10
@export var team: Team = Team.PLAYER
@export var lane: int = 1
@export var tower_name: String = "Tower"

var current_health: int = 0
var is_destroyed: bool = false

@onready var _health_bar: ProgressBar = $BarRoot/ProgressBar

func _ready():
	current_health = max_health
	add_to_group("towers")
	
	if not is_instance_valid(_health_bar):
		return
	health_changed.connect(_on_health_bar_changed)
	call_deferred("_on_health_bar_changed", current_health, max_health)

func _on_health_bar_changed(cur: int, max_hp: int) -> void:
	if not _health_bar:
		return
	if max_hp <= 0:
		_health_bar.value = 0.0
	else:
		_health_bar.value = 100.0 * float(cur) / float(max_hp)

func take_damage(amount: int) -> void:
	if is_destroyed: return

	var actual_damage = max(0, amount - defense)
	current_health -= actual_damage
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_destroy()

func _destroy():
	is_destroyed = true
	tower_destroyed.emit(self)

	_play_destruction_effect()
	queue_free()

func _play_destruction_effect():
	pass

func get_team() -> int:
	return team

func get_lane() -> int:
	return lane
