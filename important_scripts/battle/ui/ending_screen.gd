extends Control

enum Team { PLAYER = 0, OPPONENT = 1 }

@export var win_color: Color = Color.GREEN
@export var lose_color: Color = Color.RED

@onready var result_label: Label = $BackgroundPanel/VBoxContainer/ResultLabel
@onready var exp_label: Label = $BackgroundPanel/VBoxContainer/ExpLabel
@onready var crystal_label: Label = $BackgroundPanel/VBoxContainer/CrystalLabel
@onready var background: Panel = $BackgroundPanel

var _pending_exp: int = 0
var _pending_crystals: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

## Called by BattleManager with pre-calculated reward values
func show_result_with_rewards(is_victory: bool, exp_earned: int, crystals_earned: int) -> void:
	_pending_exp = exp_earned
	_pending_crystals = crystals_earned
	visible = true
	
	if is_victory:
		result_label.text = "VICTORY!"
		result_label.modulate = win_color
	else:
		result_label.text = "DEFEAT"
		result_label.modulate = lose_color
	
	if exp_label:
		exp_label.text = "+%d EXP" % exp_earned
	if crystal_label:
		crystal_label.text = "+%d 水晶" % crystals_earned

func _on_restart_pressed():
	get_tree().paused = false
	BattleTransitionManager.start_battle(BattleTransitionManager.current_config)

func _on_return_pressed():
	get_tree().paused = false
	BattleTransitionManager.end_battle(_pending_exp, _pending_crystals)
