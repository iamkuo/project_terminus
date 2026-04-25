extends Resource
class_name CutsceneStep

enum StepType {
	DIALOG,
	MOVE,
	FULLSCREEN_TEXT,
	FULLSCREEN_IMAGE
}

@export var type: StepType

# ---- Dialog ----
@export var speaker: String
@export_multiline var text: String

# ---- Move ----
@export var actor_path: NodePath
@export var target_position: Vector2
@export var duration: float = 0.5

# ---- Fullscreen ----
@export var texture: Texture2D
