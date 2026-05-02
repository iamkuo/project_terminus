extends Node

# Test script to verify game mode discovery
func _ready() -> void:
	print("=== Testing Game Mode Discovery ===")
	
	var orders_path = "res://resources/memories/orders/"
	var dir = DirAccess.open(orders_path)
	
	if not dir:
		print("Failed to open orders directory: ", orders_path)
		return
	
	print("Successfully opened orders directory: ", orders_path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var found_modes = []
	
	while file_name != "":
		print("Found file: ", file_name)
		if file_name.ends_with("_memory_order.tres"):
			var mode_name = file_name.replace("_memory_order.tres", "")
			found_modes.append(mode_name)
			print("  -> Game mode detected: ", mode_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("\n=== Summary ===")
	print("Total game modes found: ", found_modes.size())
	for mode in found_modes:
		print("  - ", mode)
	
	# Test display name mapping
	var mode_display_names = {
		"full": "完整模式",
		"trial": "試玩模式", 
		"test": "測試模式"
	}
	
	print("\n=== Display Name Mapping ===")
	for mode in found_modes:
		var display_name = mode_display_names.get(mode, "未知模式 (" + mode + ")")
		print(mode, " -> ", display_name)
	
	print("\nTest completed!")
	get_tree().quit()
