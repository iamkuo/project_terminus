extends Control

enum Team { PLAYER = 0, OPPONENT = 1 }

@export var win_color: Color = Color.GREEN
@export var lose_color: Color = Color.RED
@export var player_team: Team = Team.PLAYER
@onready var result_label: Label = $BackgroundPanel/VBoxContainer/ResultLabel
@onready var background: Panel = $BackgroundPanel
@onready var kills_label: Label = $BackgroundPanel/VBoxContainer/killslable
@onready var damage_label: Label = $BackgroundPanel/VBoxContainer/damagelable
@onready var time_label: Label = $BackgroundPanel/VBoxContainer/timelabel
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_result(winning_team: int):
	print("[EndingScreen] show_result called with winning_team: ", winning_team)
	visible = true
	print("[EndingScreen] Visible set to true")
	kills_label.text = "Defeats:" + str(BattleManager.enemy_killed)
	damage_label.text = "Damage Dealt:" +str(BattleManager.damage_dealt)
	time_label.text = "Time Spent:" + str("%01d" % BattleManager.minutes) + str("m")+ str("%02d" % BattleManager.seconds) + str("s")
	if winning_team == player_team:
		result_label.text = "VICTORY!"
		result_label.modulate = win_color
		print("[EndingScreen] Set to VICTORY")
	else:
		result_label.text = "DEFEAT"
		result_label.modulate = lose_color
		print("[EndingScreen] Set to DEFEAT")
	print("[EndingScreen] show_result completed")

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_return_pressed():
	# Return to the original position before battle started
	# Use the battle manager's return scene
	if BattleManager and BattleManager.has_method("_return_to_main_world"):
		BattleManager._return_to_main_world()
	else:
		# Fallback: switch to main world directly
		SceneSwitcher.switch_scene("main_world", "fade")
