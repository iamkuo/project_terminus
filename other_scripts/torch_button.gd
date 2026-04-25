# torch_button.gd
extends Control

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var memory_label: Label = $MemoryLabel
var _last_unlocked_state: Variant = null 
var _pending_is_unlocked: Variant = null

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
				print("[Debug] ", name, ": Lit")
			else:
				animated_sprite.play("unlit")
				self.modulate = Color(0.6, 0.6, 0.6)
				print("[Debug] ", name, ": Unlit")

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
			# 計算縮放比例：讓貼圖填滿 Control 節點的大小
			# 如果你希望保持比例，取 min(size.x/tex.x, size.y/tex.y)
			var scale_factor = Vector2(size.x / tex_size.x, size.y / tex_size.y)
			animated_sprite.scale = scale_factor
			
			# 強制置中：Sprite 的中心點 = 父節點尺寸的一半
			animated_sprite.position = size / 2
			
			# 如果火把還是太小，檢查你的 Control 節點是否有設定 Custom Minimum Size

func _ready() -> void:
	# 確保在容器完成排版後才計算
	await get_tree().process_frame 
	resized.connect(_update_layout)
	if _pending_is_unlocked != null:
		refresh_visuals(_pending_is_unlocked)
	else:
		refresh_visuals()

func set_memory_name(memory_name: String) -> void:
	"""Set the memory name displayed on the label."""
	if memory_label:
		memory_label.text = memory_name
