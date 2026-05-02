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
@onready var title_label: Label = $BackgroundPanel/VBoxContainer/TitleLabel
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_result(winning_team: int):
	print("[EndingScreen] show_result called with winning_team: ", winning_team)
	visible = true
	print("[EndingScreen] Visible set to true")
	
	# Merge battle name and result in title
	var battle_name = ConfigManager.battle_name
	if not battle_name or battle_name.is_empty():
		battle_name = "戰鬥"
	
	var result_text = "勝利！" if winning_team == player_team else "失敗"
	title_label.text = battle_name + " - " + result_text
	
	if winning_team == player_team:
		title_label.modulate = win_color
		print("[EndingScreen] Set to VICTORY")
	else:
		title_label.modulate = lose_color
		print("[EndingScreen] Set to DEFEAT")
	
	# Hide the separate result label since it's now merged with title
	result_label.visible = false
	
	kills_label.text = "擊敗數:" + str(BattleManager.enemy_killed)
	damage_label.text = "造成傷害:" +str(BattleManager.damage_dealt)
	time_label.text = "戰鬥時間:" + str("%01d" % BattleManager.minutes) + str("分")+ str("%02d" % BattleManager.seconds) + str("秒")
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
