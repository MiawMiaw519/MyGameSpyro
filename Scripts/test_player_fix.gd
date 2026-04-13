extends Node3D

class_name PlayerTester

# Test script to validate animations and player movement

func _ready() -> void:
	print("\n========== PLAYER FIX TESTS ==========")
	await get_tree().create_timer(0.5).timeout
	test_animations()
	test_inputs()

func test_animations() -> void:
	print("\n📋 TESTING ANIMATIONS:")
	var player = get_tree().root.get_child(0).get_node_or_null("Spyro/CharacterBody3D")
	if not player:
		print("❌ Player not found!")
		return
	
	print("✅ Player found:", player.name)
	print("   Idle anim:", player.idle_animation_name)
	print("   Walk anim:", player.walk_animation_name)
	print("   Run anim:", player.run_animation_name)
	print("   Jump anim:", player.jump_animation_name)
	print("   Glide anim:", player.glide_animation_name)
	print("   Charge anim:", player.charge_animation_name)
	print("   Flame anim:", player.flame_animation_name)
	print("   Landing anim:", player.landing_animation_name)

func test_inputs() -> void:
	print("\n🎮 TESTING INPUTS:")
	print("✓ Move (ZQSD/WASD)")
	print("✓ Jump (SPACE)")
	print("✓ Charge (SHIFT)")
	print("✓ Flame (LEFT MOUSE or CTRL)")
	print("\n   Try these:")
	print("   1. Walk slowly (gentle ZQSD)")
	print("   2. Run fast (hold ZQSD)")
	print("   3. Jump (SPACE)")
	print("   4. Glide (SPACE x2 while jumping)")
	print("   5. Charge (SHIFT)")
	print("   6. Flame attack (LEFT CLICK or CTRL)")

func _process(_delta: float) -> void:
	# Monitor player state for debugging
	var player = get_tree().root.get_child(0).get_node_or_null("Spyro/CharacterBody3D")
	if player and player.anim_player:
		var state_name = player.State.keys()[player.current_state]
		var anim_name = player.anim_player.current_animation
		var speed = Vector2(player.velocity.x, player.velocity.z).length()
		
		# Only print when animation changes
		if anim_name != player.current_animation:
			print("🎬 Animation changed to: %s (State: %s, Speed: %.1f)" % [anim_name, state_name, speed])
