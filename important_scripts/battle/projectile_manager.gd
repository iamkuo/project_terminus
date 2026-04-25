extends Node

const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")

## Called by UnitBase to fire a projectile.
## Only needs the shooter and target — all data is read from the unit's own stats.
func spawn_projectile(shooter: Node, target: Node) -> void:
	if not shooter or not target:
		return
		
	var proj = PROJECTILE_SCENE.instantiate()
	proj.global_position = shooter.global_position
	proj.target = target
	proj.damage = shooter.stats.attack_damage
	proj.team = shooter.team
	proj.unit_id = shooter.stats.unit_id  # drives animation selection
	
	if proj.has_method("set_shooter"):
		proj.set_shooter(shooter)
	
	# Add to the scene tree at the same level as the shooter
	shooter.get_parent().add_child(proj)
