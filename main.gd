extends Node3D

var game := FarmMatch.new()
var birds: Array[Node3D] = []
var buildings: Array[Node3D] = []
var raider_nodes: Dictionary = {}
var route_world: Node3D
var stats: Label
var enemy_stats: Label
var timer_label: Label
var notice_label: Label
var result_panel: PanelContainer
var result_label: Label
var buttons: Dictionary = {}
var clock := 0.0
var refresh := 0.0
var paused := true
var pause_button: Button
var intro: PanelContainer
var camera: Camera3D
var action_panel: PanelContainer
var farm_button: Button
var preview_mode := false
var preview_frames := 0

func _ready() -> void:
	build_world()
	build_camera()
	build_ui()
	update_ui()
	sync_farms()
	preview_mode = "--preview" in OS.get_cmdline_user_args()
	if preview_mode:
		intro.hide()
		paused = false
		game.farms[0].fence = 1
		game.farms[0].coops = 2
		sync_farms()
		update_ui()

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		n.add_child(body)
	return n

func sphere(parent: Node3D, pos: Vector3, scale_v: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	n.mesh = mesh
	n.material_override = material(color)
	n.scale = scale_v
	n.position = pos
	parent.add_child(n)
	return n

func build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("76b3dd")
	sky_material.sky_horizon_color = Color("d4e8ea")
	sky_material.ground_horizon_color = Color("c8debf")
	sky_material.ground_bottom_color = Color("669151")
	sky.sky_material = sky_material
	e.sky = sky
	e.fog_enabled = true
	e.fog_light_color = Color("cadfd5")
	e.fog_density = 0.003
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff0d5")
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	box(self, Vector3(0, -0.5, 0), Vector3(180, 0.1, 180), Color("719b53"))
	box(self, Vector3(0, -0.4, 0), Vector3(70, 0.8, 34), Color("78aa59"), true)
	build_routes()
	for side in 2:
		var x := game.farm_center(side)
		
		var barn := Node3D.new()
		add_child(barn)
		barn.position = Vector3(x, 0, -3.8)
		box(barn, Vector3(0, 1.4, 0), Vector3(4.5, 2.8, 3.2), Color("287a91") if side == 0 else Color("d26b50"), true)
		for roof_side in [-1, 1]:
			var roof := box(barn, Vector3(roof_side * 1.15, 3.17, 0), Vector3(2.65, 0.25, 3.8), Color("40494f"))
			roof.rotation_degrees.z = -roof_side * 25
		box(barn, Vector3(0, 0.9, 1.64), Vector3(1.2, 1.8, 0.1), Color("f3dda5"))
		for dx in [-1.6, 1.6]:
			box(barn, Vector3(dx, 1.7, 1.65), Vector3(0.65, 0.7, 0.1), Color("c3eef0"))
		var title := Label3D.new()
		title.text = "YOUR FARM" if side == 0 else "RIVAL FARM"
		title.position = Vector3(x, 4.6, -3.8)
		title.font_size = 48
		title.pixel_size = 0.012
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(title)
		var flock := Node3D.new()
		add_child(flock)
		birds.append(flock)
		var structures := Node3D.new()
		add_child(structures)
		buildings.append(structures)

func build_camera() -> void:
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 30
	camera.position = Vector3(0, 48, 34)
	camera.look_at(Vector3.ZERO)
	camera.far = 160
	get_viewport().size_changed.connect(fit_camera)
	fit_camera()

func fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y > 0:
		camera.size = maxf(48.0, 80.0 / (viewport_size.x / viewport_size.y))

func chicken(parent: Node3D, pos: Vector3) -> Node3D:
	var c := Node3D.new()
	parent.add_child(c)
	c.position = pos
	sphere(c, Vector3(0, 0.4, 0), Vector3(0.58, 0.65, 0.7), Color("fff3d6"))
	sphere(c, Vector3(0, 0.75, 0.2), Vector3(0.4, 0.42, 0.4), Color("ffffff"))
	box(c, Vector3(0, 1.0, 0.18), Vector3(0.12, 0.15, 0.25), Color("e65442"))
	box(c, Vector3(0, 0.73, 0.44), Vector3(0.16, 0.12, 0.22), Color("efb444"))
	for x in [-0.11, 0.11]:
		box(c, Vector3(x, 0.1, 0), Vector3(0.06, 0.2, 0.1), Color("dca53b"))
		box(c, Vector3(x * 1.65, 0.8, 0.32), Vector3(0.055, 0.06, 0.06), Color("333c40"))
	return c

func sync_farms() -> void:
	for side in 2:
		var f := game.farms[side]
		var flock := birds[side]
		if flock.get_child_count() != f.chickens:
			for child in flock.get_children():
				flock.remove_child(child)
				child.queue_free()
			for i in f.chickens:
				var x: float = game.farm_center(side) + (i % 6 - 2.5) * 1.25
				var z: float = -1.6 + floorf(i / 6.0) * 0.95
				chicken(flock, Vector3(x, 0, z))
		var structure := buildings[side]
		var key := "%d:%d:%d:%d" % [f.coops, f.fence, f.land, f.dogs]
		if structure.get_meta("key", "") == key: continue
		structure.set_meta("key", key)
		for child in structure.get_children():
			structure.remove_child(child)
			child.queue_free()
		var home_x := game.farm_center(side)
		var radius := game.farm_radius(side)
		box(structure, Vector3(home_x, 0.02, 0), Vector3(radius * 2, 0.1, radius * 2), Color("aacb70"))
		for i in f.coops:
			var cx: float = home_x - 4.2 + (i % 3) * 2.8
			box(structure, Vector3(cx, 0.5, 4 + (i / 3) * 2.2), Vector3(2, 1, 1.6), Color("e4bd7c"), true)
			box(structure, Vector3(cx, 1.1, 4 + (i / 3) * 2.2), Vector3(2.2, 0.25, 1.9), Color("98774f"))
			box(structure, Vector3(cx, 0.35, 4.82 + (i / 3) * 2.2), Vector3(0.6, 0.65, 0.04), Color("69513a"))
		if f.fence > 0:
			var color := Color("c7a274") if f.fence < 3 else Color("7699a1")
			for edge in [-1, 1]:
				for rail in range(f.fence + 1):
					var y := 0.45 + rail * 0.38
					box(structure, Vector3(home_x, y, edge * radius), Vector3(radius * 2, 0.18, 0.22), color)
					box(structure, Vector3(home_x + edge * radius, y, 0), Vector3(0.22, 0.18, radius * 2), color)
				for n in range(-int(radius), int(radius) + 1, 2):
					box(structure, Vector3(home_x + n, 0.85, edge * radius), Vector3(0.3, 1.7, 0.3), color)
					box(structure, Vector3(home_x + edge * radius, 0.85, n), Vector3(0.3, 1.7, 0.3), color)
			# Closed gate marks where raiders wait to breach the fence.
			box(structure, Vector3(home_x + (radius if side == 0 else -radius), 0.8, 0), Vector3(0.35, 1.6, 2), Color("d5a64c"))
		for i in f.dogs:
			var dog := animal(structure, Color("8d623c"))
			dog.set_meta("guard_side", side)
			dog.set_meta("guard_index", i)
			dog.position = Vector3(home_x + radius - 1, 0, -radius + 2 + i * 1.5)

func animal(parent: Node3D, color: Color) -> Node3D:
	var dog := Node3D.new()
	parent.add_child(dog)
	box(dog, Vector3(0, 0.6, 0), Vector3(0.65, 0.55, 1.1), color)
	sphere(dog, Vector3(0, 0.85, 0.6), Vector3(0.5, 0.5, 0.55), color)
	for x in [-0.22, 0.22]:
		for z in [-0.35, 0.35]:
			box(dog, Vector3(x, 0.22, z), Vector3(0.15, 0.45, 0.15), color)
	return dog

func build_routes() -> void:
	if is_instance_valid(route_world):
		remove_child(route_world)
		route_world.queue_free()
	route_world = Node3D.new()
	add_child(route_world)
	for route in game.routes:
		var points: Array[Vector3] = [Vector3(-16, 0, 0)]
		points.append_array(route.points)
		points.append(Vector3(16, 0, 0))
		for i in range(1, points.size()):
			var a := points[i-1]
			var b := points[i]
			var path := box(route_world, (a+b)*0.5 + Vector3(0, 0.1, 0), Vector3(1.8, 0.1, a.distance_to(b)), [Color("e5cb8f"), Color("b69d76"), Color("79694f")][route.terrain])
			path.rotation.y = atan2(b.x-a.x, b.z-a.z)
		var obstacle: Vector3 = route.obstacle
		box(route_world, obstacle + Vector3(0, 0.7, 0), Vector3(5, 1.4, 2.2), Color("697e70"))
		var sign := Label3D.new()
		sign.text = ["FAST PATH", "TRAIL", "MUD: SLOW"][route.terrain]
		sign.position = obstacle + Vector3(0, 2.5, 0)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 38
		sign.pixel_size = 0.025
		route_world.add_child(sign)

func route_position(r: Dictionary) -> Vector3:
	var points: Array[Vector3] = r.points
	if r.at_gate: return points[-1]
	var t := clampf(r.elapsed / r.duration, 0, 1)
	if r.leg == 1: t = 1.0 - t
	var length := 0.0
	for i in range(1, points.size()): length += points[i-1].distance_to(points[i])
	var distance := t * length
	for i in range(1, points.size()):
		var segment := points[i-1].distance_to(points[i])
		if distance <= segment: return points[i-1].lerp(points[i], distance / maxf(segment, 0.001))
		distance -= segment
	return points[-1]

func label(text_value: String, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("fff3db"))
	return l

func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("203c3c")
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var top := PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.add_theme_stylebox_override("panel", panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	stats = label("")
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats)
	timer_label = label("", 26)
	row.add_child(timer_label)
	enemy_stats = label("")
	enemy_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(enemy_stats)
	farm_button = Button.new()
	farm_button.text = "Hide actions"
	farm_button.custom_minimum_size = Vector2(150, 48)
	farm_button.pressed.connect(func():
		if intro.visible or game.finished: return
		action_panel.visible = not action_panel.visible
		farm_button.text = "Hide actions" if action_panel.visible else "Farm & raids"
		update_ui())
	row.add_child(farm_button)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(90, 48)
	pause_button.pressed.connect(func():
		if game.finished or intro.visible: return
		paused = not paused
		pause_button.text = "Resume" if paused else "Pause"
		update_ui())
	row.add_child(pause_button)
	var bottom := PanelContainer.new()
	action_panel = bottom
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_top = -202
	bottom.offset_bottom = -12
	bottom.add_theme_stylebox_override("panel", panel_style())
	bottom.show()
	var column := VBoxContainer.new()
	bottom.add_child(column)
	column.add_child(label("Eggs earn coins • Meat pays now • Larger farms need more guards", 18))
	# Status stays visible while the action panel is closed.
	notice_label = label("", 18)
	root.add_child(notice_label)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice_label.offset_top = 115
	notice_label.offset_bottom = 145
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.add_theme_color_override("font_shadow_color", Color("203c3c"))
	notice_label.add_theme_constant_override("shadow_offset_x", 2)
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	var actions := GridContainer.new()
	actions.columns = 4
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	for action in ["chicken", "sell", "coop", "expand", "fence", "dog", "boots", "raid"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func():
			if paused: return
			game.buy(0, action)
			sync_farms()
			update_ui())
		actions.add_child(b)
		buttons[action] = b
	intro = make_modal(root)
	var intro_col := VBoxContainer.new()
	intro_col.add_theme_constant_override("separation", 14)
	intro.add_child(intro_col)
	intro_col.add_child(label("CHICKEN VALLEY", 36))
	intro_col.add_child(label("Mobile farm rivalry • v0.2", 22))
	intro_col.add_child(label("Watch both farms from above.\nSell meat for cash or keep chickens for eggs.\nExpand land; upgrade fences and hire dogs.\nLaunch raiders to steal chickens from your rival.\nMost chickens after 4 minutes wins.", 20))
	var start := Button.new()
	start.text = "Start match vs AI"
	start.custom_minimum_size = Vector2(0, 60)
	start.pressed.connect(func(): intro.hide(); paused = false; update_ui())
	intro_col.add_child(start)
	result_panel = make_modal(root)
	var result_col := VBoxContainer.new()
	result_col.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_col)
	result_label = label("", 30)
	result_col.add_child(result_label)
	var restart := Button.new()
	restart.text = "Play again"
	restart.custom_minimum_size = Vector2(0, 60)
	restart.pressed.connect(func():
		game = FarmMatch.new()
		build_routes()
		sync_raiders()
		action_panel.show()
		farm_button.text = "Hide actions"
		paused = false
		pause_button.text = "Pause"
		result_panel.hide()
		sync_farms()
		update_ui())
	result_col.add_child(restart)
	result_panel.hide()

func make_modal(root: Control) -> PanelContainer:
	var p := PanelContainer.new()
	root.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -280
	p.offset_right = 280
	p.offset_top = -205
	p.offset_bottom = 155
	p.add_theme_stylebox_override("panel", panel_style())
	return p

func update_ui() -> void:
	var f := game.farms[0]
	var e := game.farms[1]
	stats.text = "YOU • %d coins\n%d/%d chickens • +%.1f eggs/s\nLand %d • Fence %d • Dogs %d • Block %d" % [f.coins, f.chickens, game.capacity(0), f.chickens * FarmMatch.EGG_INCOME, f.land + 1, f.fence, f.dogs, game.defense(0)]
	enemy_stats.text = "RIVAL • %d chickens\nFence %d • Dogs %d" % [e.chickens, e.fence, e.dogs]
	farm_button.disabled = paused or game.finished
	var seconds := ceili(game.remaining)
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	notice_label.text = "Match paused" if paused and not intro.visible else game.notice
	var names := {"chicken": "Buy chicken", "coop": "Build coop", "fence": "Upgrade fence", "boots": "Raider boots", "raid": "LAUNCH RAID", "sell": "Sell for meat", "expand": "Expand farm", "dog": "Guard dog"}
	for action in buttons:
		var detail := "%d coins" % game.cost(0, action)
		if action == "raid" and f.cooldown > 0: detail = "Ready in %ds" % ceili(f.cooldown)
		if action == "coop" and f.coops >= 2 + f.land * 2: detail = "Expand land first"
		if action == "expand" and f.land == 2: detail = "Max land"
		if action == "dog" and f.dogs == 6: detail = "Max dogs"
		if action == "sell": detail = "+%d coins; -0.65 eggs/s" % FarmMatch.MEAT_PRICE
		if action == "fence": detail += " • L%d" % f.fence
		if action == "dog": detail += " • %d guarding" % f.dogs
		if action == "fence" and f.fence == 3: detail = "Max level"
		if action == "boots" and f.boots == 3: detail = "Max level"
		if action == "chicken" and f.chickens >= game.capacity(0): detail = "Build a coop first"
		buttons[action].text = names[action] + "\n" + detail
		buttons[action].disabled = paused or not game.available(0, action)
	if game.finished:
		result_label.text = "%s\n\nYour flock: %d\nRival flock: %d" % [game.notice, f.chickens, e.chickens]
		result_panel.show()

func sync_raiders() -> void:
	var active: Array[int] = []
	for r in game.raids:
		active.append(r.id)
		if not raider_nodes.has(r.id):
			var runner := Node3D.new()
			add_child(runner)
			if r.kind == "coyote": animal(runner, Color("a8a092"))
			if r.kind == "raider":
				box(runner, Vector3(0, 0.8, 0), Vector3(0.6, 0.9, 0.5), Color("247aaf") if r.side == 0 else Color("d45745"))
				sphere(runner, Vector3(0, 1.55, 0), Vector3(0.5, 0.5, 0.5), Color("f1c797"))
				box(runner, Vector3(0, 1.8, 0), Vector3(0.85, 0.14, 0.7), Color("d6b275"))
			var badge := Label3D.new()
			badge.name = "Badge"
			badge.position.y = 2.5
			badge.font_size = 40
			badge.pixel_size = 0.012
			badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			runner.add_child(badge)
			raider_nodes[r.id] = runner
		var runner: Node3D = raider_nodes[r.id]
		runner.position = route_position(r) + Vector3(0, absf(sin(clock * 12)) * 0.16, 0)
		runner.get_node("Badge").text = "FENCE: %ds" % ceili(r.duration - r.elapsed) if r.at_gate else ("%d stolen" % r.loot if r.leg == 1 else ("COYOTE" if r.kind == "coyote" else "RAID %.0fs" % (r.duration - r.elapsed)))
	for id in raider_nodes.keys():
		if id not in active:
			raider_nodes[id].queue_free()
			raider_nodes.erase(id)

func _process(delta: float) -> void:
	if not paused:
		clock += delta
		game.tick(delta)
		for flock in birds:
			for i in flock.get_child_count():
				var c: Node3D = flock.get_child(i)
				c.rotation.y = sin(clock * 0.7 + i * 1.7) * 0.65
				c.position.y = absf(sin(clock * 3 + i)) * 0.05
		sync_raiders()
		for side in 2:
			for child in buildings[side].get_children():
				if not child.has_meta("guard_side"): continue
				var progress := fmod(clock * 0.08 + float(child.get_meta("guard_index")) * 4.0 / maxf(1, game.farms[side].dogs), 4.0)
				var radius := game.farm_radius(side) - 0.5
				var corners: Array[Vector3] = [Vector3(-radius, 0, -radius), Vector3(radius, 0, -radius), Vector3(radius, 0, radius), Vector3(-radius, 0, radius)]
				var edge := int(progress)
				var direction := corners[(edge + 1) % 4] - corners[edge]
				child.position = Vector3(game.farm_center(side), 0, 0) + corners[edge].lerp(corners[(edge + 1) % 4], progress - edge)
				child.rotation.y = atan2(direction.x, direction.z)
	refresh -= delta
	if refresh <= 0:
		refresh = 0.15
		sync_farms()
		update_ui()
	if preview_mode:
		preview_frames += 1
		if preview_frames == 90:
			var picture := get_viewport().get_texture().get_image()
			DirAccess.make_dir_recursive_absolute("res://builds")
			picture.save_png("res://builds/mobile-preview.png")
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		paused = true
		if is_instance_valid(pause_button): pause_button.text = "Resume"

