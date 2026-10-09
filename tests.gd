extends SceneTree
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func arrive(g: FarmMatch) -> void:
	g.tick(g.raids[0].duration + 0.001, false, false)

func _init() -> void:
	var g := FarmMatch.new(10)
	g.tick(1, false, false)
	check(is_equal_approx(g.farms[0].coins, 75.2), "Egg income accrues")
	check(g.buy(0, "chicken"), "Chicken can be bought")
	var coins: float = g.farms[0].coins
	check(g.buy(0, "sell") and g.farms[0].chickens == 8, "Meat sale removes one chicken")
	check(is_equal_approx(g.farms[0].coins, coins + FarmMatch.MEAT_PRICE), "Meat pays lump sum")
	coins = g.farms[0].coins
	g.tick(1, false, false)
	check(is_equal_approx(g.farms[0].coins-coins, 8 * FarmMatch.EGG_INCOME), "Sold chicken no longer earns eggs")
	g.farms[0].chickens = 0
	check(not g.buy(0, "sell"), "Empty flock cannot be sold")
	g.farms[0].coins = 2000
	g.farms[0].chickens = 12
	check(not g.buy(0, "chicken"), "Coop capacity enforced")
	check(g.buy(0, "coop") and g.capacity(0) == 24, "Coop increases capacity")
	check(not g.buy(0, "coop"), "More coops need land")
	g.farms[0].fence = 2
	var block := g.defense(0)
	check(g.buy(0, "expand") and g.farm_radius(0) == 8, "Expansion enlarges footprint")
	check(g.defense(0) < block, "Expansion spreads existing defenses thinner")
	check(g.buy(0, "coop"), "Expansion unlocks coop plots")
	check(g.buy(0, "dog") and g.defense(0) > 3, "Dogs restore guard coverage")
	check(not g.buy(0, "invalid"), "Unknown purchase rejected")
	g = FarmMatch.new(10)
	check(g.buy(0, "raid"), "Raid launches")
	check(not g.buy(0, "raid"), "Raid cooldown enforced")
	check(g.raids[0].duration > 9, "Wider battlefield increases travel")
	arrive(g)
	check(g.farms[1].chickens == 8 and g.raids[0].at_gate, "Attack waits for gate phase")
	arrive(g)
	check(g.farms[1].chickens == 4 and g.farms[0].chickens == 8, "Theft happens at target")
	arrive(g)
	check(g.farms[0].chickens == 12 and g.raids.is_empty(), "Loot returns home")
	g = FarmMatch.new(10)
	g.farms[1].fence = 3
	g.buy(0, "raid")
	arrive(g)
	check(is_equal_approx(g.raids[0].duration, 6), "Fence upgrades delay attackers")
	g.tick(5, false, false)
	check(g.farms[1].chickens == 8 and g.raids[0].at_gate, "Raider visibly waits at fence")
	g.tick(1.01, false, false)
	check(g.raids[0].loot == 0, "Strong fence stops basic theft")
	g = FarmMatch.new(10)
	g.farms[1].dogs = 2
	g.buy(0, "raid")
	arrive(g)
	arrive(g)
	check(g.raids[0].loot == 0, "Dogs stop raiders")
	g = FarmMatch.new(10)
	g.spawn_coyote(0)
	g.tick(6.2, false, false)
	check(g.farms[0].chickens == 5 and g.raids.is_empty(), "Unguarded coyote takes chickens")
	g = FarmMatch.new(10)
	g.farms[0].dogs = 2
	g.spawn_coyote(0)
	g.tick(6.2, false, false)
	check(g.farms[0].chickens == 8, "Dogs stop coyote losses")
	g = FarmMatch.new(10)
	g.buy(0, "raid")
	arrive(g)
	arrive(g)
	g.farms[0].chickens = 11
	arrive(g)
	check(g.farms[0].chickens == 12 and g.farms[1].chickens == 7, "Excess loot returned")
	g = FarmMatch.new(10)
	g.buy(0, "raid")
	arrive(g)
	arrive(g)
	g.remaining = 1
	g.tick(1, false, false)
	check(g.finished and g.winner == -1, "In-transit chickens returned before scoring")
	check(not g.buy(0, "sell"), "Finished matches reject sales")
	g = FarmMatch.new(10)
	g.routes[0].terrain = 0
	g.launch_raid(0, 0)
	var fast: float = g.raids[0].duration
	g.routes[0].terrain = 2
	g.launch_raid(0, 0)
	check(g.raids[1].duration > fast, "Mud slows same route")
	var first: Vector3 = g.raids[0].points[0]
	g.launch_raid(1, 0)
	check(g.raids[2].points[-1] == first, "Rival follows route in reverse")
	var copy := FarmMatch.new(10)
	check(copy.routes[0].points == g.routes[0].points, "Seed reproduces map")
	check(FarmMatch.new(11).routes[0].points != copy.routes[0].points, "Other seeds change obstacles and detours")
	for seed_value in 5:
		g = FarmMatch.new(seed_value)
		for i in 2401:
			g.tick(0.1)
			for side in 2:
				check(g.farms[side].coins >= 0 and g.farms[side].chickens >= 0 and g.farms[side].chickens <= g.capacity(side), "Simulation resource bounds")
		check(g.finished and g.raids.is_empty(), "AI match with wildlife finishes")
	print("Farm match tests: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
