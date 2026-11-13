extends RefCounted
## IA simples: infantaria ataca o inimigo mais próximo (espalhando alvos), atiradores
## mantêm distância e preferem terreno alto, carros caçam atiradores e infantaria leve.

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")

var sim
var side := 1
var _t := 0.0
var _idx := 0

func init(s, sd: int) -> void:
	sim = s
	side = sd

func update(dt: float) -> void:
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	var mine: Array = []
	for u: Unit in sim.units:
		if u.side == side and u.state == 0:
			mine.append(u)
	if mine.is_empty():
		return
	# rende-se com menos de um terço da força do inimigo
	if sim.power(side) < sim.power(1 - side) * Cfg.SURRENDER_RATIO:
		sim.surrender(side)
		return
	var cnt :=maxi(1, (mine.size() + 3) / 4)
	for k in cnt:
		_idx = (_idx + 1) % mine.size()
		_think(mine[_idx], mine)

func _think(u: Unit, mine: Array) -> void:
	var foes: Array = []
	for e: Unit in sim.units:
		if e.side != side and e.state == 0:
			foes.append(e)
	if foes.is_empty():
		# só restam fugitivos: tropas rápidas perseguem
		var r: Unit = sim.nearest_enemy(u, false)
		if r != null and (u.type == Cfg.LIGHT or u.type == Cfg.CHARIOT) and u.fatigue < 60.0:
			if u.target != r:
				sim.order_attack(u, r, true)
		elif u.target != null:
			sim.order_halt(u)
		return
	if u.contacts > 0:
		return
	var is_missile: bool = float(u.t.range) > 0.0 and u.ammo > 0
	if is_missile:
		_think_missile(u, foes)
		return
	# contagem de quantos amigos já miram cada inimigo
	var load := {}
	for f: Unit in mine:
		if f != u and f.target != null:
			load[f.target] = int(load.get(f.target, 0)) + 1
	# eixo do avanço: do centro do meu exército ao centro do inimigo; cada unidade
	# prefere o inimigo à sua frente (avanço em faixas, sem cruzar os aliados)
	var ca := Vector2.ZERO
	for f: Unit in mine:
		ca += f.center
	ca /= mine.size()
	var cf := Vector2.ZERO
	for e: Unit in foes:
		cf += e.center
	cf /= foes.size()
	var ax := (cf - ca).normalized() if cf.distance_to(ca) > 1.0 else u.facing
	var best: Unit = null
	var bs := 1e18
	var car: bool = u.type == Cfg.CHARIOT
	for e: Unit in foes:
		# inimigo em outra região do terreno (separada por declives que u não vence): inalcançável
		if not sim.terrain.connected(u.center, e.center, car):
			continue
		var rel := e.center - u.center
		var d := rel.length()
		var sc := absf(rel.dot(ax)) + 2.5 * absf(rel.cross(ax)) + 45.0 * int(load.get(e, 0))
		if u.type == Cfg.CHARIOT:
			if float(e.t.range) > 0.0:
				sc -= 250.0
			elif e.type == Cfg.LIGHT:
				sc -= 100.0
			elif e.type == Cfg.HEAVY:
				sc += 150.0
		if u.target == e:
			sc -= 30.0
		if sc < bs:
			bs = sc
			best = e
	if best == null:
		if u.target != null:
			sim.order_halt(u)
		return
	var dist := u.center.distance_to(best.center)
	if dist < 1.0:
		return
	var run := dist < (260.0 if u.type == Cfg.CHARIOT else 130.0) and u.fatigue < 55.0
	if u.target != best or u.running != run:
		sim.order_attack(u, best, run)

func _think_missile(u: Unit, foes: Array) -> void:
	var near: Unit = null
	var nd := 1e18
	for e: Unit in foes:
		var d := u.center.distance_to(e.center)
		if d < nd:
			nd = d
			near = e
	# inimigo de corpo a corpo chegando: recuar
	if nd < 55.0 and (float(near.t.range) <= 0.0 or near.ammo <= 0):
		var away := (u.center - near.center).normalized()
		if u.path.is_empty() or u.target != null:
			sim.order_move(u, u.center + away * 110.0, -away, u.fatigue < 80.0)
		return
	var rng: float = sim.eff_range(u, near)
	if nd > rng * 0.9:
		# não empurrar a própria linha: espera se houver aliados logo à frente
		var dir := (near.center - u.center) / nd
		for f: Unit in sim.units:
			if f.side != side or f == u or f.state != 0:
				continue
			# só espera quem avança ou luta; um aliado parado (sem rota) seguraria a fila para sempre
			if f.path.is_empty() and f.contacts == 0:
				continue
			var rel := f.center - u.center
			var ahead := rel.dot(dir)
			if ahead > 0.0 and ahead < f.brad + u.brad + 10.0 and absf(rel.cross(dir)) < f.brad + u.brad - 8.0:
				if u.target != null or not u.path.is_empty():
					sim.order_halt(u)
				return
		if u.target != near:
			sim.order_attack(u, near, false)
	elif u.target == null and u.path.is_empty():
		# já em alcance: se houver terreno mais alto bem perto, ocupar
		var g: Vector2 = sim.terrain.grad_at(u.center)
		if g.length() > 0.08 and randf() < 0.15:
			var up := u.center + g.normalized() * 40.0
			if up.distance_to(near.center) < rng * 0.85 and up.distance_to(near.center) > 70.0:
				sim.order_move(u, up, (near.center - up).normalized(), false)
