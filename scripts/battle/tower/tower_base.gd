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
@onready var _health_label: Label = $BarRoot/HealthLabel if has_node("BarRoot/HealthLabel") else null
@onready var _restriction_area: Area2D = $RestrictionArea if has_node("RestrictionArea") else null

func _ready():
	if team == Team.PLAYER:
		max_health = int(max_health * SkillManager.tower_health_mult)
	
	current_health = max_health
	add_to_group("towers")
	
	# Set up restriction area for enemy towers
	if team == Team.OPPONENT and _restriction_area:
		_restriction_area.add_to_group("tower_restrictions")
		# Store reference to this tower so restriction knows if tower is destroyed
		_restriction_area.tower = self
		# Make it detect player units (player units are on layer 1)
		# Override the scene file settings with proper collision setup
		_restriction_area.collision_layer = 4  # Restriction layer
		_restriction_area.collision_mask = 1   # Detect player layer
		
		# Make restriction area visible in editor for debugging
		if Engine.is_editor_hint():
			_restriction_area.visible = true
		else:
			_restriction_area.visible = false
	
	# Connect health changed signal for both health bar and label
	health_changed.connect(_on_health_bar_changed)
	
	# Initialize health display
	call_deferred("_on_health_bar_changed", current_health, max_health)

func _on_health_bar_changed(cur: int, max_hp: int) -> void:
	# Update health bar
	if _health_bar:
		if max_hp <= 0:
			_health_bar.value = 0.0
		else:
			_health_bar.value = 100.0 * float(cur) / float(max_hp)
	
	# Update health label
	if _health_label:
		_health_label.text = str(cur) + "/" + str(max_hp)

func take_damage(amount: int, _target: Node) -> void:
	if is_destroyed: return

	var actual_damage = max(0, amount - defense)
	current_health -= actual_damage
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_destroy()

func _destroy():
	"""
	Destroy the tower and clean up all associated resources.
	
	CRITICAL: Remove from 'towers' group IMMEDIATELY to prevent race conditions
	where AI spawning checks for alive towers during the same frame before
	the node is fully freed by queue_free().
	
	Execution order:
	1. Set is_destroyed flag (immediate effect for checks)
	2. Remove from "towers" group (prevents group queries from finding this tower)
	3. Clean up restriction area
	4. Emit signal for TowerManager notification
	5. Play destruction effect
	6. Queue node for deletion (deferred)
	"""
	is_destroyed = true
	
	# Remove from towers group immediately to prevent late spawns
	# This ensures that get_tree().get_nodes_in_group("towers") queries
	# will NOT include this tower, even before queue_free() takes effect
	remove_from_group("towers")
	
	# Remove restriction area if it exists
	if _restriction_area and is_instance_valid(_restriction_area):
		_restriction_area.queue_free()
	
	tower_destroyed.emit(self)
	_play_destruction_effect()
	
	# Queue for deletion - this happens next frame
	# But tower won't be found by group queries due to remove_from_group() above
	queue_free()

func _play_destruction_effect():
	pass

func get_team() -> int:
	return team

func get_lane() -> int:
	return lane
