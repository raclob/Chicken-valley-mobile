class_name FarmMatch
extends RefCounted

const MATCH_SECONDS := 240.0
const EGG_INCOME := 0.65
const MEAT_PRICE := 14
const FARM_X := 22.0
var farms: Array[Dictionary] = []
var raids: Array[Dictionary] = []
var routes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var remaining := MATCH_SECONDS
var ai_timer := 5.0
var wildlife_timer := 40.0
var finished := false
var winner := -1
var notice := "Expand wisely: more land needs more guards. Most chickens after 4 minutes wins."
var next_id := 0

func _init(map_seed: int = -1) -> void:
	if map_seed < 0: rng.randomize()
	else: rng.seed = map_seed
	for i in 2:
		farms.append({"coins": 70.0, "chickens": 8, "coops": 1, "fence": 0, "boots": 0, "dogs": 0, "land": 0, "cooldown": 0.0})
	for i in 3:
		var z := float(i - 1) * 6.0
		var detour := rng.randf_range(2.0, 4.5)
		var points: Array[Vector3] = [Vector3(-12, 0, z), Vector3(-6, 0, z + detour), Vector3(6, 0, z + detour), Vector3(12, 0, z)]
		routes.append({"points": points, "obstacle": Vector3(0, 0, z), "terrain": rng.randi_range(0, 2)})

func farm_center(side: int) -> float:
	return -FARM_X if side == 0 else FARM_X

func farm_radius(side: int) -> float:
	return 6.0 + farms[side].land * 2.0

func defense(side: int) -> int:
	var f := farms[side]
	return ceili(float(f.fence * 2 + f.dogs * 2) / (1.0 + f.land * 0.5))

func cost(side: int, action: String) -> int:
	var f := farms[side]
	match action:
		"chicken": return 20
		"coop": return 65 + (f.coops - 1) * 30
		"fence": return 45 + f.fence * 35
		"boots": return 55 + f.boots * 40
		"raid": return 30
		"expand": return 100 + f.land * 75
		"dog": return 60 + f.dogs * 25
	return 0

func capacity(side: int) -> int:
	return farms[side].coops * 12

func available(side: int, action: String) -> bool:
	if finished or side < 0 or side > 1: return false
	var f := farms[side]
	if f.coins < cost(side, action): return false
	match action:
		"chicken": return f.chickens < capacity(side)
		"sell": return f.chickens > 0
		"coop": return f.coops < 2 + f.land * 2
		"fence": return f.fence < 3
		"boots": return f.boots < 3
		"expand": return f.land < 2
		"dog": return f.dogs < 6
		"raid": return f.cooldown <= 0 and f.chickens < capacity(side) and farms[1-side].chickens > 0
	return false

func buy(side: int, action: String) -> bool:
	if not available(side, action): return false
	var f := farms[side]
	f.coins -= cost(side, action)
	match action:
		"chicken": f.chickens += 1
		"sell":
			f.chickens -= 1
			f.coins += MEAT_PRICE
			if side == 0: notice = "Sold one chicken for %d coins. Egg income decreased by 0.65/s." % MEAT_PRICE
		"coop": f.coops += 1
		"fence":
			f.fence += 1
			if side == 0: notice = "Fence upgraded: gate delay %ds; guards block up to %d chickens." % [f.fence * 2, defense(side)]
		"boots": f.boots += 1
		"expand":
			f.land += 1
			if side == 0: notice = "Farm expanded! Two more coop plots. Larger perimeter needs more dogs."
		"dog":
			f.dogs += 1
			if side == 0: notice = "Guard dog hired! Guards block up to %d chickens per attack." % defense(side)
		"raid":
			f.cooldown = 14.0
			launch_raid(side, rng.randi_range(0, routes.size() - 1))
	return true

func launch_raid(side: int, route_index: int) -> void:
	var route := routes[route_index]
	var points: Array[Vector3] = []
	points.append(Vector3(farm_center(0) + farm_radius(0), 0, 0))
	points.append_array(route.points)
	points.append(Vector3(farm_center(1) - farm_radius(1), 0, 0))
	if side == 1: points.reverse()
	var length := 0.0
	for i in range(1, points.size()): length += points[i-1].distance_to(points[i])
	var speed: float = (2.4 + farms[side].boots * 0.45) * [1.25, 1.0, 0.7][route.terrain]
	var duration: float = length / speed
	raids.append({"id": next_id, "side": side, "target": 1-side, "elapsed": 0.0, "leg": 0, "loot": 0, "duration": duration, "travel_duration": duration, "power": 4 + farms[side].boots, "points": points, "kind": "raider", "at_gate": false})
	next_id += 1
	if side == 0: notice = "Raider using %s route: %.1fs each way." % [["fast path", "trail", "muddy trail"][route.terrain], duration]

func spawn_coyote(side: int) -> void:
	var x := farm_center(side)
	var points: Array[Vector3] = [Vector3(x, 0, -16), Vector3(x, 0, -farm_radius(side))]
	raids.append({"id": next_id, "side": 1-side, "target": side, "elapsed": 0.0, "leg": 0, "loot": 0, "duration": 6.0, "travel_duration": 6.0, "power": 3, "points": points, "kind": "coyote", "at_gate": false})
	next_id += 1
	notice = "Coyote approaching %s farm! Fences and dogs protect chickens." % ("your" if side == 0 else "the rival")

func tick(delta: float, run_ai: bool = true, run_wildlife: bool = true) -> void:
	if finished or delta <= 0: return
	var step := minf(delta, remaining)
	remaining = maxf(0.0, remaining - step)
	for f in farms:
		f.coins += f.chickens * EGG_INCOME * step
		f.cooldown = maxf(0.0, f.cooldown - step)
	for index in range(raids.size()-1, -1, -1):
		var r := raids[index]
		r.elapsed += step
		while r.elapsed >= r.duration:
			r.elapsed -= r.duration
			if r.leg == 0 and not r.at_gate:
				r.at_gate = true
				r.duration = maxf(0.1, farms[r.target].fence * 2.0)
				if farms[r.target].fence > 0: notice = "%s stopped at the fence for %ds." % [r.kind.capitalize(), farms[r.target].fence * 2]
			elif r.leg == 0:
				var enemy := farms[r.target]
				r.loot = mini(enemy.chickens, maxi(0, r.power - defense(r.target)))
				enemy.chickens -= r.loot
				notice = "%s: %d chickens lost, %d blocked by fence/dogs." % ["Your farm" if r.target == 0 else "Rival farm", r.loot, mini(r.power, defense(r.target))]
				if r.kind == "coyote":
					raids.remove_at(index)
					break
				r.leg = 1
				r.at_gate = false
				r.duration = r.travel_duration
			else:
				var home := farms[r.side]
				var delivered := mini(r.loot, maxi(0, capacity(r.side) - home.chickens))
				home.chickens += delivered
				farms[r.target].chickens += r.loot - delivered
				raids.remove_at(index)
				break
	if run_ai:
		ai_timer -= step
		if ai_timer <= 0:
			ai_timer = 4.5
			ai_turn()
	if run_wildlife:
		wildlife_timer -= step
		if wildlife_timer <= 0 and remaining > 8:
			wildlife_timer = rng.randf_range(35, 55)
			spawn_coyote(rng.randi_range(0, 1))
	if remaining < 0.001:
		remaining = 0.0
		for r in raids:
			if r.leg == 1: farms[r.target].chickens += r.loot
		raids.clear()
		finished = true
		winner = -1 if farms[0].chickens == farms[1].chickens else (0 if farms[0].chickens > farms[1].chickens else 1)
		notice = "Draw!" if winner == -1 else ("Your farm wins!" if winner == 0 else "Rival farm wins!")

func ai_turn() -> void:
	var f := farms[1]
	for r in raids:
		if r.target == 1 and r.leg == 0:
			if f.fence < 2 and buy(1, "fence"): return
			if f.dogs < 2 + f.land and buy(1, "dog"): return
	if f.chickens >= capacity(1) - 2:
		if buy(1, "coop"): return
		if buy(1, "expand"): return
	if defense(0) < 4 + f.boots and buy(1, "raid"): return
	if buy(1, "chicken"): return
	if buy(1, "dog"): return
	if buy(1, "boots"): return
	buy(1, "fence")
