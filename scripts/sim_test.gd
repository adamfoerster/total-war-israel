extends RefCounted
## Teste headless: godot --headless --path . -- --simtest

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")
const TerrainData = preload("res://scripts/terrain_data.gd")
const BattleSim = preload("res://scripts/battle_sim.gd")
const AI = preload("res://scripts/ai_commander.gd")

var fails := 0
var cats := {}
var rout_bad := 0

func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + what)
	if not cond:
		fails += 1

func new_sim(terrain) -> BattleSim:
	var s := BattleSim.new()
	s.init(terrain)
	return s

func run() -> int:
	# semente aleatória impressa; "--seed N" repete uma rodada exata
	var sd := randi()
	var args := OS.get_cmdline_user_args()
	var k := args.find("--seed")
	if k >= 0 and k + 1 < args.size():
		sd = int(args[k + 1])
	seed(sd)
	print("semente: ", sd)
	var terrain := TerrainData.new()
	terrain.load_map()
	print("terreno real: ", terrain.real_data, "  alt base ", terrain.base_alt, "  relevo ", terrain.hmax)
	check(terrain.real_data, "heightmap real de Jerusalém carregado")
	if not "--so-batalha" in args:
		_test_fatigue(terrain)
		_test_height(terrain)
		_test_general(terrain)
		_test_clamp(terrain)
		_test_reform(terrain)
		_test_rally(terrain)
		_test_deaths(terrain)
		_test_daylight()
		_test_detour(terrain)
		_test_stance(terrain)
		_test_squeeze(terrain)
		_test_rout_credit(terrain)
		_test_surrender(terrain)
		_test_slope_limits(terrain)
	seed(sd)   # a batalha depende só da semente, com ou sem os testes anteriores
	_test_battle(terrain)
	print("FALHAS: ", fails)
	return fails

func _steepest(terrain, lo: float, hi: float) -> Vector2:
	# procura um ponto da área controlável com declive na faixa pedida
	for j in range(90, 310, 3):
		for i in range(90, 310, 3):
			var s: float = terrain.slope[j * Cfg.HM_N + i]
			if s > lo and s < hi:
				return Vector2((i - 200) * 10.0, (j - 200) * 10.0)
	return Vector2.ZERO

func _test_fatigue(terrain) -> void:
	print("[cansaço na subida]")
	var p := _steepest(terrain, 14.0, 20.0)
	var g: Vector2 = terrain.grad_at(p).normalized()
	var res := []
	for mode in 3:   # 0 corre subindo, 1 anda subindo, 2 corre em nível
		var s := new_sim(terrain)
		var u := s.add_unit(0, Cfg.LIGHT, 100, false)
		var dir := g if mode < 2 else Vector2(-g.y, g.x)
		s.place_unit(u, p - dir * 40.0, dir)
		s.finalize()
		s.order_move(u, p + dir * 40.0, Vector2.ZERO, mode != 1)
		for k in 150:
			s.tick(Cfg.TICK)
			if u.path.is_empty():
				break
		res.append(u.fatigue)
	print("  correr subindo=%.1f  andar subindo=%.1f  correr em nível=%.1f" % res)
	check(res[0] > res[2] * 1.3, "correr na subida cansa mais que correr em nível")
	check(res[0] > res[1], "correr na subida cansa mais que andar na subida")

func _test_height(terrain) -> void:
	print("[vantagem de altura]")
	var p := _steepest(terrain, 9.0, 11.5)
	var g: Vector2 = terrain.grad_at(p).normalized()
	var wins := 0
	for trial in 5:
		var s := new_sim(terrain)
		var hi := s.add_unit(0, Cfg.HEAVY, 200, false)
		var lo := s.add_unit(1, Cfg.HEAVY, 200, false)
		hi.label = "alto"
		lo.label = "baixo"
		s.place_unit(hi, p + g * 14.0, -g)
		s.place_unit(lo, p - g * 14.0, g)
		s.finalize()
		s.order_attack(lo, hi, false)
		s.order_attack(hi, lo, false)
		for k in 6000:
			s.tick(Cfg.TICK)
			if s.winner >= 0:
				break
		if s.winner == 0:
			wins += 1
		if trial == 0:
			print("  mod altura: alto=%.2f baixo=%.2f (último valor)" % [hi.height_mod, lo.height_mod])
	print("  unidade no alto venceu %d de 5 duelos espelhados" % wins)
	check(wins >= 4, "unidade em terreno superior vence duelo espelhado")

func _test_general(terrain) -> void:
	print("[general]")
	var s := new_sim(terrain)
	var a := s.add_unit(0, Cfg.HEAVY, 100, true)
	var b := s.add_unit(0, Cfg.LIGHT, 100, false)
	s.add_unit(1, Cfg.HEAVY, 100, false)
	s.place_unit(a, Vector2(-300, 0), Vector2(0, -1))
	s.place_unit(b, Vector2(-200, 0), Vector2(0, -1))
	s.place_unit(s.units[2], Vector2(-300, -900), Vector2(0, 1))
	s.finalize()
	var m0 := b.morale
	while a.general_alive and a.n > 0:
		s.kill_model(a, a.start)
	check(b.morale <= m0 - Cfg.GENERAL_DEAD_LOSS + 9.0, "morte do general derruba a moral (%.0f -> %.0f)" % [m0, b.morale])
	var s2 := new_sim(terrain)
	var c := s2.add_unit(0, Cfg.HEAVY, 100, false)
	var d := s2.add_unit(0, Cfg.LIGHT, 100, false)
	s2.add_unit(1, Cfg.HEAVY, 100, false)
	s2.place_unit(c, Vector2(-300, 0), Vector2(0, -1))
	s2.place_unit(d, Vector2(-200, 0), Vector2(0, -1))
	s2.place_unit(s2.units[2], Vector2(-300, -900), Vector2(0, 1))
	s2.finalize()
	var m1 := d.morale
	s2._start_rout(c)
	check(d.morale < m1, "ver aliado fugir reduz a moral (%.0f -> %.0f)" % [m1, d.morale])
	check(c.state == 1, "unidade em pânico sai do controle")
	for k in 6000:
		s2.tick(Cfg.TICK)
		if c.state == 2:
			break
	check(c.state == 2 and s2.fled[0] == 100 and absf(c.center.x) + absf(c.center.y) > Cfg.CONTROL_HALF, "fugitivos saem do mapa (%d saíram)" % s2.fled[0])

func _test_reform(terrain) -> void:
	print("[mudança de largura da formação]")
	var s := new_sim(terrain)
	var u := s.add_unit(0, Cfg.HEAVY, 300, false)
	s.place_unit(u, Vector2(-900, -900), Vector2(0, -1))
	s.finalize()
	var n0 := u.n
	s.order_reform(u, 3)
	check(u.files == mini(Cfg.MIN_LINE_FILES, n0), "largura mínima de %d soldados é respeitada (files=%d)" % [Cfg.MIN_LINE_FILES, u.files])
	s.order_reform(u, 40)
	check(u.files == 40 and u.rows0 == (n0 + 39) / 40, "largura 40 aplicada (files=%d, fileiras=%d)" % [u.files, u.rows0])
	var sum := 0
	for d in u.depth:
		sum += d
	check(sum == n0 and u.depth.size() == 40, "fileiras somam todos os soldados")
	for k in 400:
		s.tick(Cfg.TICK)
	var ok := true
	for i in range(u.start, u.start + u.n):
		if s.pos[i].distance_to(u.center) > 60.0:
			ok = false
	check(ok and u.n == n0, "soldados se reagrupam no novo posto sem se perder")

func _test_rally(terrain) -> void:
	print("[general reúne as tropas]")
	var s := new_sim(terrain)
	var g := s.add_unit(0, Cfg.HEAVY, 200, true)
	var near := s.add_unit(0, Cfg.LIGHT, 100, false)
	var far := s.add_unit(0, Cfg.LIGHT, 100, false)
	var enemy := s.add_unit(1, Cfg.HEAVY, 100, false)
	s.place_unit(g, Vector2(-900, -900), Vector2(0, -1))
	s.place_unit(near, Vector2(-800, -900), Vector2(0, -1))
	s.place_unit(far, Vector2(-100, -900), Vector2(0, -1))
	s.place_unit(enemy, Vector2(900, 900), Vector2(0, 1))
	s.finalize()
	near.morale = 20.0
	far.morale = 20.0
	s._start_rout(near)
	check(near.state == 1, "unidade próxima entrou em fuga")
	check(s.events.size() == 1 and s.events[0][0] == "rout", "pânico gera evento")
	check(s.rally(g), "general consegue reunir")
	check(near.state == 0 and near.morale > Cfg.ROUT_MORALE, "unidade próxima para de fugir com moral acima do limite de pânico")
	check(far.morale > 20.0 and far.morale < 20.0 + Cfg.RALLY_NEAR_GAIN, "unidade distante ganha pouca moral")
	check(not s.rally(g), "reunir fica em espera")
	for k in int(Cfg.RALLY_COOLDOWN / Cfg.TICK) + 5:
		s.tick(Cfg.TICK)
	check(near.state == 0 and near.n > 0, "unidade reunida continua sob controle")
	check(s.rally(g), "reunir disponível de novo após um minuto")

func _test_deaths(terrain) -> void:
	print("[registro de mortes para os corpos]")
	var s := new_sim(terrain)
	var u := s.add_unit(0, Cfg.CHARIOT, 20, false)
	s.place_unit(u, Vector2(-900, -900), Vector2(0, -1))
	s.finalize()
	var n0 := u.n
	s.kill_model(u, u.start)
	check(s.death_pos.is_empty(), "sem gravação ligada, nada é registrado")
	s.record_deaths = true
	var p: Vector2 = s.pos[u.start + 3]
	s.kill_model(u, u.start + 3)
	check(s.death_pos.size() == 1 and s.death_key[0] == Cfg.CHARIOT and s.death_pos[0].is_equal_approx(p), "morte registra posição e tipo")
	check(u.n == n0 - 2, "o morto sai da simulação")

func _test_daylight() -> void:
	print("[sol]")
	var D = load("res://scripts/daylight.gd")
	var am: Dictionary = D.at(8.0)
	var noon: Dictionary = D.at(12.0)
	var pm: Dictionary = D.at(16.0)
	check((noon.to_sun as Vector3).y > (am.to_sun as Vector3).y, "sol mais alto ao meio-dia que às 8h")
	check((am.to_sun as Vector3).x > 0.3 and (pm.to_sun as Vector3).x < -0.3, "sol a leste de manhã e a oeste à tarde")
	check((noon.to_sun as Vector3).z > 0.0, "ao meio-dia o sol está ao sul (z positivo)")
	check(absf((noon.to_sun as Vector3).length() - 1.0) < 0.001, "direção do sol normalizada")
	check(D.at(6.0).alt >= Cfg.SUN_MIN_ALT - 0.01, "altura mínima respeitada")
	check((noon.sun_color as Color).b > (am.sun_color as Color).b, "luz mais quente de manhã")

func _test_detour(terrain) -> void:
	print("[caminho ignora outras unidades]")
	var s := new_sim(terrain)
	var a := s.add_unit(0, Cfg.LIGHT, 100, false)
	var b := s.add_unit(0, Cfg.HEAVY, 200, false)
	s.place_unit(a, Vector2(-900, -900), Vector2(1, 0))
	s.place_unit(b, Vector2(-700, -900), Vector2(1, 0))
	s.finalize()
	s.order_move(a, Vector2(-500, -900), Vector2(1, 0), false)
	check(a.path.size() == 1, "em terreno livre o caminho é a reta, mesmo com unidade no meio")
	var reached := false
	for k in 4000:
		s.tick(Cfg.TICK)
		if a.path.is_empty():
			reached = true
			break
	check(reached, "chega ao destino passando pela outra unidade")
	check(a.center.distance_to(Vector2(-500, -900)) < 40.0, "chega perto do destino")

func _test_stance(terrain) -> void:
	print("[postura]")
	var r := {}
	for st in 3:
		var s := new_sim(terrain)
		var u := s.add_unit(0, Cfg.HEAVY, 100, false)
		var near := s.add_unit(1, Cfg.LIGHT, 100, false)
		s.place_unit(u, Vector2(-900, -900), Vector2(1, 0))
		s.place_unit(near, Vector2(-830, -900), Vector2(-1, 0))
		s.finalize()
		u.stance = st
		var gap := u.center.distance_to(near.center) - u.brad - near.brad
		for k in 6:   # a postura é avaliada com a moral, a cada 5 ticks
			s.tick(Cfg.TICK)
		r[st] = [u.target != null, gap]
		if st != Cfg.STANCE_DEFENSIVE:
			s._start_rout(near)
			for k in 6:
				s.tick(Cfg.TICK)
			r[st].append(u.target != null)
	check(Cfg.STANCE_NEUTRAL == Unit.new().stance, "postura padrão é a neutra")
	check(float(r[1][1]) < Cfg.STANCE_ENGAGE, "inimigo de teste fica a menos de 50 m (%.0f m)" % r[1][1])
	check(not r[0][0], "defensiva não ataca sozinha")
	check(r[1][0] and r[2][0], "neutra e agressiva atacam o inimigo próximo")
	check(not r[1][2], "neutra não persegue quem foge")
	check(r[2][2], "agressiva persegue quem foge")
	var s2 := new_sim(terrain)
	var a := s2.add_unit(0, Cfg.HEAVY, 100, false)
	var far := s2.add_unit(1, Cfg.LIGHT, 100, false)
	s2.place_unit(a, Vector2(-900, -900), Vector2(1, 0))
	s2.place_unit(far, Vector2(-600, -900), Vector2(-1, 0))
	s2.finalize()
	for k in 6:
		s2.tick(Cfg.TICK)
	check(a.target == null, "neutra ignora inimigo a mais de 50 m")

func _test_rout_credit(terrain) -> void:
	print("[moral para quem pôs o inimigo em pânico]")
	var s := new_sim(terrain)
	var foe := s.add_unit(1, Cfg.LIGHT, 100, false)
	var melee := s.add_unit(0, Cfg.HEAVY, 100, false)
	var archer := s.add_unit(0, Cfg.ARCHER, 100, false)
	var walker := s.add_unit(0, Cfg.LIGHT, 100, false)
	var old := s.add_unit(0, Cfg.LIGHT, 100, false)
	var foe2 := s.add_unit(1, Cfg.LIGHT, 100, false)
	s.place_unit(foe2, Vector2(-500, -900), Vector2(0, 1))
	s.place_unit(foe, Vector2(-900, -900), Vector2(0, 1))
	s.place_unit(melee, Vector2(-900, -870), Vector2(0, -1))
	s.place_unit(archer, Vector2(-900, -700), Vector2(0, -1))
	s.place_unit(walker, Vector2(-800, -800), Vector2(0, -1))
	s.place_unit(old, Vector2(-1000, -800), Vector2(0, -1))
	s.finalize()
	# golpe corpo a corpo e disparo que cai no alvo registram o atacante
	s._attack(melee, foe.start)
	s.volleys.append([s.time, foe, 0.0, archer])
	s._update_volleys()
	check(foe.attacked_by.has(melee.id) and foe.attacked_by.has(archer.id), "golpe e disparo registram o atacante")
	s.order_attack(walker, foe, false)
	foe.attacked_by[old.id] = s.time - Cfg.ROUT_CREDIT_WINDOW - 1.0
	for u: Unit in [melee, archer, walker, old]:
		u.morale = 30.0
	s._start_rout(foe)
	var after := 30.0 + Cfg.ROUT_CREDIT_GAIN
	# _start_rout também tira SEE_ROUT_LOSS das unidades do lado de foe, não destas
	check(is_equal_approx(melee.morale, after), "quem golpeava ganha moral (%.1f)" % melee.morale)
	check(is_equal_approx(archer.morale, after), "quem acertava disparos ganha moral (%.1f)" % archer.morale)
	check(is_equal_approx(walker.morale, 30.0), "quem só marchava até o alvo não ganha (%.1f)" % walker.morale)
	check(is_equal_approx(old.morale, 30.0), "ataque antigo demais não conta (%.1f)" % old.morale)
	melee.morale = melee.morale_base - 2.0
	foe2.attacked_by[melee.id] = s.time
	s._start_rout(foe2)
	check(melee.morale <= melee.morale_base + 0.001, "o ganho respeita o teto de moral")

func _test_slope_limits(terrain) -> void:
	print("[declives máximos ajustáveis]")
	var solid := func(g: AStarGrid2D) -> int:
		var c := 0
		for z in Cfg.NAV_N:
			for x in Cfg.NAV_N:
				if g.is_point_solid(Vector2i(x, z)):
					c += 1
		return c
	var foot0: int = solid.call(terrain.nav_foot)
	var car0: int = solid.call(terrain.nav_car)
	terrain.set_limits(Cfg.SLOPE_IMPASS + 15.0, Cfg.SLOPE_CHARIOT + 10.0)
	var foot1: int = solid.call(terrain.nav_foot)
	var car1: int = solid.call(terrain.nav_car)
	check(foot1 < foot0 and car1 < car0, "limites maiores liberam terreno (a pé %d -> %d, carros %d -> %d)" % [foot0, foot1, car0, car1])
	check(terrain.limit(true) == Cfg.SLOPE_CHARIOT + 10.0 and terrain.limit(false) == Cfg.SLOPE_IMPASS + 15.0, "limit() devolve os novos valores")
	terrain.set_limits(Cfg.SLOPE_IMPASS, Cfg.SLOPE_CHARIOT)
	check(solid.call(terrain.nav_foot) == foot0 and solid.call(terrain.nav_car) == car0, "voltar aos limites padrão refaz as grades iguais")

func _test_surrender(terrain) -> void:
	print("[força e rendição]")
	var s := new_sim(terrain)
	var h := s.add_unit(0, Cfg.HEAVY, 100, true)     # 100 x 2 = 200
	var c := s.add_unit(0, Cfg.CHARIOT, 20, false)   # 10 carros x 4 = 40
	var l := s.add_unit(1, Cfg.LIGHT, 100, true)     # 100 x 1 = 100
	s.place_unit(h, Vector2(-900, 600), Vector2(0, -1))
	s.place_unit(c, Vector2(-700, 600), Vector2(0, -1))
	s.place_unit(l, Vector2(-900, -600), Vector2(0, 1))
	s.finalize()
	check(s.power(0) == 240 and s.power(1) == 100, "força: 2 por pesada, 4 por carro, 1 por leve (%d x %d)" % [s.power(0), s.power(1)])
	var ai1 := AI.new()
	ai1.init(s, 1)
	ai1.update(1.0)
	check(s.winner < 0, "IA com mais de 1/3 da força não se rende")
	for k in 30:
		s.kill_model(l, l.start)
	ai1.update(1.0)
	check(s.winner == 0 and s.surrendered == 1, "IA com menos de 1/3 da força se rende (%d x %d)" % [s.power(0), s.power(1)])
	var s2 := new_sim(terrain)
	var a := s2.add_unit(0, Cfg.LIGHT, 100, true)
	var b := s2.add_unit(1, Cfg.LIGHT, 100, true)
	s2.place_unit(a, Vector2(-900, 600), Vector2(0, -1))
	s2.place_unit(b, Vector2(-900, -600), Vector2(0, 1))
	s2.finalize()
	s2.surrender(0)
	check(s2.winner == 1 and s2.surrendered == 0, "jogador se rende: vitória do inimigo")

func _test_squeeze(terrain) -> void:
	print("[estreitar a frente para passar por um vão]")
	var s := new_sim(terrain)
	var m := s.add_unit(0, Cfg.LIGHT, 100, false)
	s.place_unit(m, Vector2(-900, -900), Vector2(1, 0))
	var sp: float = m.t.spacing
	var gap := 6.5 * sp   # cabem 6 soldados -> frente de 5
	var walls: Array = []
	for j in 6:
		for sgn: float in [-1.0, 1.0]:
			var w := s.add_unit(0, Cfg.HEAVY, 300, false)
			walls.append([w, sgn, j])
	for e: Array in walls:
		var w: Unit = e[0]
		var wh: float = w.files * float(w.t.spacing)
		var z: float = -900.0 + float(e[1]) * (gap * 0.5 + wh * 0.5 + int(e[2]) * wh)
		s.place_unit(w, Vector2(-700, z), Vector2(1, 0))
	s.finalize()
	s.order_reform(m, 20)
	check(m.files == 20, "frente inicial de 20")
	s.order_move(m, Vector2(-500, -900), Vector2(1, 0), false)
	var minf := m.files
	var reached := false
	for k in 6000:
		s.tick(Cfg.TICK)
		minf = mini(minf, m.files)
		if m.path.is_empty() and m.files_want == 0 and k > 100:
			reached = true
			break
	check(minf == 5, "estreita para 5 soldados no vão de 6 (mínimo=%d)" % minf)
	check(reached and m.center.x > -560.0, "passa pelo vão e chega ao destino (x=%.0f)" % m.center.x)
	check(m.files == 20, "volta à frente de 20 depois do vão (files=%d)" % m.files)

func _test_clamp(terrain) -> void:
	print("[limite da área controlável]")
	var s := new_sim(terrain)
	var u := s.add_unit(0, Cfg.LIGHT, 100, false)
	s.place_unit(u, Vector2(-900, -900), Vector2(0, -1))
	s.finalize()
	s.order_move(u, Vector2(-1900, -1900), Vector2.ZERO, true)
	for k in 3000:
		s.tick(Cfg.TICK)
		if u.path.is_empty():
			break
	check(absf(u.center.x) <= Cfg.CONTROL_HALF and absf(u.center.y) <= Cfg.CONTROL_HALF,
		"ordem para fora da área é limitada (parou em %s)" % str(u.center.round()))

func _violations(s: BattleSim) -> Array:
	# [carros em declive proibido, soldados em declive intransponível, controladas fora da área]
	var car := 0
	var imp := 0
	var out := 0
	s.materialize_all()
	for u: Unit in s.units:
		if u.state == 2:
			continue
		if u.state == 0 and (absf(u.center.x) > Cfg.CONTROL_HALF or absf(u.center.y) > Cfg.CONTROL_HALF):
			out += 1
		for i in range(u.start, u.start + u.n):
			var sl: float = terrain_slope(s, s.pos[i])
			if u.type == Cfg.CHARIOT and sl > Cfg.SLOPE_CHARIOT:
				car += 1
			if sl > Cfg.SLOPE_IMPASS:
				imp += 1
	return [car, imp, out]

func terrain_slope(s: BattleSim, p: Vector2) -> float:
	return s.terrain.slope_at(p.x, p.y)

func _overlap_count(s: BattleSim) -> Array:
	# força bruta por células de 2 m; conta pares com sobreposição > 35% e > 15%
	var cells := {}
	s.materialize_all()
	for u: Unit in s.units:
		if u.state == 2:
			continue
		for i in range(u.start, u.start + u.n):
			var p := s.pos[i]
			var key := Vector2i(int(floor(p.x / 3.0)), int(floor(p.y / 3.0)))
			if not cells.has(key):
				cells[key] = PackedInt32Array()
			cells[key].append(i)
	var bad := 0
	var soft := 0
	var total := 0
	for key: Vector2i in cells:
		var a: PackedInt32Array = cells[key]
		for dz in range(0, 2):
			for dx in range(-1, 2):
				if dz == 0 and dx < 0:
					continue
				var k2 := Vector2i(key.x + dx, key.y + dz)
				if not cells.has(k2):
					continue
				var b: PackedInt32Array = cells[k2]
				var same := k2 == key
				for ia in a.size():
					var i := a[ia]
					for ib in range(ia + 1 if same else 0, b.size()):
						var j := b[ib]
						var rr := s.rad[i] + s.rad[j]
						var d := s.pos[i].distance_to(s.pos[j])
						if d < rr * 0.65:
							bad += 1
							var ua: Unit = s.units[s.unit_of[i]]
							var ub: Unit = s.units[s.unit_of[j]]
							if ua.state == 1 and ub.state == 1:
								bad -= 1
								rout_bad += 1
							var key2 := "mesma unidade" if ua == ub else ("aliados" if ua.side == ub.side else "inimigos")
							key2 += " grade=%s/%s estado=%d/%d" % [ua.in_grid, ub.in_grid, ua.state, ub.state]
							cats[key2] = int(cats.get(key2, 0)) + 1
						elif d < rr * 0.85:
							soft += 1
		total += a.size()
	return [bad, soft, total]

func _test_battle(terrain) -> void:
	print("[batalha completa IA x IA, 20 x 20 cards de 300]")
	var s := new_sim(terrain)
	var comp := [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4]
	for side in 2:
		for k in comp.size():
			var u := s.add_unit(side, comp[k], 300, k == 0)
			u.label = "%s %d (%s)" % [u.t.name, k + 1, Cfg.SIDE_NAMES[side]]
	s.deploy_side(0)
	s.deploy_side(1)
	var in_sector := true
	for u: Unit in s.units:
		var zr: Vector2 = s.sector_z(u.side)
		if u.center.y < zr.x or u.center.y > zr.y:
			in_sector = false
	check(in_sector, "posicionamento inicial dentro do setor de cada lado")
	# posicionar fora do setor (no meio do mapa) leva a formação inteira de volta à borda do setor
	var u0: Unit = s.units[0]
	var c0 := u0.center
	s.place_in_sector(u0, Vector2(-450, -300), Vector2(0, -1))
	var front_z := u0.center.y - u0.rows() * float(u0.t.spacing) * 0.5
	check(front_z >= Cfg.SECTOR_HALF - 0.01, "posicionar fora do setor fica na borda do setor (frente z=%.1f)" % front_z)
	s.place_in_sector(u0, c0, Vector2(0, -1))
	s.finalize()
	print("  soldados simulados: ", s.pos.size())
	var ai0 := AI.new()
	ai0.init(s, 0)
	var ai1 := AI.new()
	ai1.init(s, 1)
	var ov0: Array = _overlap_count(s)
	check(ov0[0] == 0, "posicionamento inicial sem unidades sobrepostas (%d pares)" % ov0[0])
	var base := _violations(s)
	check(base[0] == 0 and base[1] == 0, "posicionamento inicial sem soldados em declive proibido %s" % str(base))
	print("  violações iniciais (carro, intransp., fora): ", base)
	var worst_bad := 0
	var worst_soft := 0
	var max_car: int = base[0]
	var max_imp: int = base[1]
	var max_out := 0
	var t_total := 0
	var t_max := 0
	var ticks := 0
	var printed := 0
	while s.winner < 0 and ticks < 30000:
		ai0.update(Cfg.TICK)
		ai1.update(Cfg.TICK)
		var t0 := Time.get_ticks_usec()
		s.tick(Cfg.TICK)
		var dt := Time.get_ticks_usec() - t0
		t_total += dt
		t_max = maxi(t_max, dt)
		ticks += 1
		if ticks % 200 == 0:
			var v := _violations(s)
			max_car = maxi(max_car, v[0])
			max_imp = maxi(max_imp, v[1])
			max_out = maxi(max_out, v[2])
			var o := _overlap_count(s)
			worst_bad = maxi(worst_bad, o[0])
			worst_soft = maxi(worst_soft, o[1])
		if ticks % 1000 == 0 or ticks == 300:
			var nf := 0
			var ng := 0
			var ns := 0
			for u: Unit in s.units:
				nf += 1 if u.formed else 0
				ng += 1 if u.in_grid else 0
				ns += 1 if u.safe else 0
			var nr := 0
			for u: Unit in s.units:
				if u.state == 1:
					nr += u.n
			print("    formadas %d  na grade %d  terreno seguro %d  fugitivos em campo %d" % [nf, ng, ns, nr])
			print("  t=%4ds  Israel %d un/%d h  Filisteus %d un/%d h  tick médio %.1f ms  acordados %d" % [
				int(s.time), s.controlled(0), s.men_alive(0), s.controlled(1), s.men_alive(1),
				t_total / 1000.0 / ticks, s.awake_count])
		while printed < s.messages.size() and printed < 12:
			print("    > ", s.messages[printed][0])
			printed += 1
	print("  fim em t=%ds, vencedor=%s, baixas=%s, fugiram=%s" % [int(s.time),
		Cfg.SIDE_NAMES[s.winner] if s.winner >= 0 else "nenhum", str(s.losses), str(s.fled)])
	if s.winner < 0:
		for u: Unit in s.units:
			if u.state == 0:
				print("    resta: %s tipo=%d n=%d moral=%.0f centro=%s alvo=%s rota=%d contatos=%d ativo=%s munição=%d fadiga=%.0f declive=%.1f" % [u.label, u.type, u.n, u.morale,
					str(u.center.round()), u.target.label if u.target != null else "-", u.path.size(), u.contacts, u.active, u.ammo, u.fatigue,
					s.terrain.slope_at(u.center.x, u.center.y)])
	print("  tick médio %.2f ms, pior %.1f ms" % [t_total / 1000.0 / ticks, t_max / 1000.0])
	print("  sobreposições fortes por categoria: ", cats)
	check(s.winner >= 0, "batalha termina com um vencedor")
	check(max_car <= base[0], "nenhum carro entrou em declive > %.0f graus (max %d, inicial %d)" % [Cfg.SLOPE_CHARIOT, max_car, base[0]])
	check(max_imp <= base[1], "ninguém entrou em declive intransponível (max %d)" % max_imp)
	check(max_out == 0, "unidades controladas ficaram dentro da área controlável")
	check(worst_bad == 0, "nenhum par de soldados sob controle atravessado (sobreposição forte: %d, leve: %d)" % [worst_bad, worst_soft])
	check(rout_bad <= 20, "fugitivos em pânico quase nunca se sobrepõem (%d pares somando todas as amostras)" % rout_bad)
	check(t_total / 1000.0 / ticks < 40.0, "tick médio abaixo de 40 ms")
