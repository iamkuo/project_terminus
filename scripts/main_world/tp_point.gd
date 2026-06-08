extends AnimatedSprite2D

## --- Battle Identity ---
## Unique battle identifier. If empty, a fallback ID will be generated.
@export var battle_id: String = ""
## Battle name shown on the victory/ending screen. If empty, falls back to the battle ID.
@export var battle_name: String = ""

## --- Visual / Scene Setup ---
## Custom battle background scene. If empty, uses the default background.
@export var background_scene: PackedScene
## Custom music track to play during battle. If empty, no custom music is played.
@export var music_track: AudioStream

## --- AI Enemy Configuration ---
## Minimum spawn cooldown (in seconds) for enemy units.
@export var ai_cooldown_min: float = 2.0
## Maximum spawn cooldown (in seconds) for enemy units.
@export var ai_cooldown_max: float = 5.0

## --- Player Constraints ---
## Starting聖水 (elixir) amount for the player.
@export var starting_elixir: float = 5.0

## --- Tower Stats ---
## Starting HP for the player's towers. Set to 0 to use scene/tower defaults.
@export var player_tower_hp: int = 1000
## Starting HP for the opponent's towers. Set to 0 to use scene/tower defaults.
@export var enemy_tower_hp: int = 1000

## --- Reward Configuration (Victory only) ---
## Base EXP rewarded on victory.
@export var exp_reward_victory: int = 100
## Base crystals rewarded on victory.
@export var crystal_reward_victory: int = 50
## EXP granted per enemy killed.
@export var exp_per_kill: int = 10
## EXP granted per 1 damage dealt to enemies.
@export var exp_per_damage: float = 0.05
## Crystals granted per enemy killed.
@export var crystals_per_kill: int = 2
## Enemy strength multiplier (affects health and damage).
@export var enemy_multiplyer: float = 1

## --- Memory Unlock ---
## Memory ID to unlock when the player wins this battle. Leave empty for none.
@export var unlock_memory_on_win: String = ""

## --- Loss Return Safety ---
## Offset (in world-space pixels) applied to the player's position when returning
## after a loss, to ensure they don't land inside this trigger's Area2D again.
## Set this in the editor to a direction that is clear of walls/terrain.
## Example: Vector2(0, 150) pushes the player 150px downward (below the trigger).
@export var loss_return_offset: Vector2 = Vector2(0, 150)

# Guard flag: prevents the Area2D from firing immediately after the scene loads.
# Necessary because on loss-return the player is placed at the saved position
# which is inside the Area2D, and body_entered would fire on the same frame.
var _entry_cooldown_active: bool = true

func _ready() -> void:
	if BattleManager.is_tp_point_triggered(_get_internal_id()):
		queue_free()
		return

	# Allow 0.5 s before the Area2D signal is honoured.
	# The signal is wired in the .tscn so we can't defer connecting it;
	# instead we gate it via this flag.
	await get_tree().create_timer(0.5).timeout
	_entry_cooldown_active = false

func _on_area_2d_body_entered(_body: Node2D) -> void:
	if _entry_cooldown_active:
		return
	if not _is_valid_player(_body):
		return

	# NOTE: We intentionally do NOT call mark_tp_point_triggered here.
	# BattleManager will mark it only on a player victory, so a loss
	# causes the tp_point to reappear when the world is reloaded.
	ConfigManager.load_config(_build_config())
	BattleManager.start_battle(_body)
	queue_free()

func _is_valid_player(body: Node2D) -> bool:
	return body.name == "Player" or body.is_in_group("player")

func _build_config() -> Dictionary:
	return {
		"battle_id": battle_id,
		"battle_name": battle_name,
		"background_scene": background_scene,
		"music_track": music_track,
		"enemy_multiplyer": enemy_multiplyer,
		"ai_cooldown_min": ai_cooldown_min,
		"ai_cooldown_max": ai_cooldown_max,
		"starting_elixir": starting_elixir,
		"player_tower_hp": player_tower_hp,
		"enemy_tower_hp": enemy_tower_hp,
		"exp_reward_victory": exp_reward_victory,
		"crystal_reward_victory": crystal_reward_victory,
		"exp_per_kill": exp_per_kill,
		"exp_per_damage": exp_per_damage,
		"crystals_per_kill": crystals_per_kill,
		# Memory unlock
		"unlock_memory_on_win": unlock_memory_on_win,
		# TP Point identity (used by BattleManager to mark triggered on WIN only)
		"tp_point_id": _get_internal_id(),
		"tp_point_position": global_position,
		"tp_point_loss_return_offset": loss_return_offset,
	}

func _get_internal_id() -> String:
	if not battle_id.is_empty():
		return battle_id
	# Fallback: Create a unique ID based on the scene name and global position
	# This ensures it's robust even if the user forgets to set a unique battle_id
	var scene_name = "unknown_scene"
	if get_tree() and get_tree().current_scene:
		scene_name = get_tree().current_scene.name

	return "%s_%s" % [scene_name, str(global_position)]
