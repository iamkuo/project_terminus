extends Control

@onready var gems_label: Label = $MarginContainer/HBoxContainer/gems
@onready var hud_button: Button = $MarginContainer/HBoxContainer/Button
@onready var reward_label: Label = $MarginContainer/HBoxContainer/RewardLabel

func _ready() -> void:
	hud_button.pressed.connect(_on_hud_button_pressed)
	_refresh_crystal_label()
	self.visible = true
	ProgressManager.data_updated.connect(_refresh_crystal_label)
	BattleTransitionManager.rewards_applied.connect(_show_reward_toast)

func _on_hud_button_pressed() -> void:
	ProgressManager.crystal_count += 1
	ProgressManager.data_updated.emit()

func _refresh_crystal_label() -> void:
	gems_label.text = "水晶數量: %d" % ProgressManager.crystal_count

func _show_reward_toast(exp_earned: int, crystals_earned: int) -> void:
	if reward_label:
		reward_label.text = "+%d EXP  +%d 水晶" % [exp_earned, crystals_earned]
		reward_label.show()
		await get_tree().create_timer(3.0).timeout
		reward_label.hide()
