extends Control

@onready var gems_label: Label = $MarginContainer/HBoxContainer/gems
@onready var hud_button: Button = $MarginContainer/HBoxContainer/Button

func _ready() -> void:
	hud_button.pressed.connect(_on_hud_button_pressed)
	_refresh_crystal_label()
	self.visible = true
	ProgressManager.data_updated.connect(_refresh_crystal_label)
	BattleManager.rewards_applied.connect(_show_reward_toast)

func _on_hud_button_pressed() -> void:
	ProgressManager.crystal_count += 1000
	ProgressManager.data_updated.emit()

func _refresh_crystal_label() -> void:
	gems_label.text = "水晶數量: %d" % ProgressManager.crystal_count

func _show_reward_toast(exp_earned: int, crystals_earned: int) -> void:
	MessageManager.show_message("+%d EXP  +%d 水晶" % [exp_earned, crystals_earned])
