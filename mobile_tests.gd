extends SceneTree

func _initialize() -> void:
	call_deferred("check_scene")

func check_scene() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	assert(scene.camera.current)
	assert(scene.action_panel.visible)
	assert(scene.camera.global_position.y > 20)
	scene.intro.hide()
	scene.paused = false
	scene.update_ui()
	assert(not scene.buttons["chicken"].disabled)
	var count: int = scene.game.farms[0].chickens
	scene.buttons["chicken"].pressed.emit()
	assert(scene.game.farms[0].chickens == count + 1)
	scene.game.farms[0].coins = 2000
	for action in ["sell", "expand", "fence", "dog"]:
		assert(not scene.buttons[action].disabled)
		scene.buttons[action].pressed.emit()
		scene.update_ui()
	assert(scene.game.farms[0].land == 1)
	assert(scene.game.farms[0].dogs == 1)
	assert(scene.game.farms[0].fence == 1)
	assert(scene.buildings[0].get_child_count() > 30)
	scene.game.launch_raid(0, 0)
	scene.sync_raiders()
	var r: Dictionary = scene.game.raids[0]
	assert(scene.route_position(r).is_equal_approx(r.points[0]))
	r.elapsed = r.duration * 0.5
	assert(scene.route_position(r).distance_to(r.points[0]) > 5)
	r.at_gate = true
	assert(scene.route_position(r).is_equal_approx(r.points[-1]))
	scene.game.spawn_coyote(0)
	scene.sync_raiders()
	assert(scene.raider_nodes.size() == 2)
	for side in 2:
		for edge in [-1, 1]:
			assert(scene.camera.is_position_in_frustum(Vector3(scene.game.farm_center(side) + edge * 10, 0, 0)))
	scene.pause_button.pressed.emit()
	assert(scene.paused)
	assert(scene.buttons["raid"].disabled)
	scene.queue_free()
	print("Mobile overhead checks: PASS")
	quit()
