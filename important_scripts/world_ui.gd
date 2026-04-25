extends CanvasLayer

# =============================
# Node References
# =============================
@onready var hud: Control = $HUD
@onready var pause_menu: Control = $Pause

# set_coin removed — HUD now reads directly from ProgressManager.crystal_count
