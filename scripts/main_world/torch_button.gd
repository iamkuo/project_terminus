# torch_button.gd
extends Control

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var memory_label: Label = $MemoryLabel
var _last_unlocked_state: Variant = null 
var _pending_is_unlocked: Variant = null
var _memory_name: String = ""

func refresh_visuals(is_unlocked = null) -> void:
	if is_unlocked != null:
		_pending_is_unlocked = is_unlocked
		
	if not is_inside_tree() or not animated_sprite:
		return

	# 1. 狀態處理與 Debug (維持原樣)
	var state_to_apply = is_unlocked if is_unlocked != null else _pending_is_unlocked
	if state_to_apply != null:
		if state_to_apply != _last_unlocked_state:
			_last_unlocked_state = state_to_apply
			if state_to_apply:
				animated_sprite.play("lit")
				self.modulate = Color.WHITE
			else:
				animated_sprite.play("unlit")
				self.modulate = Color(0.6, 0.6, 0.6)
	
	_update_label()

	# 2. 修正縮放與置中邏輯
	_update_layout()

func _update_layout() -> void:
	var frames = animated_sprite.sprite_frames
	if not frames: return
	
	# 取得當前動畫的第一張貼圖來計算尺寸
	var curr_anim = animated_sprite.animation
	var tex = frames.get_frame_texture(curr_anim, 0)
	
	if tex:
		var tex_size = tex.get_size()
		# 防止除以零
		if tex_size.x > 0 and tex_size.y > 0:
			# Calculate scale factor while keeping aspect ratio
			var scale_x = size.x / tex_size.x
			var scale_y = size.y / tex_size.y
			var uniform_scale = min(scale_x, scale_y)
			animated_sprite.scale = Vector2(uniform_scale, uniform_scale)
			
			# 強制置中：Sprite 的中心點 = 父節點尺寸的一半
			animated_sprite.position = size / 2
			
			# 如果火把還是太小，檢查你的 Control 節點是否有設定 Custom Minimum Size

func _ready() -> void:
	resized.connect(_update_layout)
	if _pending_is_unlocked != null:
		refresh_visuals(_pending_is_unlocked)
	else:
		refresh_visuals()

func set_memory_name(memory_name: String) -> void:
	"""Set the memory name displayed on the label."""
	_memory_name = memory_name
	_update_label()

func _update_label() -> void:
	if memory_label:
		if _last_unlocked_state:
			memory_label.text = _memory_name
		else:
			memory_label.text = "???"
