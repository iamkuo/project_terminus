extends Node2D

signal all_towers_destroyed(winning_team: int)
signal tower_destroyed_notify(tower)

var towers: Array = []
var player_towers: int = 0
var enemy_towers: int = 0

func _ready():
	call_deferred("_register_all_towers")

func _register_all_towers():
	towers.clear()
	player_towers = 0
	enemy_towers = 0

	for node in get_tree().get_nodes_in_group("towers"):
		if node.has_method("take_damage"):
			towers.append(node)
			if node.team == 0:
				player_towers += 1
			else:
				enemy_towers += 1
			node.tower_destroyed.connect(_on_tower_destroyed.bind())

func _on_tower_destroyed(tower):
	towers.erase(tower)

	if tower.team == 0:
		player_towers -= 1
	else:
		enemy_towers -= 1

	tower_destroyed_notify.emit(tower)
	_check_game_end()

func _check_game_end():
	if player_towers <= 0:
		_end_game(1)
	elif enemy_towers <= 0:
		_end_game(0)

func _end_game(winning_team: int):
	all_towers_destroyed.emit(winning_team)
	# BattleManager listens for all_towers_destroyed and handles the ending flow
	# through BattleTransitionManager — no direct call needed here
