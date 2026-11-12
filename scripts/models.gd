extends RefCounted
## Modelos simplificados (caixas, sem animação) para cada tipo de unidade.
## Frente do modelo = -Z.

const Cfg = preload("res://scripts/config.gd")

const SIDE_COLORS := [Color(0.16, 0.32, 0.78), Color(0.72, 0.14, 0.11)]
const SKIN := Color(0.78, 0.6, 0.45)
const BRONZE := Color(0.72, 0.55, 0.22)
const WOOD := Color(0.42, 0.29, 0.16)
const HORSE := Color(0.36, 0.24, 0.15)
const LINEN := Color(0.85, 0.8, 0.68)

static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(0, 0, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1)],
		[Vector3(0, 0, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)],
		[Vector3(-1, 0, 0), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)],
		[Vector3(1, 0, 0), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)],
		[Vector3(0, 1, 0), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
	]
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		for k: int in [1, 2, 3, 1, 3, 4]:
			st.set_normal(nrm)
			st.set_color(col)
			st.add_vertex(c + (f[k] as Vector3) * h)

static func _man(st: SurfaceTool, off: Vector3, tunic: Color) -> void:
	_box(st, off + Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.32), tunic)
	_box(st, off + Vector3(0, 1.64, 0), Vector3(0.26, 0.28, 0.26), SKIN)

static func build(type: int, side: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sc: Color = SIDE_COLORS[side]
	match type:
		Cfg.HEAVY:
			_man(st, Vector3.ZERO, sc.darkened(0.15))
			_box(st, Vector3(0, 1.82, 0), Vector3(0.3, 0.1, 0.3), BRONZE)
			_box(st, Vector3(-0.08, 0.95, -0.24), Vector3(0.62, 0.95, 0.08), BRONZE)
			_box(st, Vector3(0.32, 1.3, -0.1), Vector3(0.05, 2.6, 0.05), WOOD)
		Cfg.LIGHT:
			_man(st, Vector3.ZERO, sc)
			_box(st, Vector3(-0.12, 1.0, -0.22), Vector3(0.4, 0.4, 0.06), WOOD)
			_box(st, Vector3(0.32, 1.1, -0.1), Vector3(0.05, 1.8, 0.05), WOOD)
		Cfg.SLINGER:
			_man(st, Vector3.ZERO, sc.lerp(LINEN, 0.55))
			_box(st, Vector3(0.34, 1.25, 0.1), Vector3(0.05, 0.05, 0.7), WOOD)
		Cfg.ARCHER:
			_man(st, Vector3.ZERO, sc.lerp(Color(0.25, 0.4, 0.2), 0.5))
			_box(st, Vector3(-0.3, 1.1, -0.28), Vector3(0.05, 1.3, 0.05), WOOD)
		Cfg.CHARIOT:
			_box(st, Vector3(0, 0.75, 0.3), Vector3(1.3, 0.5, 1.3), sc.darkened(0.1))
			_box(st, Vector3(-0.72, 0.5, 0.35), Vector3(0.1, 1.0, 1.0), WOOD)
			_box(st, Vector3(0.72, 0.5, 0.35), Vector3(0.1, 1.0, 1.0), WOOD)
			_box(st, Vector3(0, 0.75, -0.9), Vector3(0.08, 0.08, 1.4), WOOD)
			_box(st, Vector3(-0.38, 0.85, -1.9), Vector3(0.42, 1.0, 1.5), HORSE)
			_box(st, Vector3(0.38, 0.85, -1.9), Vector3(0.42, 1.0, 1.5), HORSE.lightened(0.15))
			_box(st, Vector3(-0.38, 1.5, -2.7), Vector3(0.22, 0.5, 0.4), HORSE)
			_box(st, Vector3(0.38, 1.5, -2.7), Vector3(0.22, 0.5, 0.4), HORSE.lightened(0.15))
			_man(st, Vector3(-0.3, 1.0, 0.3), sc)
			_man(st, Vector3(0.3, 1.0, 0.3), sc.lerp(LINEN, 0.4))
	return st.commit()

static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
