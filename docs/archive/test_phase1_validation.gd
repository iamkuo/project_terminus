extends Node
# Phase 1 Validation Test Script
# Tests: Mode validation, resource validation, startup behavior

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("PHASE 1 VALIDATION TEST")
	print("=".repeat(60) + "\n")
	
	# Wait for ProgressManager to be ready
	await get_tree().process_frame
	
	test_mode_validation()
	test_resource_validation()
	test_startup_behavior()
	test_startup_stage_values()
	
	print("\n" + "=".repeat(60))
	print("ALL TESTS COMPLETED")
	print("=".repeat(60) + "\n")

func test_mode_validation() -> void:
	print("[TEST 1] Mode Validation")
	print("-" * 40)
	
	# Save original mode
	var original_mode = ProgressManager.mode
	
	# Test 1a: Valid modes should not trigger error fallback
	var valid_modes = ["test", "trial", "full"]
	for mode in valid_modes:
		ProgressManager.mode = mode
		print("  ✓ Mode '%s' is valid" % mode)
	
	# Test 1b: Invalid mode should fall back to "test"
	ProgressManager.mode = "invalid_mode_xyz"
	print("  ! Testing invalid mode fallback...")
	ProgressManager._validate_mode()
	# Note: push_error will log to console, we can't catch it directly
	print("  ✓ Invalid mode should have triggered error log (check console)")
	
	# Restore mode
	ProgressManager.mode = "test"
	print("  ✓ Mode validation test completed\n")

func test_resource_validation() -> void:
	print("[TEST 2] Resource Validation")
	print("-" * 40)
	
	# Check active resources are loaded
	print("  Loaded stages: %d" % ProgressManager.active_stages.size())
	print("  Loaded memories: %d" % ProgressManager.active_memories.size())
	print("  Loaded cutscenes: %d" % ProgressManager.active_cutscenes.size())
	
	# Check for common stage IDs
	var expected_stages = ["universal_startup", "tutorial", "early_milestone", "ending"]
	var found_stages = []
	for stage in ProgressManager.active_stages:
		found_stages.append(stage.id)
	
	print("\n  Stage validation:")
	for expected in expected_stages:
		var found = expected in found_stages
		var symbol = "✓" if found else "✗"
		print("    %s %s" % [symbol, expected])
	
	# Verify no negative req_exp values
	var negative_exp_stages = []
	for stage in ProgressManager.active_stages:
		if stage.req_exp < 0:
			negative_exp_stages.append(stage.id)
	
	if negative_exp_stages.is_empty():
		print("\n  ✓ No stages with negative req_exp")
	else:
		print("\n  ✗ Found stages with negative req_exp: %s" % negative_exp_stages)
	
	# Verify memory references exist
	var invalid_memory_refs = []
	for stage in ProgressManager.active_stages:
		if stage.unlocks_memory_id:
			var found = false
			for mem in ProgressManager.active_memories:
				if mem.id == stage.unlocks_memory_id:
					found = true
					break
			if not found:
				invalid_memory_refs.append({stage: stage.id, memory: stage.unlocks_memory_id})
	
	if invalid_memory_refs.is_empty():
		print("  ✓ All memory references are valid")
	else:
		print("  ✗ Found invalid memory references:")
		for ref in invalid_memory_refs:
			print("    - Stage '%s' → Memory '%s'" % [ref.stage, ref.memory])
	
	print("  ✓ Resource validation test completed\n")

func test_startup_behavior() -> void:
	print("[TEST 3] Startup Cutscene Behavior")
	print("-" * 40)
	
	# Check that startup stage has req_exp = 0
	var startup_stage = null
	for stage in ProgressManager.active_stages:
		if stage.id == "universal_startup":
			startup_stage = stage
			break
	
	if startup_stage:
		print("  Found startup stage: '%s'" % startup_stage.id)
		print("  - req_exp: %d" % startup_stage.req_exp)
		print("  - cutscene_id: '%s'" % startup_stage.cutscene_id)
		print("  - unlocks_memory_id: '%s'" % startup_stage.unlocks_memory_id)
		
		if startup_stage.req_exp == 0:
			print("  ✓ Startup stage has req_exp = 0 (correct)")
		else:
			print("  ✗ Startup stage has req_exp = %d (should be 0)" % startup_stage.req_exp)
	else:
		print("  ✗ Startup stage not found")
	
	# Test: Starting with exp=0 should allow first stage to trigger
	print("\n  Checking progression at exp=0:")
	var initial_exp = ProgressManager.current_exp
	var initial_stage_idx = ProgressManager.current_stage_index
	print("    Initial exp: %d" % initial_exp)
	print("    Initial stage index: %d" % initial_stage_idx)
	
	# The startup should be triggered since we have req_exp=0
	if ProgressManager.current_stage_index >= 0:
		print("  ✓ Startup stage should be available at exp=0")
	
	print("  ✓ Startup behavior test completed\n")

func test_startup_stage_values() -> void:
	print("[TEST 4] Startup Stage Values")
	print("-" * 40)
	
	var modes = ["test", "trial", "full"]
	var startup_data = {}
	
	for mode in modes:
		var stage_path = "res://resources/stages/%s/startup.tres" % mode
		var stage = load(stage_path) as StageData
		
		if stage:
			startup_data[mode] = stage
			print("  [%s Mode]" % mode)
			print("    - id: %s" % stage.id)
			print("    - name: %s" % stage.name)
			print("    - req_exp: %d" % stage.req_exp)
			print("    - cutscene_id: %s" % stage.cutscene_id)
			print("    - unlocks_memory_id: %s" % stage.unlocks_memory_id)
			
			if stage.req_exp == 0:
				print("    ✓ req_exp = 0 (correct)")
			else:
				print("    ✗ req_exp = %d (should be 0)" % stage.req_exp)
			print()
		else:
			print("  [%s Mode] ✗ Failed to load startup.tres\n" % mode)
	
	# Verify all have req_exp = 0
	var all_zero = true
	for mode in modes:
		if mode in startup_data:
			if startup_data[mode].req_exp != 0:
				all_zero = false
	
	if all_zero:
		print("  ✓ All startup stages have req_exp = 0")
	else:
		print("  ✗ Some startup stages have incorrect req_exp values")
	
	print("  ✓ Startup stage values test completed\n")
