extends Node

## --- Signals ---
signal battle_started(config: Dictionary)
signal rewards_applied(exp_earned: int, crystals_earned: int)

## --- State ---
var current_config: Dictionary = {}
var _return_scene: String = "main_world"

## --- Forward Transition: World → Battle ---
## Called by tp_point.gd with a config dictionary built from its @export vars.
func start_battle(config: Dictionary, return_scene: String = "main_world") -> void:
	current_config = config
	_return_scene = return_scene
	battle_started.emit(config)
	SceneSwitcher.switch_scene("battle_scene", "fade")

## --- Return Transition: Battle → World ---
## Called by ending_screen.gd with final calculated values.
func end_battle(exp_earned: int, crystals_earned: int) -> void:
	ProgressManager.current_exp += exp_earned
	ProgressManager.crystal_count += crystals_earned
	rewards_applied.emit(exp_earned, crystals_earned)
	print("[BattleTransition] Applied: +%d EXP, +%d Crystals" % [exp_earned, crystals_earned])
	SceneSwitcher.switch_scene(_return_scene, "fade")
