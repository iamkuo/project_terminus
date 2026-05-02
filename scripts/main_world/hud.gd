extends Control

@onready var gems_label: Label = $MarginContainer/HBoxContainer/gems
@onready var exp_label: Label = $MarginContainer/HBoxContainer/exp
@onready var lvl_label: Label = $MarginContainer/HBoxContainer/lvl
@onready var hud_button: Button = $MarginContainer/HBoxContainer/Button

func _ready() -> void:
	hud_button.pressed.connect(_on_hud_button_pressed)
	_refresh_hud_labels()
	self.visible = true
	ProgressManager.data_updated.connect(_refresh_hud_labels)
	BattleManager.rewards_applied.connect(_show_reward_toast)
	
	# Set initial cheat button visibility
	_update_cheat_button_visibility()

func _on_hud_button_pressed() -> void:
	ProgressManager.crystal_count += 1000
	ProgressManager.current_exp += 500
	ProgressManager.data_updated.emit()

func _refresh_hud_labels() -> void:
	gems_label.text = "水晶數量: %d" % ProgressManager.crystal_count
	
	var current_lvl = ProgressManager.get_current_level()
	var next_exp = ProgressManager.get_next_level_exp()
	
	lvl_label.text = "LVL: %d" % current_lvl
	
	if next_exp > 0:
		exp_label.text = "EXP: %d / %d" % [ProgressManager.current_exp, next_exp]
	else:
		exp_label.text = "EXP: %d (MAX)" % ProgressManager.current_exp

func _show_reward_toast(exp_earned: int, crystals_earned: int) -> void:
	MessageManager.show_message("+%d EXP  +%d 水晶" % [exp_earned, crystals_earned])
	_refresh_hud_labels() # Ensure labels update immediately when rewards are applied

func _process(_delta: float) -> void:
	# Check cheat mode visibility continuously
	_update_cheat_button_visibility()

func _update_cheat_button_visibility() -> void:
	hud_button.visible = ConfigManager.cheat_mode
