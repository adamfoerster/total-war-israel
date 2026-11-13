extends RefCounted
## Simulação da batalha: soldados em arrays globais, grade espacial, combate, moral.
##
## Otimizações (cada soldado só checa o que está perto):
##  * Unidade "formada" e longe de tudo: nenhum custo por soldado; as posições são
##    implícitas (slots da formação) e só são materializadas quando necessário.
##  * Unidade perto de outra entra na grade espacial (células de 1,6 m, atualizada de
##    forma incremental). Só soldados "acordados" (fora do posto ou em contato com o
##    inimigo) são processados, e cada um consulta apenas as células vizinhas.

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")

const GH := Cfg.GRID_HALF
const GINV := 1.0 / Cfg.GRID_CELL
const GD := Cfg.GRID_N
const GMAX := 2.0 * Cfg.GRID_HALF - 6.0
const HALF := Cfg.HALF_MAP
const N := Cfg.HM_N
const REACH := 0.7
const CTRL := Cfg.CONTROL_HALF - 25.0
const BLK := 40.0
const BLK_N := 100

var terrain
var units: Array = []
var pos := PackedVector2Array()
var cd := PackedFloat32Array()     # instante do próximo ataque
var flag := PackedByteArray()      # 1 vivo, 2 na lista de acordados, 4 em contato
var side_of := PackedByteArray()
var unit_of := PackedInt32Array()
var col_of := PackedByteArray()    # fileira (coluna) do soldado na formação
var row_of := PackedByteArray()    # posto (linha) dentro da fileira
var rad := PackedFloat32Array()
var head := PackedInt32Array()
var nxt := PackedInt32Array()
var slope := PackedFloat32Array()
var blockmax := PackedFloat32Array()

var tick_n := 0
var time := 0.0
var winner := -1
var messages: Array = []           # [texto, lado]
var events: Array = []             # [tipo, unidade] para a camada de som; quem consome limpa
var record_deaths := false          # a cena liga: guarda onde cada soldado morreu
var death_pos := PackedVector2Array()   # visual: posição de cada morte; quem consome limpa
var death_key := PackedInt32Array()     # lado * 10 + tipo, paralelo a death_pos
var shots: Array = []            # visuais: [de, para, tempo de voo, tipo da unidade]
var surrendered := -1                # lado que se rendeu (-1: ninguém)
var volleys: Array = []            # [t_impacto, alvo, acertos, atirador]
var losses := [0, 0]
var fled := [0, 0]
var awake_count := 0               # estatística: soldados processados no último tick

func init(t) -> void:
	terrain = t
	slope = t.slope
	blockmax.resize(BLK_N * BLK_N)
	for bz in BLK_N:
		for bx in BLK_N:
			var m := 0.0
			for j in range(maxi(bz * 4 - 1, 0), mini(bz * 4 + 6, N)):
				for i in range(maxi(bx * 4 - 1, 0), mini(bx * 4 + 6, N)):
					m = maxf(m, slope[j * N + i])
			blockmax[bz * BLK_N + bx] = m

func add_unit(side: int, type: int, men: int, general: bool) -> Unit:
	var u := Unit.new()
	u.id = units.size()
	u.side = side
	u.type = type
	u.t = Cfg.TYPES[type]
	u.mpm = u.t.mpm
	u.cap = int(ceil(float(men) / u.mpm))
	u.n = u.cap
	u.men_init = u.cap * u.mpm
	u.is_general = general
	u.files = clampi(int(round(sqrt(u.cap * float(u.t.ratio)))), 1, 250)
	u.rows0 = (u.cap + u.files - 1) / u.files
	u.depth.resize(u.files)
	u.depth.fill(0)
	u.morale_base = float(u.t.morale) + (15.0 if general else 0.0)
	u.morale = u.morale_base
	u.ammo = u.t.ammo
	u.reload_t = randf() * 2.0
	u.start = pos.size()
	var tot := u.start + u.cap
	pos.resize(tot)
	cd.resize(tot)
	flag.resize(tot)
	side_of.resize(tot)
	unit_of.resize(tot)
	col_of.resize(tot)
	row_of.resize(tot)
	rad.resize(tot)
	nxt.resize(tot)
	for i in range(u.start, tot):
		flag[i] = 1
		cd[i] = randf() * 1.5
		side_of[i] = side
		unit_of[i] = u.id
		var kk := i - u.start
		col_of[i] = kk % u.files
		row_of[i] = kk / u.files
		u.depth[kk % u.files] += 1
		rad[i] = u.t.radius
	units.append(u)
	return u

## Escreve em pos[] os postos da formação na pose atual da unidade.
func materialize(u: Unit) -> void:
	var f := u.facing
	var sp: float = u.t.spacing
	var files := u.files
	var rows := u.rows()
	var rstep := Vector2(-f.y, f.x) * sp
	var fstep := f * sp
	var rowbase := u.center - rstep * ((files - 1) * 0.5) + fstep * ((rows - 1) * 0.5)
	for i in range(u.start, u.start + u.n):
		pos[i] = rowbase + rstep * col_of[i] - fstep * row_of[i]

func materialize_all() -> void:
	for u: Unit in units:
		if u.formed and u.state == 0:
			materialize(u)

func _unform(u: Unit) -> void:
	if u.formed:
		materialize(u)
		u.formed = false
		u.settling = true
		u.dirty = true

func place_unit(u: Unit, center: Vector2, facing: Vector2) -> void:
	u.center = center
	u.facing = facing
	materialize(u)
	u.formed = false
	u.settling = true
	u.brad = _form_radius(u)
	u.dirty = true

## Posiciona as unidades de um lado em linhas: infantaria à frente, carros nas alas,
## atiradores atrás.
func deploy(side: int, origin: Vector2, facing: Vector2) -> void:
	var front: Array = []
	var rear: Array = []
	var cars: Array = []
	for u: Unit in units:
		if u.side != side:
			continue
		if u.type == Cfg.CHARIOT:
			cars.append(u)
		elif float(u.t.range) > 0.0:
			rear.append(u)
		else:
			front.append(u)
	for k in cars.size():
		if k % 2 == 0:
			front.push_front(cars[k])
		else:
			front.push_back(cars[k])
	var lines: Array = []
	for group: Array in [front, rear]:
		var cur: Array = []
		var w := 0.0
		for u: Unit in group:
			var uw: float = u.files * float(u.t.spacing) + 12.0
			if w + uw > 1000.0 and not cur.is_empty():
				lines.append(cur)
				cur = []
				w = 0.0
			cur.append(u)
			w += uw
		if not cur.is_empty():
			lines.append(cur)
	var r := Vector2(-facing.y, facing.x)
	var back := 0.0
	for line: Array in lines:
		var total := 0.0
		var depth := 0.0
		for u: Unit in line:
			total += u.files * float(u.t.spacing) + 12.0
			depth = maxf(depth, u.rows() * float(u.t.spacing))
		var x := -total * 0.5
		for u: Unit in line:
			var uw: float = u.files * float(u.t.spacing) + 12.0
			var c := origin + r * (x + uw * 0.5) - facing * (back + depth * 0.5)
			if u.type == Cfg.CHARIOT:
				c = terrain.nearest_passable(c, true)
			place_unit(u, c, facing)
			x += uw
		back += depth + 25.0

## Faixa z (mín, máx) do setor de posicionamento do lado.
func sector_z(side: int) -> Vector2:
	return Vector2(Cfg.SECTOR_HALF, CTRL) if side == 0 else Vector2(-CTRL, -Cfg.SECTOR_HALF)

## Posicionamento inicial automático do lado, dentro do seu setor.
func deploy_side(side: int) -> void:
	deploy(side, Cfg.DEPLOY_ORIGIN[side], Cfg.DEPLOY_FACING[side])
	for u: Unit in units:
		if u.side == side:
			place_in_sector(u, u.center, u.facing)

## Fase de posicionamento: põe a unidade direto em `p` (sem marchar), virada para `facing`
## (ZERO mantém a frente atual), com a formação inteira dentro do setor do seu lado.
## Se o centro cair em terreno intransponível ou a formação encostar em outra unidade do
## mesmo lado (fora de `ignore`), procura o ponto livre mais próximo em anéis de até 300 m.
func place_in_sector(u: Unit, p: Vector2, facing: Vector2, ignore: Array = []) -> void:
	var f := facing if facing != Vector2.ZERO else u.facing
	u.facing = f
	u.path = PackedVector2Array()
	u.target = null
	u.want_facing = Vector2.ZERO
	u.dest_facing = Vector2.ZERO
	var best := _sector_clamp(u, p)
	for ring in 21:
		var rad := ring * 15.0
		var tries := 1 if ring == 0 else 8 + ring * 2
		var found := false
		for k in tries:
			var c := _sector_clamp(u, p + Vector2(rad, 0).rotated(TAU * k / tries))
			if _deploy_spot_ok(u, c, ignore):
				best = c
				found = true
				break
		if found:
			break
	place_unit(u, best, f)

## Centro limitado para a formação inteira (na frente atual de u) caber no setor.
func _sector_clamp(u: Unit, p: Vector2) -> Vector2:
	var f := u.facing
	var sp: float = u.t.spacing
	var hw := u.files * sp * 0.5
	var hd := u.rows() * sp * 0.5
	var r := Vector2(-f.y, f.x)
	var ex := absf(r.x) * hw + absf(f.x) * hd
	var ez := absf(r.y) * hw + absf(f.y) * hd
	var zr := sector_z(u.side)
	p.x = clampf(p.x, -CTRL + ex, CTRL - ex) if ex < CTRL else 0.0
	p.y = clampf(p.y, zr.x + ez, zr.y - ez) if zr.x + ez < zr.y - ez else (zr.x + zr.y) * 0.5
	return p

## Todos os postos da formação em terreno transitável e formação sem encostar em outra
## unidade do mesmo lado.
func _deploy_spot_ok(u: Unit, c: Vector2, ignore: Array) -> bool:
	for o: Unit in units:
		if o == u or o.side != u.side or o.state != 0 or o.n == 0 or o in ignore:
			continue
		if _rects_touch_at(c, u, o, 2.0):
			return false
	var lim: float = terrain.limit(u.type == Cfg.CHARIOT)
	var f := u.facing
	var sp: float = u.t.spacing
	var rstep := Vector2(-f.y, f.x) * sp
	var fstep := f * sp
	var rowbase := c - rstep * ((u.files - 1) * 0.5) + fstep * ((u.rows() - 1) * 0.5)
	for i in range(u.start, u.start + u.n):
		var q := rowbase + rstep * col_of[i] - fstep * row_of[i]
		if terrain.slope_at(q.x, q.y) > lim:
			return false
	return true

func finalize() -> void:
	head.resize(GD * GD)
	head.fill(-1)

# ------------------------------------------------------------------ ordens

func _clamp_ctrl(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -CTRL, CTRL), clampf(p.y, -CTRL, CTRL))

## Ponto onde a unidade de fato chegaria ao receber ordem de ir até p.
func reachable(p: Vector2, u: Unit) -> Vector2:
	return terrain.nearest_passable(_clamp_ctrl(p), u.type == Cfg.CHARIOT)

func order_move(u: Unit, dest: Vector2, facing: Vector2, run: bool) -> void:
	if u.state != 0:
		return
	u.target = null
	u.running = run
	u.dest_facing = facing
	dest = reachable(dest, u)
	u.path = plan_path(u, dest, null)
	u.path_i = 0
	u.blocked_t = 0.0
	u.replan_at = Cfg.BLOCK_REPLAN

## Caminho de u até `dest` dando a volta nas outras unidades (exceto `exclude`). Se o desvio
## for muito maior que o caminho direto, ou não existir, devolve o direto e marca u.thru:
## nesse caso a unidade passa por entre as outras.
func plan_path(u: Unit, dest: Vector2, exclude) -> PackedVector2Array:
	var chariot := u.type == Cfg.CHARIOT
	u.thru = false
	var cells := _obstacle_cells(u, exclude, u.center, dest)
	if cells.is_empty():
		return terrain.find_path(u.center, dest, chariot)
	if _straight_fits(u, u.center, dest, exclude):
		# a reta passa por um vão onde a unidade cabe estreitando a frente
		var direct0: PackedVector2Array = terrain.find_path(u.center, dest, chariot)
		if direct0.size() <= 2:
			return direct0
	var around: PackedVector2Array = terrain.find_path_blocked(u.center, dest, chariot, cells)
	var straight := u.center.distance_to(dest)
	if not around.is_empty():
		var la := _path_len(u.center, around)
		if la <= straight * 1.3 + 40.0:
			return around
		var direct: PackedVector2Array = terrain.find_path(u.center, dest, chariot)
		if la <= _path_len(u.center, direct) * Cfg.DETOUR_RATIO + Cfg.DETOUR_ADD:
			return around
		u.thru = true
		return direct
	u.thru = true
	return terrain.find_path(u.center, dest, chariot)

func _path_len(from: Vector2, path: PackedVector2Array) -> float:
	var l := 0.0
	var c := from
	for p in path:
		l += c.distance_to(p)
		c = p
	return l

## Células da grade de navegação ocupadas pelas formações das outras unidades, com folga
## para a largura de u. Ignora as células perto da origem e do destino.
func _obstacle_cells(u: Unit, exclude, a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	var seen := {}
	var m := minf(maxf(u.files * float(u.t.spacing), u.rows() * float(u.t.spacing)) * 0.5, 30.0) + 2.0
	var cell := Cfg.NAV_CELL
	for o: Unit in units:
		if o == u or is_same(o, exclude) or o.state != 0 or o.n == 0:
			continue
		var sp: float = o.t.spacing
		var hw := o.files * sp * 0.5 + m + cell * 0.5
		var hd := o.rows() * sp * 0.5 + m + cell * 0.5
		var f := o.facing
		var r := Vector2(-f.y, f.x)
		var ext := absf(r.x) * hw + absf(f.x) * hd
		var exz := absf(r.y) * hw + absf(f.y) * hd
		var c0: Vector2i = terrain._cell(o.center - Vector2(ext, exz))
		var c1: Vector2i = terrain._cell(o.center + Vector2(ext, exz))
		for cz in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var wp := Vector2(-HALF + (cx + 0.5) * cell, -HALF + (cz + 0.5) * cell)
				var d := wp - o.center
				if absf(d.dot(r)) <= hw and absf(d.dot(f)) <= hd 						and wp.distance_squared_to(a) > 900.0 and wp.distance_squared_to(b) > 900.0:
					var id := Vector2i(cx, cz)
					if not seen.has(id):
						seen[id] = true
						out.append(id)
	return out

## Muda a largura da formação para `nf` soldados na frente (mínimo Cfg.MIN_LINE_FILES,
## ou todos, se a unidade tiver menos). Os soldados mantêm a ordem (fileira, coluna) e
## caminham até os novos postos.
func order_reform(u: Unit, nf: int) -> void:
	if u.state != 0 or u.n == 0:
		return
	u.files_want = 0
	u.squeeze_vec = Vector2.ZERO
	_set_files(u, clampi(nf, mini(Cfg.MIN_LINE_FILES, u.n), u.n))

## Troca a largura sem limite mínimo de linha (usado também ao estreitar num vão).
func _set_files(u: Unit, nf: int) -> void:
	nf = clampi(nf, 1, maxi(u.n, 1))
	if nf == u.files:
		return
	_unform(u)
	var order: Array = range(u.start, u.start + u.n)
	order.sort_custom(func(a, b): return row_of[a] * 1000 + col_of[a] < row_of[b] * 1000 + col_of[b])
	u.files = nf
	u.rows0 = (u.n + nf - 1) / nf
	u.depth.resize(nf)
	u.depth.fill(0)
	for j in order.size():
		var i: int = order[j]
		col_of[i] = j % nf
		row_of[i] = j / nf
		u.depth[j % nf] += 1
	u.ragged = false
	u.settling = true
	u.dirty = true
	if u.in_grid:
		_wake_all(u)

## O general tenta parar a debandada: tropas próximas ganham muito moral (e as que fugiam
## voltam ao controle, de frente para o inimigo); as distantes ganham pouca. Uma vez por minuto.
## Devolve false se não puder (sem general vivo e sob controle, ou em espera).
func rally(g: Unit) -> bool:
	if not g.is_general or not g.general_alive or g.state != 0 or time < g.rally_ready:
		return false
	g.rally_ready = time + Cfg.RALLY_COOLDOWN
	var back := 0
	for f: Unit in units:
		if f.side != g.side or f.state == 2:
			continue
		var near := f.center.distance_to(g.center) <= Cfg.RALLY_NEAR
		if f.state == 1:
			if near and f.n > 0:
				_stop_rout(f)
				f.morale = minf(Cfg.ROUT_MORALE + Cfg.RALLY_NEAR_GAIN, f.morale_base)
				back += 1
			continue
		var gain: float = Cfg.RALLY_NEAR_GAIN if near else Cfg.RALLY_FAR_GAIN
		f.morale = minf(f.morale + gain, f.morale_base + 10.0)
	messages.append(["O general de %s reúne as tropas!%s" % [Cfg.SIDE_NAMES[g.side], (" %d unidade(s) deixam de fugir." % back) if back > 0 else ""], g.side])
	events.append(["rally", g])
	return true

## Fim da fuga: os soldados voltam a se alinhar nos postos, virados para o inimigo.
func _stop_rout(u: Unit) -> void:
	u.state = 0
	u.rout_path = PackedVector2Array()
	u.rout_blocked = false
	u.vel = Vector2.ZERO
	u.path = PackedVector2Array()
	if u.flee_dir != Vector2.ZERO:
		u.want_facing = -u.flee_dir
	u.formed = false
	u.settling = true
	u.dirty = true
	u.dense = true   # força passagem pela grade até se reorganizar
	for i in range(u.start, u.start + u.n):
		flag[i] = 1
	if u.in_grid:
		_wake_all(u)

func order_attack(u: Unit, tg: Unit, run: bool) -> void:
	if u.state != 0 or tg == null or tg.state == 2:
		return
	u.target = tg
	u.running = run
	u.dest_facing = Vector2.ZERO
	u.repath_t = 0.0
	u.path = PackedVector2Array()

func order_halt(u: Unit) -> void:
	u.target = null
	u.path = PackedVector2Array()
	u.dest_facing = Vector2.ZERO

func nearest_enemy(u: Unit, only_ok: bool) -> Unit:
	var best: Unit = null
	var bd := 1e18
	for e: Unit in units:
		if e.side == u.side or e.state == 2 or (only_ok and e.state != 0):
			continue
		var d := u.center.distance_squared_to(e.center)
		if d < bd:
			bd = d
			best = e
	return best

func controlled(side: int) -> int:
	var c := 0
	for u: Unit in units:
		if u.side == side and u.state == 0:
			c += 1
	return c

func men_alive(side: int) -> int:
	var c := 0
	for u: Unit in units:
		if u.side == side and u.state == 0:
			c += u.men()
	return c

# ------------------------------------------------------------------ grade espacial

func _cell(p: Vector2) -> int:
	var x := p.x + GH
	var z := p.y + GH
	if x < 6.0 or z < 6.0 or x > GMAX or z > GMAX:
		return -1
	return int(x * GINV) + int(z * GINV) * GD

func _link(i: int, c: int) -> void:
	if c >= 0:
		nxt[i] = head[c]
		head[c] = i

func _unlink(i: int, c: int) -> void:
	if c < 0:
		return
	var j := head[c]
	if j == i:
		head[c] = nxt[i]
		return
	while j >= 0:
		var k := nxt[j]
		if k == i:
			nxt[j] = nxt[i]
			return
		j = k

func _set_pos(i: int, q: Vector2) -> void:
	var a := _cell(pos[i])
	var b := _cell(q)
	if a != b:
		_unlink(i, a)
		_link(i, b)
	pos[i] = q

func _grid_add(u: Unit) -> void:
	u.rigid = false
	for i in range(u.start, u.start + u.n):
		_link(i, _cell(pos[i]))
	u.in_grid = true

func _grid_remove(u: Unit) -> void:
	for i in range(u.start, u.start + u.n):
		_unlink(i, _cell(pos[i]))
	u.in_grid = false

func _wake(u: Unit, i: int) -> void:
	var f := flag[i]
	if (f & 2) == 0:
		flag[i] = f | 2
		u.wake.append(i)

func _wake_all(u: Unit) -> void:
	var s := u.start
	var e := s + u.n
	u.wake = PackedInt32Array(range(s, e))
	for i in range(s, e):
		flag[i] = flag[i] | 2
	u.all_awake = true

func _notify(j: int) -> void:
	var f := flag[j]
	flag[j] = f | 6
	if (f & 2) == 0:
		(units[unit_of[j]] as Unit).wake.append(j)

# ------------------------------------------------------------------ tick

func tick(dt: float) -> void:
	tick_n += 1
	time += dt
	if tick_n % 3 == 1:
		_broadphase()
	awake_count = 0
	for u: Unit in units:
		if u.state == 0:
			_update_unit(u, dt)
		elif u.state == 1 and (tick_n + u.id) % 2 == 0:
			# fugitivos: atualizados a cada dois ticks (metade do custo)
			_update_rout(u, dt * 2.0)
			u.rout_stamp = tick_n
	_update_volleys()
	if tick_n % 5 == 0:
		_update_morale(dt * 5.0)
		_check_victory()

func _form_radius(u: Unit) -> float:
	var sp: float = u.t.spacing
	var w := u.files * sp
	var d := u.rows() * sp
	return 0.5 * sqrt(w * w + d * d) + 6.0

## Retângulos orientados das formações se tocam? (teste de eixos separadores)
func _rects_touch(a: Unit, b: Unit, margin: float) -> bool:
	return _rects_touch_at(a.center, a, b, margin)

## Mesmo teste com a unidade a posicionada em `ac`.
func _rects_touch_at(ac: Vector2, a: Unit, b: Unit, margin: float) -> bool:
	var d := b.center - ac
	var ah := Vector2(a.files * float(a.t.spacing) * 0.5 + margin, a.rows() * float(a.t.spacing) * 0.5 + margin)
	var bh := Vector2(b.files * float(b.t.spacing) * 0.5 + margin, b.rows() * float(b.t.spacing) * 0.5 + margin)
	var af := a.facing
	var ar := Vector2(-af.y, af.x)
	var bf := b.facing
	var br := Vector2(-bf.y, bf.x)
	for ax: Vector2 in [ar, af, br, bf]:
		var pa := ah.x * absf(ar.dot(ax)) + ah.y * absf(af.dot(ax))
		var pb := bh.x * absf(br.dot(ax)) + bh.y * absf(bf.dot(ax))
		if absf(d.dot(ax)) > pa + pb:
			return false
	return true

## A formação de u, se fosse para `nc`, entraria na de outra unidade que ainda não a toca?
func _path_blocked(u: Unit, nc: Vector2) -> bool:
	for o: Unit in units:
		if o == u or o.state != 0 or o.n == 0 or is_same(o, u.target):
			continue
		var rr := u.brad + o.brad + 20.0
		if nc.distance_squared_to(o.center) > rr * rr:
			continue
		if _rects_touch_at(nc, u, o, 0.0) and not _rects_touch_at(u.center, u, o, 0.0):
			return true
	return false

func _terrain_safe(u: Unit, lim: float) -> bool:
	var r := u.brad + 8.0
	var x0 := clampi(int((u.center.x - r + HALF) / BLK), 0, BLK_N - 1)
	var x1 := clampi(int((u.center.x + r + HALF) / BLK), 0, BLK_N - 1)
	var z0 := clampi(int((u.center.y - r + HALF) / BLK), 0, BLK_N - 1)
	var z1 := clampi(int((u.center.y + r + HALF) / BLK), 0, BLK_N - 1)
	for bz in range(z0, z1 + 1):
		for bx in range(x0, x1 + 1):
			if blockmax[bz * BLK_N + bx] > lim:
				return false
	return true

func _broadphase() -> void:
	var cnt := units.size()
	for u: Unit in units:
		u.dense = false
		u.qr = 2 if u.type == Cfg.CHARIOT else 1
		if u.state == 0:
			u.brad = _form_radius(u)
	for a in cnt:
		var ua: Unit = units[a]
		if ua.state == 2:
			continue
		for b in range(a + 1, cnt):
			var ub: Unit = units[b]
			if ub.state == 2:
				continue
			var rr := ua.brad + ub.brad + 8.0 + ua.spill + ub.spill
			if ua.center.distance_squared_to(ub.center) >= rr * rr:
				continue
			var hit := false
			if ua.state == 1 or ub.state == 1:
				hit = true
			elif ua.side != ub.side or ua.active or ub.active:
				# formações só entram na grade quando os retângulos quase se tocam
				# (a margem vale para os dois retângulos, então metade da folga somada basta)
				hit = _rects_touch(ua, ub, 3.0 + 0.5 * (ua.spill + ub.spill))
			if hit:
				ua.dense = true
				ub.dense = true
				if ub.type == Cfg.CHARIOT:
					ua.qr = 2
				if ua.type == Cfg.CHARIOT:
					ub.qr = 2
	for u: Unit in units:
		if u.state == 1:
			# fugitivos: na grade só quando perto de outra unidade
			var want := u.dense or u.rout_blocked
			if want and not u.in_grid:
				_grid_add(u)
			elif not want and u.in_grid:
				_grid_remove(u)
		elif u.state == 0:
			u.safe = _terrain_safe(u, terrain.limit(u.type == Cfg.CHARIOT))
			if u.in_grid:
				# todos nos postos, ninguém por perto, terreno livre: volta a ser rígida
				if not u.dense and u.safe and u.rigid:
					_grid_remove(u)
					u.formed = true
			elif not u.formed or u.dense or not u.safe:
				_unform(u)
				_grid_add(u)
				_wake_all(u)

func _node(p: Vector2) -> int:
	return clampi(int((p.y + HALF) * 0.1 + 0.5), 0, N - 1) * N + clampi(int((p.x + HALF) * 0.1 + 0.5), 0, N - 1)

## Aplica as regras de declive a um passo p -> q. Devolve a posição final.
func _terrain_step(p: Vector2, q: Vector2, lim: float) -> Vector2:
	var s := slope[_node(q)]
	var s0 := slope[_node(p)]
	if s <= lim or s0 > lim or s <= s0:
		return q
	var d := q - p
	var q2 := p + d.rotated(1.2)
	if slope[_node(q2)] <= lim:
		return q2
	q2 = p + d.rotated(-1.2)
	if slope[_node(q2)] <= lim:
		return q2
	return p

## q colide com alguém? Ignora vizinhos dos quais o soldado está se afastando
## (evita que pares encostados fiquem travados).
func _overlaps(i: int, p: Vector2, q: Vector2, myr: float, qr: int) -> bool:
	var cq := _cell(q)
	if cq < 0:
		return false
	for dz in range(-qr, qr + 1):
		var base := cq + dz * GD
		for dx in range(-qr, qr + 1):
			var j := head[base + dx]
			while j >= 0:
				if j != i:
					var rr := (myr + rad[j]) * 0.88
					var pj := pos[j]
					var dq := q.distance_squared_to(pj)
					if dq < rr * rr and dq < p.distance_squared_to(pj):
						return true
				j = nxt[j]
	return false

func _about_face(u: Unit) -> void:
	_unform(u)
	var ing := u.in_grid
	if ing:
		_grid_remove(u)
	# cada homem fica onde está: a última linha de cada fileira vira a primeira
	var files := u.files
	for i in range(u.start, u.start + u.n):
		var c := col_of[i]
		row_of[i] = u.depth[c] - 1 - row_of[i]
		col_of[i] = files - 1 - c
	u.depth.reverse()
	u.facing = -u.facing
	u.settling = true
	if ing:
		_grid_add(u)
		_wake_all(u)

func eff_range(u: Unit, tg: Unit) -> float:
	var dh: float = terrain.height(u.center.x, u.center.y) - terrain.height(tg.center.x, tg.center.y)
	return float(u.t.range) * (1.0 + clampf(dh * 0.003, -0.15, 0.25))

func _advance_anchor(u: Unit, dt: float, spd_mult: float) -> bool:
	var t := u.t
	var want := Vector2.ZERO
	if u.target != null:
		var tg: Unit = u.target
		if tg.state == 2 or tg.n == 0:
			u.target = null
			u.path = PackedVector2Array()
		else:
			var tc := tg.center
			var dist := u.center.distance_to(tc)
			var hold := false
			if float(t.range) > 0.0 and u.ammo > 0:
				hold = dist <= eff_range(u, tg) * 0.9
			else:
				var need := maxi(2, mini(u.files, tg.files) / 2)
				var depth: float = (u.rows() * float(t.spacing) + tg.rows() * float(tg.t.spacing)) * 0.5
				hold = u.contacts >= need or dist < depth * 0.5 + 1.0
			if hold:
				u.path = PackedVector2Array()
				if u.contacts == 0 and dist > 1.0:
					want = (tc - u.center) / dist
			else:
				u.repath_t -= dt
				if u.path.is_empty() or u.repath_t <= 0.0:
					u.repath_t = 1.0 + randf() * 0.5
					u.path = plan_path(u, tc, tg)
					u.path_i = 0
	var moved := false
	if not u.path.is_empty():
		var step: float = (float(t.run) if u.running else float(t.walk)) * spd_mult * dt
		var wp := u.path[u.path_i]
		var dv := wp - u.center
		var l := dv.length()
		var dir := dv / l if l > 0.001 else u.facing
		var g: Vector2 = terrain.grad_at(u.center)
		var climb := g.dot(dir)
		if climb > 0.0:
			step *= clampf(1.0 - climb * 1.2, 0.45, 1.0)
		if l <= step:
			u.center = wp
			u.path_i += 1
			if u.path_i >= u.path.size():
				u.path = PackedVector2Array()
				if u.target == null:
					u.arrived_at = time
					if u.dest_facing != Vector2.ZERO:
						u.want_facing = u.dest_facing
		else:
			u.center += dir * step
			want = dir
		if u.squeeze_vec != Vector2.ZERO:
			# centraliza a coluna estreitada no vão
			var lv := u.squeeze_vec.limit_length(step * 0.5)
			u.center += lv
			u.squeeze_vec -= lv
		u.center = _clamp_ctrl(u.center)
		u.vel = dir * (step / dt)
		moved = true
		var fm: float = t.fat
		if u.running:
			u.fatigue += 1.0 * fm * dt
		elif climb <= 0.02:
			u.fatigue -= 0.3 * dt
		if climb > 0.0:
			# subir cansa: proporcional aos metros verticais, mais ainda correndo
			u.fatigue += climb * step * (0.8 if u.running else 0.5) * fm
	else:
		u.vel = Vector2.ZERO
	if want != Vector2.ZERO:
		u.want_facing = want
	if u.want_facing != Vector2.ZERO:
		var ang := u.facing.angle_to(u.want_facing)
		if absf(ang) > 2.2 and u.contacts == 0:
			_about_face(u)
			ang = u.facing.angle_to(u.want_facing)
		# giro limitado pela velocidade dos homens das pontas
		var halfw: float = maxf(u.files * float(t.spacing) * 0.5, 2.0)
		var maxa: float = minf(float(t.turn), 0.5 * float(t.run) * spd_mult / halfw) * dt
		if absf(ang) <= maxa:
			u.facing = u.want_facing.normalized()
			u.want_facing = Vector2.ZERO
		else:
			u.facing = u.facing.rotated(signf(ang) * maxa)
		moved = true
	return moved

## Interseção do raio p + d·t com o retângulo da formação de o, aumentado de `grow`.
## Devolve [entrada, saída] ou [] se não cruza.
func _ray_rect(p: Vector2, d: Vector2, o: Unit, grow: float) -> Array:
	var sp: float = o.t.spacing
	var of := o.facing
	var orr := Vector2(-of.y, of.x)
	var rel := p - o.center
	var tmin := -1e9
	var tmax := 1e9
	for ax: Vector2 in [orr, of]:
		var h: float = (o.files if ax == orr else o.rows()) * sp * 0.5 + grow
		var pp := rel.dot(ax)
		var dd := d.dot(ax)
		if absf(dd) < 1e-6:
			if absf(pp) > h:
				return []
			continue
		var t1 := (-h - pp) / dd
		var t2 := (h - pp) / dd
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmax < tmin:
		return []
	return [tmin, tmax]

## Distância de p, na direção d, até a borda da formação mais próxima de `obs` (até `cap`).
func _free_dist(p: Vector2, d: Vector2, cap: float, obs: Array) -> float:
	var best := cap
	for o: Unit in obs:
		var hit := _ray_rect(p, d, o, 0.0)
		if hit.is_empty() or float(hit[1]) < 0.0:
			continue
		best = minf(best, maxf(float(hit[0]), 0.0))
	return best

## A linha reta de a até b passa entre as outras unidades com folga para a frente mínima
## de estreitamento? Ignora unidades que já cobrem a origem ou o destino.
func _straight_fits(u: Unit, a: Vector2, b: Vector2, exclude) -> bool:
	var l := a.distance_to(b)
	if l < 1.0:
		return true
	var d := (b - a) / l
	var grow := mini(Cfg.SQUEEZE_MIN_FILES + 1, u.n) * float(u.t.spacing) * 0.5
	for o: Unit in units:
		if o == u or is_same(o, exclude) or o.state != 0 or o.n == 0:
			continue
		var hit := _ray_rect(a, d, o, grow)
		if hit.is_empty() or float(hit[1]) < 0.0 or float(hit[0]) > l:
			continue
		if float(hit[0]) <= 0.0 or float(hit[1]) >= l:
			continue   # a origem ou o destino está colado nessa unidade
		return false
	return true

## Estreita a frente para passar por um vão entre outras unidades e volta à largura
## original depois. O vão é medido na retaguarda, no centro, na frente e um pouco adiante;
## a nova frente é o número de soldados que cabem no vão menos um.
func _update_squeeze(u: Unit, dt: float) -> void:
	u.squeeze_t -= dt
	if u.squeeze_t > 0.0:
		return
	u.squeeze_t = Cfg.SQUEEZE_CHECK + randf() * 0.2
	var moving := not u.path.is_empty()
	if u.contacts > 0 or (not moving and u.files_want == 0):
		return
	var base := u.files_want if u.files_want > 0 else u.files
	var sp: float = u.t.spacing
	var dir := u.facing
	if moving:
		var dv := u.path[u.path_i] - u.center
		if dv.length_squared() > 0.01:
			dir = dv.normalized()
	var r := Vector2(-dir.y, dir.x)
	var half := base * sp * 0.5 + sp
	var hd := u.rows() * sp * 0.5
	var reach := u.brad + half + hd + 40.0
	var obs: Array = []
	for o: Unit in units:
		if o == u or o.state != 0 or o.n == 0 or is_same(o, u.target):
			continue
		var rr := reach + o.brad
		if o.center.distance_squared_to(u.center) <= rr * rr:
			obs.append(o)
	var gap := 1e9
	var off := 0.0
	if not obs.is_empty():
		# pontos de medição ao longo de toda a coluna, a cada SQUEEZE_PROBE_STEP m no máximo,
		# para nenhuma formação rasa caber entre dois pontos sem ser vista
		var front := hd + sp + (sp * 4.0 + 10.0 if moving else 0.0)
		var span := front + hd
		var steps := maxi(1, int(ceil(span / Cfg.SQUEEZE_PROBE_STEP)))
		var probes: Array = []
		for q in steps + 1:
			probes.append(-hd + span * q / steps)
		for k: float in probes:
			var p := u.center + dir * k
			var lft := _free_dist(p, -r, half, obs)
			var rgt := _free_dist(p, r, half, obs)
			if lft + rgt < gap:
				gap = lft + rgt
				off = (rgt - lft) * 0.5
	var nf := int(floor(gap / sp)) - 1 if gap < 1e8 else base
	if nf >= base:
		# caminho livre: volta à largura original
		if u.files_want > 0:
			_set_files(u, u.files_want)
			u.files_want = 0
			u.squeeze_vec = Vector2.ZERO
		return
	if nf < mini(Cfg.SQUEEZE_MIN_FILES, u.n):
		return   # vão estreito demais: segue como antes (passa por entre as unidades)
	if nf < u.files and moving:
		if u.files_want == 0:
			u.files_want = u.files
		_set_files(u, nf)
	elif nf > u.files and u.files_want > 0:
		_set_files(u, nf)   # o vão abriu um pouco: alarga em parte
	if u.files_want > 0 and moving:
		u.squeeze_vec = r * off

func _update_unit(u: Unit, dt: float) -> void:
	var t := u.t
	_update_squeeze(u, dt)
	var spd_mult := 1.0 - 0.4 * u.fatigue * 0.01
	var prevc := u.contacts
	var anchor_moved := _advance_anchor(u, dt, spd_mult)
	var fm: float = t.fat
	if prevc > 0:
		u.fatigue += 0.6 * fm * dt
	elif not anchor_moved:
		u.fatigue -= 1.5 * dt
	u.fatigue = clampf(u.fatigue, 0.0, 100.0)
	if u.charge_t > 0.0:
		u.charge_t -= dt
	if u.flank_t > 0.0:
		u.flank_t -= dt
	if u.ammo > 0:
		u.reload_t -= dt
		if u.reload_t <= 0.0 and u.path.is_empty() and prevc == 0:
			_try_fire(u)
	var n := u.n
	if n == 0:
		return
	if u.formed:
		# formação rígida longe de tudo: custo zero por soldado
		u.contacts = 0
		u.active = anchor_moved
		u.spill = 0.0
		return
	var s := u.start
	var f := u.facing
	var sp: float = t.spacing
	var files := u.files
	var rows := u.rows0
	var rstep := Vector2(-f.y, f.x) * sp
	var fstep := f * sp
	var rowbase := u.center - rstep * ((files - 1) * 0.5) + fstep * ((rows - 1) * 0.5)
	var maxstep: float = float(t.run) * spd_mult * dt * (1.6 if u.running else 1.0)
	var ms2 := maxstep * maxstep
	var lim: float = terrain.limit(u.type == Cfg.CHARIOT)
	var sl := slope
	var any := false
	var k := 0
	if not u.in_grid:
		# saiu da formação rígida (morte, reforma, meia-volta): entra na grade já, para os
		# soldados seguirem o centro. Esperar a próxima varredura os deixava parados enquanto
		# o centro andava, e o desenho os puxava de volta (teleporte).
		_grid_add(u)
		_wake_all(u)
	# na grade: colisão e combate, apenas para os soldados acordados
	if anchor_moved and not u.all_awake:
		_wake_all(u)
	var w := u.wake
	u.wake = PackedInt32Array()
	var nw := PackedInt32Array()
	var sd := side_of
	var rd := rad
	var uo := unit_of
	var uid := u.id
	var myr: float = t.radius
	var myside := u.side
	var qr := u.qr
	var tm := time
	var ncontact := 0
	var noff := 0
	var rigid_prev := u.rigid
	var cb2 := col_of
	var rb2 := row_of
	var off2 := 0.0
	awake_count += w.size()
	for gi in w:
		k = gi - s
		if k >= n:
			continue
		var fl := flag[gi]
		var slot := rowbase + rstep * cb2[gi] - fstep * rb2[gi]
		var p := pos[gi]
		var d := slot - p
		var l2 := d.length_squared()
		if l2 > off2:
			off2 = l2
		var at_slot := l2 < 0.0004
		if (fl & 4) != 0 and at_slot and tm < cd[gi]:
			ncontact += 1
			nw.append(gi)
			continue
		var q := p
		var exact := true
		if not at_slot:
			if l2 > ms2:
				d *= maxstep / sqrt(l2)
				exact = false
			q = p + d
		var skip_own := exact and rigid_prev
		var cq := _cell(q)
		if cq < 0:
			if not at_slot:
				var q3 := _terrain_step(p, q, lim)
				if q3 != p:
					_set_pos(gi, q3)
					any = true
				nw.append(gi)
			elif anchor_moved:
				nw.append(gi)
			else:
				flag[gi] = fl & 249
				u.all_awake = false
			continue
		var best := -1
		var bestd := 1e9
		var push := Vector2.ZERO
		var nover := 0
		for dz in range(-qr, qr + 1):
			var base := cq + dz * GD
			for dx in range(-qr, qr + 1):
				var j := head[base + dx]
				while j >= 0:
					if j != gi:
						if sd[j] != myside:
							var dv := q - pos[j]
							var d2 := dv.length_squared()
							var rr := myr + rd[j]
							var er := rr + REACH
							if d2 < er * er:
								if d2 < bestd:
									bestd = d2
									best = j
								if (flag[j] & 6) != 6:
									_notify(j)
								if d2 < rr * rr:
									nover += 1
									if d2 > 0.0001:
										var dl := sqrt(d2)
										push += dv * ((rr - dl) / dl)
									else:
										push += Vector2(0.3, 0.0).rotated(float(gi))
						elif not (skip_own and uo[j] == uid):
							var dv2 := q - pos[j]
							var d2b := dv2.length_squared()
							var rr2 := myr + rd[j]
							if d2b < rr2 * rr2:
								nover += 1
								if d2b > 0.0001:
									var dl2 := sqrt(d2b)
									push += dv2 * ((rr2 - dl2) / dl2)
								else:
									push += Vector2(0.3, 0.0).rotated(float(gi))
					j = nxt[j]
		if best >= 0:
			ncontact += 1
			if (fl & 4) == 0:
				fl |= 4
				flag[gi] = fl
			var er2 := myr + rd[best] + REACH
			var near := p.distance_squared_to(pos[best]) < er2 * er2
			if tm >= cd[gi]:
				cd[gi] = tm + 1.2 + randf() * 0.6
				_attack(u, best)
			nw.append(gi)
			if near:
				if not at_slot:
					noff += 1
				continue
		elif (fl & 4) != 0:
			fl &= 251
			flag[gi] = fl
		if at_slot:
			if best < 0:
				if anchor_moved:
					nw.append(gi)
				else:
					flag[gi] = fl & 249
					u.all_awake = false
			continue
		var ok := true
		if nover > 0:
			q += push
			var mv := q - p
			var m2 := mv.length_squared()
			if m2 < 0.0009:
				ok = false
			else:
				if m2 > ms2:
					q = p + mv * (maxstep / sqrt(m2))
				if _overlaps(gi, p, q, myr, qr):
					ok = false
		if ok and sl[_node(q)] > lim:
			var q2 := _terrain_step(p, q, lim)
			if q2 == p or (q2 != q and _overlaps(gi, p, q2, myr, qr)):
				ok = false
			q = q2
		# só anda quem tem espaço: um passo que não aproxima do posto (empurrão de vizinhos,
		# desvio de declive) deixaria o soldado tremendo no lugar
		if ok and best < 0 and (slot - q).length_squared() > l2 - 0.0004:
			ok = false
		if ok:
			_set_pos(gi, q)
			any = true
		if not (ok and exact):
			noff += 1
		if best < 0:
			nw.append(gi)
	u.rigid = noff == 0 and ncontact == 0
	# soldados fora do posto saem do retângulo da formação; a varredura alarga o teste
	# de contato por essa folga, mais o que andam até a próxima varredura (3 ticks)
	u.spill = sqrt(off2) + maxstep * 3.0
	nw.append_array(u.wake)
	u.wake = nw
	if ncontact > 0 and prevc == 0 and u.running and anchor_moved:
		u.charge_t = 6.0
	u.contacts = ncontact
	u.settling = any
	u.active = anchor_moved or any
	if u.active:
		u.dirty = true

# ------------------------------------------------------------------ combate

func _attack(a: Unit, j: int) -> void:
	var b: Unit = units[unit_of[j]]
	b.attacked_by[a.id] = time
	var av: float = float(a.t.atk) * a.str_mult
	if a.charge_t > 0.0:
		av += float(a.t.charge)
	var dv: float = maxf(float(b.t.def) * b.str_mult, 0.5)
	var p := 0.06 * av / dv
	if b.state == 1:
		p *= 3.0
	else:
		var dirv := (a.center - b.center).normalized()
		if b.facing.dot(dirv) < -0.25:
			p *= 1.6
			b.flank_t = 2.0
	if randf() < clampf(p, 0.01, 0.7):
		a.kills += b.mpm
		kill_model(b, j)

func kill_model(u: Unit, gi: int) -> void:
	if u.n <= 0:
		return
	_unform(u)
	if record_deaths:
		death_pos.append(pos[gi])
		death_key.append(u.side * 10 + u.type)
	var ing := u.in_grid
	var s := u.start
	var last := s + u.n - 1
	if u.state == 0:
		# os de trás, na mesma fileira, avançam um posto (ninguém cruza ninguém)
		var c := col_of[gi]
		var r := row_of[gi]
		if r < u.depth[c] - 1:
			for i in range(s, last + 1):
				if col_of[i] == c and row_of[i] > r:
					row_of[i] -= 1
					if ing:
						_wake(u, i)
		u.depth[c] -= 1
		u.ragged = true
	if ing:
		_unlink(gi, _cell(pos[gi]))
	if gi != last:
		if ing:
			_unlink(last, _cell(pos[last]))
		pos[gi] = pos[last]
		cd[gi] = cd[last]
		col_of[gi] = col_of[last]
		row_of[gi] = row_of[last]
		var fl := flag[last]
		flag[gi] = (fl & 5) | (flag[gi] & 2)
		if ing:
			_link(gi, _cell(pos[gi]))
			if (fl & 2) != 0:
				_wake(u, gi)
	flag[last] = 0
	var nb := u.n
	u.n -= 1
	u.lost_acc += u.mpm
	u.dirty = true
	u.settling = true
	losses[u.side] += u.mpm
	if u.is_general and u.general_alive and randi() % nb == 0:
		_general_down(u, true)
	if u.n == 0:
		var was_ok := u.state == 0
		u.state = 2
		u.target = null
		u.in_grid = false
		if was_ok:
			messages.append(["%s foi aniquilada!" % u.label, u.side])
			_shock(u, Cfg.SEE_ROUT_LOSS)

func _general_down(u: Unit, killed: bool) -> void:
	u.general_alive = false
	var loss := Cfg.GENERAL_DEAD_LOSS if killed else Cfg.GENERAL_FLED_LOSS
	for f: Unit in units:
		if f.side == u.side and f.state == 0:
			f.morale -= loss
	messages.append(["O general de %s %s!" % [Cfg.SIDE_NAMES[u.side], "foi morto" if killed else "fugiu"], u.side])

func _shock(u: Unit, loss: float) -> void:
	for f: Unit in units:
		if f != u and f.side == u.side and f.state == 0:
			if f.center.distance_to(u.center) < Cfg.SEE_ROUT_DIST:
				f.morale -= loss

func _try_fire(u: Unit) -> void:
	var tg: Unit = null
	if u.target != null and (u.target as Unit).state != 2:
		if u.center.distance_to((u.target as Unit).center) <= eff_range(u, u.target):
			tg = u.target
	if tg == null and u.fire_at_will:
		var bd := 1e18
		for e: Unit in units:
			if e.side == u.side or e.state == 2 or e.n == 0:
				continue
			var d := u.center.distance_to(e.center)
			var sc := d + (60.0 if e.state == 1 else 0.0)
			if sc < bd and d <= eff_range(u, e):
				bd = sc
				tg = e
	if tg == null:
		u.reload_t = 0.5
		return
	u.ammo -= 1
	u.reload_t = float(u.t.reload) + randf() * 0.4
	var dist := u.center.distance_to(tg.center)
	var flight := dist / 45.0 + 0.3
	var dh: float = terrain.height(u.center.x, u.center.y) - terrain.height(tg.center.x, tg.center.y)
	var hits: float = u.n * float(u.t.acc) * (1.2 - 0.5 * dist / maxf(float(u.t.range), 1.0))
	hits *= (1.0 + clampf(dh * 0.004, -0.15, 0.25)) * (1.0 - float(tg.t.armor)) * (0.7 + 0.3 * u.str_mult)
	volleys.append([time + flight, tg, hits, u])
	shots.append([u.center, tg.center, flight, u.type])

func _update_volleys() -> void:
	var k := volleys.size() - 1
	while k >= 0:
		var v: Array = volleys[k]
		if time >= float(v[0]):
			var tg: Unit = v[1]
			var hits: float = v[2]
			if tg.state != 2:
				tg.attacked_by[(v[3] as Unit).id] = time
			var cnt := int(hits)
			if randf() < hits - cnt:
				cnt += 1
			for c in cnt:
				if tg.n > 0:
					kill_model(tg, tg.start + randi() % tg.n)
			volleys.remove_at(k)
		k -= 1

# ------------------------------------------------------------------ moral / fuga

func _update_morale(dt: float) -> void:
	var gen := [null, null]
	for u: Unit in units:
		if u.is_general and u.general_alive and u.state == 0:
			gen[u.side] = u
	for u: Unit in units:
		if u.state == 1:
			_set_flee_dir(u)
			continue
		if u.state != 0:
			continue
		if u.ragged:
			_rebalance(u)
		var m := u.morale
		if u.lost_acc > 0:
			m -= float(u.lost_acc) / u.men_init * 110.0
			u.lost_acc = 0
		var e := nearest_enemy(u, true)
		var dist := 1e9
		u.height_mod = 1.0
		if e != null:
			dist = u.center.distance_to(e.center)
			if dist < u.brad + e.brad + 15.0:
				# terreno: quem está mais baixo que o oponente luta pior, quem está acima luta melhor
				var dh: float = terrain.height(u.center.x, u.center.y) - terrain.height(e.center.x, e.center.y)
				u.height_mod = clampf(1.0 + dh * 0.05, 0.65, 1.35)
			# unidade parada vira-se para a ameaça que se aproxima
			if u.contacts == 0 and u.path.is_empty() and u.target == null and dist < u.brad + e.brad + 60.0:
				var dir := (e.center - u.center).normalized()
				if u.facing.dot(dir) < 0.9:
					u.want_facing = dir
		var melee := u.contacts > 0
		if u.flank_t > 0.0:
			m -= 1.5 * dt
		if u.fatigue > 70.0:
			m -= 0.6 * dt
		if melee and u.height_mod < 0.95:
			m -= 0.5 * dt
		var cap := u.morale_base
		var g: Unit = gen[u.side]
		if g != null and g.center.distance_to(u.center) < Cfg.GENERAL_AURA:
			cap += 10.0
			m += 0.4 * dt
		if not melee and dist > 150.0:
			m += 1.0 * dt
		u.morale = clampf(m, 0.0, cap)
		var ff := 1.0 - 0.35 * u.fatigue * 0.01
		var mf := 0.7 + 0.3 * clampf(u.morale / u.morale_base, 0.0, 1.1)
		u.str_mult = ff * mf * u.height_mod
		var frac := float(u.men()) / u.men_init
		if u.morale <= Cfg.ROUT_MORALE or frac <= Cfg.ROUT_STRENGTH \
				or (u.fatigue >= Cfg.ROUT_FATIGUE and melee and u.morale < 55.0):
			_start_rout(u)

## Fileiras vizinhas com profundidades muito diferentes: o último homem da mais
## funda passa para o fim da mais rasa (um passo em diagonal pela retaguarda).
func _rebalance(u: Unit) -> void:
	var moved := false
	var s := u.start
	var e := s + u.n
	for c in u.files - 1:
		var a := u.depth[c]
		var b := u.depth[c + 1]
		if absi(a - b) < 2:
			continue
		var from := c if a > b else c + 1
		var to := c + 1 if a > b else c
		var tail := u.depth[from] - 1
		for i in range(s, e):
			if col_of[i] == from and row_of[i] == tail:
				if not moved:
					_unform(u)
					moved = true
				col_of[i] = to
				row_of[i] = u.depth[to]
				u.depth[from] -= 1
				u.depth[to] += 1
				if u.in_grid:
					_wake(u, i)
				break
	if moved:
		u.settling = true
		u.dirty = true
	else:
		u.ragged = false

func _start_rout(u: Unit) -> void:
	_unform(u)
	u.state = 1
	u.spill = 0.0   # na fuga, brad já cobre todos os soldados
	u.target = null
	u.path = PackedVector2Array()
	u.contacts = 0
	u.rout_t = 0.0
	u.wake = PackedInt32Array()
	for i in range(u.start, u.start + u.n):
		flag[i] = 1
	_set_flee_dir(u)
	messages.append(["%s entrou em pânico e foge!" % u.label, u.side])
	events.append(["rout", u])
	_shock(u, Cfg.SEE_ROUT_LOSS)
	_credit_rout(u)
	if u.is_general and u.general_alive:
		_general_down(u, false)

## Quem pôs u em pânico ganha moral: só as unidades sob controle que golpearam u ou
## acertaram disparos nela nos últimos Cfg.ROUT_CREDIT_WINDOW s. Quem apenas marchava
## até ela não conta. O ganho respeita o teto de moral da unidade.
func _credit_rout(u: Unit) -> void:
	for id: int in u.attacked_by:
		if time - float(u.attacked_by[id]) > Cfg.ROUT_CREDIT_WINDOW:
			continue
		var a: Unit = units[id]
		if a.state == 0:
			a.morale = minf(a.morale + Cfg.ROUT_CREDIT_GAIN, _morale_cap(a))
	u.attacked_by.clear()

## Teto de moral: a base da unidade, mais 10 perto do general vivo e sob controle.
func _morale_cap(u: Unit) -> float:
	for g: Unit in units:
		if g.side == u.side and g.is_general and g.general_alive and g.state == 0:
			if g.center.distance_to(u.center) < Cfg.GENERAL_AURA:
				return u.morale_base + 10.0
	return u.morale_base

## Direção de fuga: para longe do inimigo e rumo à borda mais próxima, seguindo uma
## rota que contorna os declives proibidos para o tipo da unidade.
func _set_flee_dir(u: Unit) -> void:
	var c := u.center
	u.rout_repath -= 0.5
	if u.rout_path.is_empty() or u.rout_repath <= 0.0:
		var edge := Vector2(signf(c.x) if c.x != 0.0 else 1.0, 0.0)
		if HALF - absf(c.y) < HALF - absf(c.x):
			edge = Vector2(0.0, signf(c.y) if c.y != 0.0 else 1.0)
		var away := Vector2.ZERO
		var e := nearest_enemy(u, true)
		if e != null and e.center.distance_to(c) < 400.0:
			away = (c - e.center).normalized()
		var d := away + edge * 0.6
		if d.length() < 0.1:
			d = edge
		d = d.normalized().rotated(u.rout_try * PI * 0.5)
		# ponto de saída: onde o raio (c, d) cruza a borda do mapa
		var lim := HALF - 12.0
		var tx := 1e9
		var tz := 1e9
		if absf(d.x) > 0.001:
			tx = (signf(d.x) * lim - c.x) / d.x
		if absf(d.y) > 0.001:
			tz = (signf(d.y) * lim - c.y) / d.y
		var exit := c + d * maxf(minf(tx, tz), 10.0)
		u.rout_path = terrain.find_path(c, exit, u.type == Cfg.CHARIOT)
		u.rout_pi = 0
		u.rout_repath = 4.0
		if u.rout_path.is_empty():
			u.flee_dir = d
			return
		var last := u.rout_path[u.rout_path.size() - 1]
		if absf(last.x) < lim - 60.0 and absf(last.y) < lim - 60.0 and last.distance_to(c) < 60.0:
			u.rout_try += 1   # beco sem saída: tentar outro lado na próxima
	while u.rout_pi < u.rout_path.size() - 1 and c.distance_to(u.rout_path[u.rout_pi]) < 45.0:
		u.rout_pi += 1
	var w := u.rout_path[u.rout_pi] - c
	if w.length() > 1.0:
		u.flee_dir = w.normalized()

func _update_rout(u: Unit, dt: float) -> void:
	u.rout_t += dt
	var t := u.t
	var step: float = float(t.run) * (1.0 - 0.3 * u.fatigue * 0.01) * dt
	var lim: float = terrain.limit(u.type == Cfg.CHARIOT)
	var myr: float = t.radius
	var fd := u.flee_dir
	var s := u.start
	var i := s + u.n - 1
	var sum := Vector2.ZERO
	var c := u.center
	var maxd2 := 0.0
	var ex := Cfg.EXIT_HALF
	var ing := u.in_grid
	var qr := u.qr
	var fr := Vector2(-fd.y, fd.x)
	var spread := 0.75 / maxf(u.brad, 5.0)
	awake_count += u.n
	if not ing:
		# sem colisão só enquanto o campo de fuga anda livre: se o declive desviar ou travar
		# alguém, os de trás passariam por cima. Nesse caso entra na grade antes de mover.
		var k := s + u.n - 1
		while k >= s:
			var p0 := pos[k]
			var q0 := p0 + fd.rotated(clampf((p0 - c).dot(fr) * spread, -0.75, 0.75)) * step
			if absf(q0.x) <= ex and absf(q0.y) <= ex and _terrain_step(p0, q0, lim) != q0:
				u.rout_blocked = true
				_grid_add(u)
				ing = true
				break
			k -= 1
	while i >= s:
		var p := pos[i]
		# campo divergente: quem está à esquerda foge mais para a esquerda, etc.
		var dir := fd.rotated(clampf((p - c).dot(fr) * spread, -0.75, 0.75))
		var q := p + dir * step
		if absf(q.x) > ex or absf(q.y) > ex:
			var last := s + u.n - 1
			if ing:
				_unlink(i, _cell(p))
			if i != last:
				if ing:
					_unlink(last, _cell(pos[last]))
				pos[i] = pos[last]
				cd[i] = cd[last]
				if ing:
					_link(i, _cell(pos[i]))
			flag[last] = 0
			u.n -= 1
			fled[u.side] += u.mpm
			i -= 1
			continue
		q = _terrain_step(p, q, lim)
		if ing:
			if q != p and _overlaps(i, p, q, myr, qr):
				q = _terrain_step(p, p + dir.rotated(1.0 if i % 2 == 0 else -1.0) * step, lim)
				if _overlaps(i, p, q, myr, qr):
					q = p
			if q != p:
				_set_pos(i, q)
		else:
			pos[i] = q
		if q == p and not ing:
			u.rout_blocked = true   # alguém travou: passa a usar a grade para não amontoar
		sum += q
		var d2 := q.distance_squared_to(c)
		if d2 > maxd2:
			maxd2 = d2
		i -= 1
	if u.n == 0 or u.rout_t > 400.0:
		if ing:
			_grid_remove(u)
		for k in range(s, s + u.n):
			flag[k] = 0
		fled[u.side] += u.n * u.mpm
		u.n = 0
		u.state = 2
		u.in_grid = false
		u.dirty = true
		return
	u.center = sum / u.n
	u.brad = sqrt(maxd2) + 4.0
	u.vel = fd * (step / dt)
	u.dirty = true

## Força do lado: soma dos pontos (Cfg.TYPES[].power) dos modelos vivos nas unidades sob
## controle. Unidades em fuga não contam.
func power(side: int) -> int:
	var p := 0
	for u: Unit in units:
		if u.side == side and u.state == 0:
			p += u.n * int(u.t.power)
	return p

## O lado desiste: a vitória vai para o outro.
func surrender(side: int) -> void:
	if winner >= 0:
		return
	surrendered = side
	winner = 1 - side
	messages.append(["%s se %s!" % [Cfg.SIDE_NAMES[side], "rendeu" if side == 0 else "renderam"], side])

func _check_victory() -> void:
	if winner >= 0:
		return
	var a := controlled(0)
	var b := controlled(1)
	if a == 0:
		winner = 1
	elif b == 0:
		winner = 0
