extends RefCounted
## Gera a malha do terreno (cores por vértice) e a linha da área controlável.

const Cfg = preload("res://scripts/config.gd")

static func build(terrain) -> ArrayMesh:
	var n := Cfg.HM_N
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
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
			cols[k] = Color(c.r * noise, c.g * noise, c.b * noise)
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
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
