extends RefCounted
## Gera a malha do terreno (cores por vértice) e a linha da área controlável.

const Cfg = preload("res://scripts/config.gd")

static func build(terrain) -> ArrayMesh:
	var n := Cfg.HM_N
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()   # x: parede rochosa, y: planura (vegetação), ver shaders/terrain.gdshader
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	uvs.resize(n * n)
	var h: PackedFloat32Array = terrain.h
	var gx: PackedFloat32Array = terrain.gx
	var gz: PackedFloat32Array = terrain.gz
	var sl: PackedFloat32Array = terrain.slope
	var hmax: float = terrain.hmax
	var low := Color(0.44, 0.5, 0.29)
	var high := Color(0.8, 0.74, 0.56)
	var steep := Color(0.58, 0.48, 0.36)
	var rock := Color(0.36, 0.34, 0.33)
	var ctrl := Cfg.CONTROL_HALF
	for j in n:
		var z := (j - 200) * Cfg.HM_CELL
		for i in n:
			var k := j * n + i
			var x := (i - 200) * Cfg.HM_CELL
			verts[k] = Vector3(x, h[k], z)
			norms[k] = Vector3(-gx[k], 1.0, -gz[k]).normalized()
			var c := low.lerp(high, h[k] / hmax)
			var s := sl[k]
			if s > Cfg.SLOPE_IMPASS:
				c = rock
			elif s > Cfg.SLOPE_CHARIOT:
				c = c.lerp(steep, clampf((s - Cfg.SLOPE_CHARIOT) / 12.0, 0.25, 0.9))
			var noise := 0.94 + 0.12 * float((i * 73856093 ^ j * 19349663) & 255) / 255.0
			if absf(x) > ctrl or absf(z) > ctrl:
				noise *= 0.72
			cols[k] = Color(c.r, c.g, c.b, noise)
			uvs[k] = Vector2(smoothstep(Cfg.SLOPE_ROCK - 2.0, Cfg.SLOPE_ROCK + 2.0, s),
				1.0 - smoothstep(5.0, 11.0, s))
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var w := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[w] = a
			idx[w + 1] = a + 1
			idx[w + 2] = a + n
			idx[w + 3] = a + 1
			idx[w + 4] = a + n + 1
			idx[w + 5] = a + n
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/terrain.gdshader")
	mesh.surface_set_material(0, m)
	return mesh

## Camada de depuração do acesso: cobre o relevo com cores por nó do heightmap, conforme
## os declives máximos atuais do terreno: vermelho onde nem soldados a pé passam, amarelo
## onde só eles passam (carros não), verde onde todos passam.
static func build_access(terrain) -> ArrayMesh:
	var n := Cfg.HM_N
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	cols.resize(n * n)
	var h: PackedFloat32Array = terrain.h
	var sl: PackedFloat32Array = terrain.slope
	var foot: float = terrain.lim_foot
	var car: float = terrain.lim_car
	var red := Color(0.95, 0.12, 0.1, 0.6)
	var yellow := Color(1.0, 0.85, 0.1, 0.55)
	var green := Color(0.15, 0.85, 0.2, 0.4)
	for j in n:
		var z := (j - 200) * Cfg.HM_CELL
		for i in n:
			var k := j * n + i
			verts[k] = Vector3((i - 200) * Cfg.HM_CELL, h[k] + 0.4, z)
			var s := sl[k]
			cols[k] = red if s > foot else (yellow if s > car else green)
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var w := 0
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx[w] = a
			idx[w + 1] = a + 1
			idx[w + 2] = a + n
			idx[w + 3] = a + 1
			idx[w + 4] = a + n + 1
			idx[w + 5] = a + n
			w += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh

## Faixa translúcida sobre o relevo, de z0 a z1, na largura da área controlável, com uma
## borda mais forte na linha `edge_z` (o limite do setor voltado para o centro do mapa).
## Os vértices caem nos nós do heightmap (10 m), para a faixa acompanhar o chão sem afundar.
static func build_sector(terrain, z0: float, z1: float, edge_z: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Cfg.CONTROL_HALF
	var step := Cfg.HM_CELL
	var nx := int(round(2.0 * c / step))
	var nz := int(round((z1 - z0) / step))
	var lift := 0.6
	st.set_color(col)
	for iz in nz:
		var za := z0 + iz * step
		var zb := za + step
		for ix in nx:
			var xa := -c + ix * step
			var xb := xa + step
			var v := [Vector3(xa, terrain.height(xa, za) + lift, za), Vector3(xb, terrain.height(xb, za) + lift, za),
				Vector3(xb, terrain.height(xb, zb) + lift, zb), Vector3(xa, terrain.height(xa, zb) + lift, zb)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[k])
	# borda: faixa de 5 m de largura, opaca
	var edge := Color(col.r, col.g, col.b, 0.9)
	st.set_color(edge)
	for ix in nx:
		var xa := -c + ix * step
		var xb := xa + step
		var q := [Vector3(xa, terrain.height(xa, edge_z) + lift + 0.2, edge_z - 2.5),
			Vector3(xb, terrain.height(xb, edge_z) + lift + 0.2, edge_z - 2.5),
			Vector3(xb, terrain.height(xb, edge_z) + lift + 0.2, edge_z + 2.5),
			Vector3(xa, terrain.height(xa, edge_z) + lift + 0.2, edge_z + 2.5)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[k])
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh

static func build_border(terrain) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Cfg.CONTROL_HALF
	var corners := [Vector2(-c, -c), Vector2(c, -c), Vector2(c, c), Vector2(-c, c)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x) * 2.5
		var steps := int(a.distance_to(b) / 10.0)
		for s in steps:
			var p0 := a + dir * (s * 10.0)
			var p1 := a + dir * ((s + 1) * 10.0)
			var q := [p0 - nrm, p0 + nrm, p1 + nrm, p1 - nrm]
			var v: Array = []
			for p: Vector2 in q:
				v.append(Vector3(p.x, terrain.height(p.x, p.y) + 0.8, p.y))
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[k])
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.92, 0.6, 0.85)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	return mesh
