extends Node3D
## Cena da batalha: monta o mundo, roda a simulação em passo fixo, desenha os
## soldados com MultiMesh e trata as ordens do jogador.

signal finished

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")
const TerrainData = preload("res://scripts/terrain_data.gd")
const TerrainMesh = preload("res://scripts/terrain_mesh.gd")
const BattleSim = preload("res://scripts/battle_sim.gd")
const AI = preload("res://scripts/ai_commander.gd")
const Models = preload("res://scripts/models.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const Hud = preload("res://scripts/ui/battle_hud.gd")

var army: Array = []          # [{type, men, general}]
var terrain: TerrainData
var sim: BattleSim
var ai: AI
var rig: CameraRig
var hud: Hud
var nodes: Array = []         # MultiMeshInstance3D por unidade
var bufs: Array = []          # PackedFloat32Array por unidade
var last_facing: Array = []
var view_c: Array = []        # pose (centro, frente) em que cada buffer foi gravado
var view_f: Array = []
var selected: Array = []
var ready_ok := false
var paused := false
var speed := 1.0
var acc := 0.0
var since_tick := 0.0
var tick_ms := 0.0
var rc_start := Vector2.ZERO
var rc_ground = null
var marker: MeshInstance3D
var marker_t := 0.0
var arrows: MultiMeshInstance3D
var arrow_list: Array = []    # [de3, para3, t, dur]
var ended := false

func _ready() -> void:
	var loading := Label.new()
	loading.text = "Carregando o relevo de Jerusalém..."
	loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var cl := CanvasLayer.new()
	cl.add_child(loading)
	add_child(cl)
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	cl.queue_free()
	ready_ok = true

func _build_world() -> void:
	terrain = TerrainData.new()
	terrain.load_map()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	var tm := MeshInstance3D.new()
	tm.mesh = TerrainMesh.build(terrain)
	add_child(tm)
	var bm := MeshInstance3D.new()
	bm.mesh = TerrainMesh.build_border(terrain)
	add_child(bm)

	sim = BattleSim.new()
	sim.init(terrain)
	var counts := {}
	for side in 2:
		for a: Dictionary in army:
			var is_gen: bool = a.general
			var u := sim.add_unit(side, a.type, a.men, is_gen)
			var key := "%d_%d" % [side, u.type]
			counts[key] = int(counts.get(key, 0)) + 1
			u.label = "%s %d (%s)" % [u.t.name, counts[key], Cfg.SIDE_NAMES[side]]
	sim.deploy(0, Vector2(-450, -50), Vector2(0, -1))
	sim.deploy(1, Vector2(-450, -850), Vector2(0, 1))
	sim.finalize()
	ai = AI.new()
	ai.init(sim, 1)

	var mat := Models.material()
	var meshes := {}
	for u: Unit in sim.units:
		var key := u.side * 10 + u.type
		if not meshes.has(key):
			var me := Models.build(u.type, u.side)
			me.surface_set_material(0, mat)
			meshes[key] = me
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key]
		mm.instance_count = u.cap
		var buf := PackedFloat32Array()
		buf.resize(u.cap * 12)
		for i in u.cap:
			buf[i * 12 + 5] = 1.0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 600, 4000))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		nodes.append(node)
		bufs.append(buf)
		last_facing.append(Vector2.ZERO)
		view_c.append(u.center)
		view_f.append(u.facing)

	# flechas / pedras (apenas visuais)
	var am := MultiMesh.new()
	am.transform_format = MultiMesh.TRANSFORM_3D
	var bx := BoxMesh.new()
	bx.size = Vector3(0.25, 0.25, 2.2)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.15, 0.12, 0.1)
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bx.material = amat
	am.mesh = bx
	am.instance_count = 240
	am.visible_instance_count = 0
	arrows = MultiMeshInstance3D.new()
	arrows.multimesh = am
	arrows.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 900, 4000))
	add_child(arrows)

	marker = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 14.0
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1, 0.9, 0.2)
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = mmat
	marker.mesh = cyl
	marker.visible = false
	add_child(marker)

	rig = CameraRig.new()
	rig.terrain = terrain
	add_child(rig)
	hud = Hud.new()
	hud.battle = self
	add_child(hud)
	_sync_view(true)

func _process(delta: float) -> void:
	if not ready_ok:
		return
	if not paused and sim.winner < 0:
		acc += delta * speed
		var steps := 0
		while acc >= Cfg.TICK and steps < 3:
			var t0 := Time.get_ticks_usec()
			ai.update(Cfg.TICK)
			sim.tick(Cfg.TICK)
			tick_ms = lerpf(tick_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)
			acc -= Cfg.TICK
			steps += 1
		if acc >= Cfg.TICK:
			acc = 0.0   # máquina lenta: o tempo do jogo desacelera, os soldados não diminuem
		if steps > 0:
			_sync_view(false)
			since_tick = acc
			_spawn_shots()
		else:
			since_tick += delta * speed
		# extrapolação visual entre ticks
		for k in nodes.size():
			var u: Unit = sim.units[k]
			if u.state == 0:
				(nodes[k] as Node3D).transform = _pose_xf(k, u, since_tick)
			elif u.state == 1:
				(nodes[k] as Node3D).position = Vector3(u.vel.x, 0.0, u.vel.y) * (since_tick + (sim.tick_n - u.rout_stamp) * Cfg.TICK)
	_update_arrows(delta * (0.0 if paused else speed))
	if marker_t > 0.0:
		marker_t -= delta
		marker.visible = marker_t > 0.0
	if sim.winner >= 0 and not ended:
		ended = true
		selected.clear()
		hud.show_result()

func _sync_view(force: bool) -> void:
	for k in nodes.size():
		var u: Unit = sim.units[k]
		if not (u.dirty or force):
			continue
		u.dirty = false
		var node: MultiMeshInstance3D = nodes[k]
		var mm := node.multimesh
		if u.n == 0:
			mm.visible_instance_count = 0
			continue
		var buf: PackedFloat32Array = bufs[k]
		bufs[k] = null   # evita cópia (copy-on-write) ao escrever
		var f := u.facing if u.state == 0 else u.flee_dir
		if f != last_facing[k]:
			last_facing[k] = f
			for i in u.cap:
				var ob := i * 12
				buf[ob] = -f.y
				buf[ob + 2] = -f.x
				buf[ob + 8] = f.x
				buf[ob + 10] = -f.y
		var s := u.start
		var o := 3
		view_c[k] = u.center
		view_f[k] = f
		if u.state == 0:
			# grava x/z do mundo com y = 0; a altura vem da transformação do nó
			# (plano tangente ao terreno), ver _pose_xf
			if u.formed:
				sim.materialize(u)
			var ps := sim.pos
			for i in range(s, s + u.n):
				var p := ps[i]
				buf[o] = p.x
				buf[o + 4] = 0.0
				buf[o + 8] = p.y
				o += 12
			node.transform = _pose_xf(k, u, 0.0)
		else:
			node.transform = Transform3D.IDENTITY
			var ps := sim.pos
			for i in range(s, s + u.n):
				var p := ps[i]
				buf[o] = p.x
				buf[o + 4] = terrain.height(p.x, p.y)
				buf[o + 8] = p.y
				o += 12
		mm.buffer = buf
		mm.visible_instance_count = u.n
		bufs[k] = buf

## Transformação do nó de uma unidade sob controle: leva a pose em que o buffer foi
## gravado até a pose atual (movimento rígido da formação) e assenta os soldados no
## plano tangente ao terreno. Assim, unidades em marcha não regravam o buffer.
func _pose_xf(k: int, u: Unit, ahead: float) -> Transform3D:
	var c1 := u.center + u.vel * ahead
	var c0: Vector2 = view_c[k]
	var th: float = (view_f[k] as Vector2).angle_to(u.facing)
	var g: Vector2 = terrain.grad_at(c1)
	var h1: float = terrain.height(c1.x, c1.y)
	var rx := Vector2(1, 0).rotated(th)
	var rz := Vector2(0, 1).rotated(th)
	var rc0 := c0.rotated(th)
	var b := Basis(Vector3(rx.x, g.dot(rx), rx.y), Vector3(0, 1, 0), Vector3(rz.x, g.dot(rz), rz.y))
	return Transform3D(b, Vector3(c1.x - rc0.x, h1 - g.dot(rc0), c1.y - rc0.y))

func _spawn_shots() -> void:
	for sh: Array in sim.shots:
		var a: Vector2 = sh[0]
		var b: Vector2 = sh[1]
		var a3 := Vector3(a.x, terrain.height(a.x, a.y) + 1.5, a.y)
		var b3 := Vector3(b.x, terrain.height(b.x, b.y) + 1.0, b.y)
		for k in 6:
			if arrow_list.size() >= 240:
				break
			var off := Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
			arrow_list.append([a3 + off, b3 + off * 1.3, 0.0, float(sh[2])])
	sim.shots.clear()

func _update_arrows(dt: float) -> void:
	var mm := arrows.multimesh
	var k := arrow_list.size() - 1
	while k >= 0:
		var a: Array = arrow_list[k]
		a[2] = float(a[2]) + dt
		if float(a[2]) >= float(a[3]):
			arrow_list.remove_at(k)
		k -= 1
	mm.visible_instance_count = arrow_list.size()
	for i in arrow_list.size():
		var a: Array = arrow_list[i]
		var f: float = float(a[2]) / float(a[3])
		var p0: Vector3 = a[0]
		var p1: Vector3 = a[1]
		var arc: float = p0.distance_to(p1) * 0.18
		var p := p0.lerp(p1, f) + Vector3(0, arc * 4.0 * f * (1.0 - f), 0)
		var f2 := minf(f + 0.03, 1.0)
		var pn := p0.lerp(p1, f2) + Vector3(0, arc * 4.0 * f2 * (1.0 - f2), 0)
		var tr := Transform3D(Basis.IDENTITY, p)
		if pn.distance_squared_to(p) > 0.0001:
			tr = tr.looking_at(pn, Vector3.UP)
		mm.set_instance_transform(i, tr)

# ------------------------------------------------------------------ entrada

func player_units() -> Array:
	var out: Array = []
	for u: Unit in sim.units:
		if u.side == 0:
			out.append(u)
	return out

func select_card(u: Unit, additive: bool) -> void:
	if u.state != 0:
		return
	if additive:
		if u in selected:
			selected.erase(u)
		else:
			selected.append(u)
	else:
		selected = [u]

func select_all() -> void:
	selected.clear()
	for u: Unit in sim.units:
		if u.side == 0 and u.state == 0:
			selected.append(u)

func _prune() -> void:
	selected = selected.filter(func(u): return u.state == 0)

func cmd_run_toggle() -> void:
	_prune()
	if selected.is_empty():
		return
	var run: bool = not (selected[0] as Unit).running
	for u: Unit in selected:
		u.running = run

func cmd_halt() -> void:
	_prune()
	for u: Unit in selected:
		sim.order_halt(u)

func cmd_fire_toggle() -> void:
	_prune()
	if selected.is_empty():
		return
	var v: bool = not (selected[0] as Unit).fire_at_will
	for u: Unit in selected:
		u.fire_at_will = v

func _unhandled_input(ev: InputEvent) -> void:
	if not ready_ok or ended:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			rig.zoom(0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			rig.zoom(1.14)
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var own := _own_banner_at(mb.position)
			if own != null:
				select_card(own, mb.shift_pressed or mb.ctrl_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				rc_start = mb.position
				rc_ground = rig.pick(mb.position)
			else:
				_issue_order(mb.position)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if k == KEY_R:
			cmd_run_toggle()
		elif k == KEY_H:
			cmd_halt()
		elif k == KEY_F:
			cmd_fire_toggle()
		elif k == KEY_P or k == KEY_SPACE:
			paused = not paused
		elif k == KEY_A and (ev as InputEventKey).ctrl_pressed:
			select_all()
		elif k == KEY_ESCAPE:
			selected.clear()

## Unidade própria cujo estandarte está sob o ponto da tela (retângulo 34 x 18).
func _own_banner_at(screen: Vector2) -> Unit:
	var best: Unit = null
	var bd := 1e9
	for u: Unit in sim.units:
		if u.side != 0 or u.state != 0:
			continue
		var sp = hud.banner_pos.get(u)
		if sp == null:
			continue
		var d: Vector2 = (screen - (sp as Vector2)).abs()
		if d.x <= 17.0 and d.y <= 9.0 and d.length() < bd:
			bd = d.length()
			best = u
	return best

func _enemy_at(screen: Vector2, ground) -> Unit:
	var best: Unit = null
	var bd := 26.0
	for u: Unit in sim.units:
		if u.side == 0 or u.state == 2:
			continue
		var sp = hud.banner_pos.get(u)
		if sp != null and (sp as Vector2).distance_to(screen) < bd:
			bd = (sp as Vector2).distance_to(screen)
			best = u
	if best == null and ground != null:
		var gd := 1e9
		for u: Unit in sim.units:
			if u.side == 0 or u.state == 2:
				continue
			var d: float = u.center.distance_to(ground)
			if d < u.brad * 0.8 and d < gd:
				gd = d
				best = u
	return best

func _issue_order(release: Vector2) -> void:
	_prune()
	if selected.is_empty():
		return
	var enemy := _enemy_at(rc_start, rc_ground)
	if enemy != null:
		for u: Unit in selected:
			sim.order_attack(u, enemy, u.running)
		_flash(enemy.center)
		return
	if rc_ground == null:
		return
	var dest: Vector2 = rc_ground
	var facing := Vector2.ZERO
	if rc_start.distance_to(release) > 14.0:
		var g2 = rig.pick(release)
		if g2 != null and (g2 as Vector2).distance_to(dest) > 3.0:
			facing = ((g2 as Vector2) - dest).normalized()
	var cen := Vector2.ZERO
	for u: Unit in selected:
		cen += u.center
	cen /= selected.size()
	for u: Unit in selected:
		var off := (u.center - cen).limit_length(350.0)
		sim.order_move(u, dest + off, facing, u.running)
	var lim := Cfg.CONTROL_HALF - 25.0
	_flash(Vector2(clampf(dest.x, -lim, lim), clampf(dest.y, -lim, lim)))

func _flash(p: Vector2) -> void:
	marker.position = Vector3(p.x, terrain.height(p.x, p.y) + 7.0, p.y)
	marker.visible = true
	marker_t = 1.2

func leave() -> void:
	finished.emit()
