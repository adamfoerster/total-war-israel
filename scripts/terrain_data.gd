extends RefCounted
## Dados do terreno: altura, gradiente, declive e grades de navegação.

const Cfg = preload("res://scripts/config.gd")
const N := Cfg.HM_N
const HALF := Cfg.HALF_MAP
const INV := 1.0 / Cfg.HM_CELL

var h := PackedFloat32Array()
var slope := PackedFloat32Array()   # graus, por nó
var gx := PackedFloat32Array()
var gz := PackedFloat32Array()
var hmax := 1.0
var base_alt := 0.0
var real_data := false
var nav_foot := AStarGrid2D.new()
var nav_car := AStarGrid2D.new()

func load_map() -> void:
	var path := "res://assets/jerusalem_height.res"
	if ResourceLoader.exists(path):
		var img := load(path) as Image
		if img != null and img.get_width() == N and img.get_format() == Image.FORMAT_RF:
			h = img.get_data().to_float32_array()
			real_data = true
	if h.size() != N * N:
		_fallback()
	var mn := 1e9
	for v in h:
		mn = minf(mn, v)
	base_alt = mn
	hmax = 1.0
	for k in h.size():
		var v := (h[k] - mn) * Cfg.VERT_EXAG
		h[k] = v
		hmax = maxf(hmax, v)
	gx.resize(N * N)
	gz.resize(N * N)
	slope.resize(N * N)
	for j in N:
		var j0 := maxi(j - 1, 0)
		var j1 := mini(j + 1, N - 1)
		for i in N:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, N - 1)
			var k := j * N + i
			var a := (h[j * N + i1] - h[j * N + i0]) / ((i1 - i0) * Cfg.HM_CELL)
			var b := (h[j1 * N + i] - h[j0 * N + i]) / ((j1 - j0) * Cfg.HM_CELL)
			gx[k] = a
			gz[k] = b
			slope[k] = rad_to_deg(atan(sqrt(a * a + b * b)))
	_build_nav(nav_foot, Cfg.SLOPE_IMPASS, 0)
	_build_nav(nav_car, Cfg.SLOPE_CHARIOT, 3)

func _fallback() -> void:
	# Relevo sintético, usado apenas se o heightmap real não estiver presente.
	h.resize(N * N)
	for j in N:
		for i in N:
			var x := (i - 200) * 10.0
			var z := (j - 200) * 10.0
			var v := 700.0 + 60.0 * exp(-((x + 100.0) * (x + 100.0) + z * z) / 400000.0)
			v += 110.0 * exp(-((x - 850.0) * (x - 850.0)) / 150000.0)
			v -= 70.0 * exp(-((x - 350.0) * (x - 350.0)) / 20000.0)
			h[j * N + i] = v

## margin: nós extras (10 m cada) ao redor da célula que também precisam ser transitáveis;
## dá folga para a largura da formação dos carros.
func _build_nav(g: AStarGrid2D, lim: float, margin: int) -> void:
	var nn := Cfg.NAV_N
	g.region = Rect2i(0, 0, nn, nn)
	g.cell_size = Vector2(Cfg.NAV_CELL, Cfg.NAV_CELL)
	g.offset = Vector2(-HALF + Cfg.NAV_CELL * 0.5, -HALF + Cfg.NAV_CELL * 0.5)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for cz in nn:
		for cx in nn:
			var s := 0.0
			for b in range(maxi(cz * 2 - margin, 0), mini(cz * 2 + 3 + margin, N)):
				for a in range(maxi(cx * 2 - margin, 0), mini(cx * 2 + 3 + margin, N)):
					s = maxf(s, slope[b * N + a])
			var id := Vector2i(cx, cz)
			if s > lim:
				g.set_point_solid(id, true)
			else:
				g.set_point_weight_scale(id, 1.0 + s / 10.0)

func height(x: float, z: float) -> float:
	var fx := clampf((x + HALF) * INV, 0.0, N - 1.001)
	var fz := clampf((z + HALF) * INV, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var k := iz * N + ix
	return lerpf(lerpf(h[k], h[k + 1], tx), lerpf(h[k + N], h[k + N + 1], tx), fz - iz)

func node_index(x: float, z: float) -> int:
	var ix := clampi(int((x + HALF) * INV + 0.5), 0, N - 1)
	var iz := clampi(int((z + HALF) * INV + 0.5), 0, N - 1)
	return iz * N + ix

func slope_at(x: float, z: float) -> float:
	return slope[node_index(x, z)]

func grad_at(p: Vector2) -> Vector2:
	var k := node_index(p.x, p.y)
	return Vector2(gx[k], gz[k])

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x + HALF) / Cfg.NAV_CELL), 0, Cfg.NAV_N - 1),
		clampi(int((p.y + HALF) / Cfg.NAV_CELL), 0, Cfg.NAV_N - 1))

func _nearest_free(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if not g.is_point_solid(c):
		return c
	for r in range(1, 40):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var q := Vector2i(c.x + dx, c.y + dz)
				if q.x < 0 or q.y < 0 or q.x >= Cfg.NAV_N or q.y >= Cfg.NAV_N:
					continue
				if not g.is_point_solid(q):
					return q
	return c

func line_clear(g: AStarGrid2D, a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / 8.0) + 1
	for s in range(steps + 1):
		if g.is_point_solid(_cell(a + d * (float(s) / steps))):
			return false
	return true

## Posição transitável mais próxima de p (centro de célula) para o tipo dado.
func nearest_passable(p: Vector2, chariot: bool) -> Vector2:
	var g := nav_car if chariot else nav_foot
	var c := _cell(p)
	if not g.is_point_solid(c):
		return p
	return g.get_point_position(_nearest_free(g, c))

## Mesmo que find_path, tratando as células `cells` (Vector2i) como bloqueadas durante a busca.
func find_path_blocked(a: Vector2, b: Vector2, chariot: bool, cells: Array) -> PackedVector2Array:
	var g := nav_car if chariot else nav_foot
	var marked: Array = []
	for c: Vector2i in cells:
		if not g.is_point_solid(c):
			g.set_point_solid(c, true)
			marked.append(c)
	var out := find_path(a, b, chariot)
	for c: Vector2i in marked:
		g.set_point_solid(c, false)
	return out

## Caminho (sem o ponto inicial) de a até b; termina no ponto alcançável mais próximo.
func find_path(a: Vector2, b: Vector2, chariot: bool) -> PackedVector2Array:
	var g := nav_car if chariot else nav_foot
	var out := PackedVector2Array()
	if line_clear(g, a, b):
		out.append(b)
		return out
	var ca := _nearest_free(g, _cell(a))
	var cb0 := _cell(b)
	var cb := _nearest_free(g, cb0)
	var pts := g.get_point_path(ca, cb, true)
	if pts.is_empty():
		return out
	if cb == cb0 and pts[pts.size() - 1].distance_to(g.get_point_position(cb)) < 1.0:
		pts[pts.size() - 1] = b
	# simplificação por linha de visada
	var cur := a
	var i := 0
	while i < pts.size():
		var far := i
		var k := mini(pts.size() - 1, i + 24)
		while k > i:
			if line_clear(g, cur, pts[k]):
				far = k
				break
			k -= 1
		out.append(pts[far])
		cur = pts[far]
		i = far + 1
	return out
