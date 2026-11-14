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
const SHOT_MAX := 480       # feixes simultâneos por tipo (flechas / pedras)
const SHOTS_PER_VOLLEY := 10
const PAIN_GAP := 1.6            # s médios entre gritos de dor da mesma unidade
const VIEW_REFRESH_DIST := 3.0   # m andados até regravar as alturas dos soldados
const VIEW_REFRESH_ANG := 0.08   # rad girados até regravar
const BLOOD_GROW_T := 5.0   # segundos para a mancha chegar ao tamanho final
const BLOOD_START := 0.15   # fração inicial do tamanho
const Hud = preload("res://scripts/ui/battle_hud.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Settings = preload("res://scripts/settings.gd")

var army: Array = []          # [{type, men, general}]
var sun: DirectionalLight3D
var env: Environment
var day: Dictionary
var hour := Cfg.HOUR_DEFAULT  # hora do dia escolhida no preparo
var terrain: TerrainData
var sim: BattleSim
var ai: AI
var rig: CameraRig
var hud: Hud
var sfx
var nodes: Array = []         # MultiMeshInstance3D por unidade
var bufs: Array = []          # PackedFloat32Array por unidade
var last_facing: Array = []
var view_c: Array = []        # pose (centro, frente) em que cada buffer foi gravado
var view_f: Array = []
var pain_n: Array = []        # homens vivos na última olhada, por unidade (gritos de dor)
var pain_t: Array = []        # tempo até a unidade poder gritar de novo
var selected: Array = []
var sel_anchor = null   # última unidade selecionada sem Shift (início do intervalo)
var ready_ok := false
var paused := false
var deploying := true          # fase de posicionamento: a simulação não corre e as ordens só posicionam
var access_node: MeshInstance3D   # camada de depuração do acesso do terreno
var sector_nodes: Array = []   # faixas dos setores no chão, visíveis só no posicionamento
var speed := 1.0
var acc := 0.0
var since_tick := 0.0
var tick_ms := 0.0
var rc_start := Vector2.ZERO
var rc_ground = null
var rc_held := false   # botão direito pressionado (ordem em andamento)
var lc_held := false   # botão esquerdo pressionado no mapa (clique ou retângulo de seleção)
var lc_start := Vector2.ZERO
const BOX_MIN := 6.0   # px arrastados até o clique virar retângulo de seleção
var marker: MeshInstance3D
var marker_t := 0.0
var arrows: MultiMeshInstance3D
var arrow_list: Array = []    # [de3, para3, t, dur]
var stones: MultiMeshInstance3D
var stone_list: Array = []    # [de3, para3, t, dur]
var ended := false
var fight_t := 0.0   # intervalo até o próximo som de combate
var move_snd_t := 0.0  # intervalo até reatribuir os laços de marcha
var corpses := {}             # lado * 10 + tipo -> [MultiMesh, total já desenhado]
var blood_mm: MultiMesh
var blood_n := 0
var blood_grow: Array = []    # manchas em crescimento: [slot, basis final, origem, idade]

func _ready() -> void:
	Settings.load_file()
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

## O jogador desiste: a vitória vai para os filisteus.
func surrender() -> void:
	if ended or sim.winner >= 0:
		return
	paused = false
	sim.surrender(0)

## Fim do posicionamento: some com os setores e a simulação começa a correr.
func start_battle() -> void:
	if not deploying:
		return
	deploying = false
	for n: Node in sector_nodes:
		n.queue_free()
	sector_nodes.clear()
	selected.clear()
	sfx.play_any(["inicio-bom", "inicio-medio", "inicio-ruim"])

## Muda a hora do dia: posição e cor do sol, céu e luz ambiente.
func set_hour(h: float) -> void:
	hour = h
	day = Daylight.at(h)
	env.background_color = day.sky
	env.ambient_light_color = (day.sky as Color).lerp(Color.WHITE, 0.7)
	sun.light_color = day.sun_color
	sun.light_energy = day.sun_energy
	sun.transform = Transform3D(Basis.looking_at(-(day.to_sun as Vector3), Vector3.UP), Vector3.ZERO)
	env.ambient_light_energy = day.ambient_energy if Settings.sun else 1.0

## Aplica as configurações de exibição (sol, sombras) à cena.
func apply_settings() -> void:
	sun.visible = Settings.sun
	sun.shadow_enabled = Settings.shadows
	env.ambient_light_energy = day.ambient_energy if Settings.sun else 1.0
	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Settings.unit_shadows 		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for n: GeometryInstance3D in nodes:
		n.cast_shadow = cast
	_show_access(Settings.debug_access)

## Depuração: mostra ou esconde a camada que pinta o terreno conforme quem consegue passar.
func _show_access(on: bool) -> void:
	if on and access_node == null:
		access_node = MeshInstance3D.new()
		access_node.mesh = TerrainMesh.build_access(terrain)
		access_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(access_node)
	if access_node != null:
		access_node.visible = on

## Muda os declives máximos de soldados a pé e de carros (tela de configurações): refaz
## as grades de navegação e, se estiver visível, a camada de acesso.
func set_slope_limits(foot: float, car: float) -> void:
	terrain.set_limits(foot, car)
	if access_node != null:
		access_node.mesh = TerrainMesh.build_access(terrain)

func _build_world() -> void:
	terrain = TerrainData.new()
	terrain.load_map()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 2500.0
	sun.directional_shadow_split_1 = 0.15
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	set_hour(hour)
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
	sim.deploy_side(0)
	sim.deploy_side(1)
	sim.finalize()
	# setores de posicionamento: azul para Israel (sul), vermelho para os filisteus (norte)
	var sh := Cfg.SECTOR_HALF
	var ch := Cfg.CONTROL_HALF
	for spec: Array in [[sh, ch, sh, Color(0.25, 0.5, 1.0, 0.16)], [-ch, -sh, -sh, Color(1.0, 0.3, 0.25, 0.13)]]:
		var sm := MeshInstance3D.new()
		sm.mesh = TerrainMesh.build_sector(terrain, spec[0], spec[1], spec[2], spec[3])
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sm)
		sector_nodes.append(sm)
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
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(node)
		nodes.append(node)
		bufs.append(buf)
		last_facing.append(Vector2.ZERO)
		view_c.append(u.center)
		view_f.append(u.facing)
		pain_n.append(u.n)
		pain_t.append(0.0)

	# poças de sangue no chão (um disco achatado por morte)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 14
	disc.rings = 1
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.36, 0.03, 0.03, 0.72)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material = bmat
	blood_mm = MultiMesh.new()
	blood_mm.transform_format = MultiMesh.TRANSFORM_3D
	blood_mm.mesh = disc
	blood_mm.instance_count = Cfg.BLOOD_CAP
	blood_mm.visible_instance_count = 0
	var bn := MultiMeshInstance3D.new()
	bn.multimesh = blood_mm
	bn.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 600, 4000))
	bn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bn)
	# corpos deitados: o mesmo modelo do soldado, tombado
	for k: int in meshes:
		var cm := MultiMesh.new()
		cm.transform_format = MultiMesh.TRANSFORM_3D
		cm.mesh = meshes[k]
		cm.instance_count = Cfg.CORPSE_CAP
		cm.visible_instance_count = 0
		var cn := MultiMeshInstance3D.new()
		cn.multimesh = cm
		cn.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 600, 4000))
		cn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cn)
		corpses[k] = [cm, 0]
	sim.record_deaths = true
	apply_settings()

	# flechas / pedras (apenas visuais)
	var am := MultiMesh.new()
	am.transform_format = MultiMesh.TRANSFORM_3D
	# cada instância é um feixe de 4 projéteis finos (uma só malha, um só desenho)
	var bx := BoxMesh.new()
	bx.size = Vector3(0.09, 0.09, 2.2)
	var st := SurfaceTool.new()
	for o: Vector3 in [Vector3(-0.6, 0.25, 0.0), Vector3(0.6, -0.2, 0.5), Vector3(-0.2, -0.5, -0.6), Vector3(0.3, 0.55, 0.9)]:
		st.append_from(bx, 0, Transform3D(Basis.IDENTITY, o))
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.15, 0.12, 0.1)
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bundle := st.commit()
	bundle.surface_set_material(0, amat)
	am.mesh = bundle
	am.instance_count = SHOT_MAX
	am.visible_instance_count = 0
	arrows = MultiMeshInstance3D.new()
	arrows.multimesh = am
	arrows.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 900, 4000))
	add_child(arrows)

	# pedras das fundas: 10 pontos cinzas por instância
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	var pt := BoxMesh.new()
	pt.size = Vector3(0.15, 0.15, 0.15)
	var sst := SurfaceTool.new()
	for i in 10:
		var po := Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8), randf_range(-2.2, 2.2))
		sst.append_from(pt, 0, Transform3D(Basis.IDENTITY, po))
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.55, 0.57)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sbundle := sst.commit()
	sbundle.surface_set_material(0, smat)
	sm.mesh = sbundle
	sm.instance_count = SHOT_MAX
	sm.visible_instance_count = 0
	stones = MultiMeshInstance3D.new()
	stones.multimesh = sm
	stones.custom_aabb = arrows.custom_aabb
	add_child(stones)

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
	# começa olhando a linha de frente de Israel no seu setor
	rig.target = (Cfg.DEPLOY_ORIGIN[0] as Vector2) - Vector2(0, 180)
	add_child(rig)
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	hud.battle = self
	add_child(hud)
	_sync_view(true)

func _process(delta: float) -> void:
	if not ready_ok:
		return
	if not paused and not deploying and sim.winner < 0:
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
			_spawn_corpses()
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
	_event_sounds()
	_pain_sounds(delta * speed)
	_combat_sound(delta)
	_move_sounds(delta)
	if marker_t > 0.0:
		marker_t -= delta
		marker.visible = marker_t > 0.0
	if sim.winner >= 0 and not ended:
		ended = true
		selected.clear()
		hud.show_result()
		sfx.play("win" if sim.winner == 0 else "lose")

## Voz da ordem de ataque: sorteia uma das unidades selecionadas. Carros, arqueiros e
## infantaria pesada têm voz própria em 10% das vezes; as demais usam "ataquem" em 10%.
## Nas outras vezes toca o som de combate normal.
func _attack_sound() -> void:
	var u: Unit = selected[randi() % selected.size()]
	var own := {Cfg.CHARIOT: "carruagens", Cfg.ARCHER: "arqueiros", Cfg.HEAVY: "infantaria-pesada"}
	var voice: String = own.get(u.type, "ataquem")
	sfx.play(voice if randf() < 0.1 else "sword")

## Sons de marcha: passos das unidades a pé e cascos e rodas dos carros. A cada 0,25 s
## os laços se prendem às unidades em movimento (marchando ou em fuga, de qualquer lado)
## mais perto da câmera, Sfx.LOOP_PLAYERS por tipo. Correndo, o laço toca mais rápido;
## unidades maiores soam mais alto.
func _move_sounds(delta: float) -> void:
	if paused or ended or deploying:
		sfx.stop_loops()
		return
	move_snd_t -= delta
	if move_snd_t > 0.0:
		return
	move_snd_t = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var foot: Array = []
	var cars: Array = []
	for u: Unit in sim.units:
		if u.n == 0 or not (u.state == 1 or (u.state == 0 and not u.path.is_empty())):
			continue
		var p := _unit_pos3(u)
		var item := [eye.distance_squared_to(p), p, u]
		(cars if u.type == Cfg.CHARIOT else foot).append(item)
	for pair in [["passos", foot], ["carros", cars]]:
		var list: Array = pair[1]
		list.sort_custom(func(a, b): return a[0] < b[0])
		var srcs: Array = []
		for i in mini(list.size(), Sfx.LOOP_PLAYERS):
			var u: Unit = list[i][2]
			var fast := u.running or u.state == 1
			var vol := linear_to_db(clampf(u.men() / 150.0, 0.3, 1.0)) - 4.0
			srcs.append([list[i][1], vol, 1.25 if fast else 1.0])
		sfx.set_loop(pair[0], srcs)

## Ponto da unidade no mundo, para os sons posicionados.
func _unit_pos3(u: Unit) -> Vector3:
	return Vector3(u.center.x, terrain.height(u.center.x, u.center.y) + 2.0, u.center.y)

## Vozes dos eventos da simulação (pânico das tropas do jogador), vindas da unidade.
func _event_sounds() -> void:
	for e: Array in sim.events:
		var u: Unit = e[1]
		if e[0] == "rout" and u.side == 0:
			var at := _unit_pos3(u)
			if u.is_general:
				sfx.play_any_at(["fuga-general", "fuga-general2"], at, 4.0)
			else:
				sfx.play_any_at(["fuga1", "fuga2"], at, 4.0)
	sim.events.clear()

## Gritos de dor nas unidades que perderam homens desde a última olhada. Cada unidade
## grita no máximo a cada PAIN_GAP s; mais baixas de uma vez, grito mais alto.
func _pain_sounds(delta: float) -> void:
	for k in sim.units.size():
		var u: Unit = sim.units[k]
		var lost: int = pain_n[k] - u.n
		pain_n[k] = u.n
		pain_t[k] = float(pain_t[k]) - delta
		if lost <= 0 or float(pain_t[k]) > 0.0 or paused:
			continue
		if u.state == 2 and u.n == 0 and lost > 3:
			continue   # fugitivos que saíram do mapa: somem de uma vez, sem dor
		pain_t[k] = randf_range(PAIN_GAP * 0.6, PAIN_GAP * 1.4)
		sfx.play_any_at(Sfx.PAIN, _unit_pos3(u), -6.0 + minf(lost, 6) * 1.5, randf_range(0.9, 1.12))

## O general tenta parar a debandada (uma vez por minuto).
func cmd_rally() -> void:
	if deploying:
		return
	var g: Unit = null
	for u: Unit in sim.units:
		if u.side == 0 and u.is_general:
			g = u
	if g == null or not g.general_alive or g.state != 0:
		sim.messages.append(["O general não pode reunir as tropas agora.", 0])
		return
	if not sim.rally(g):
		sim.messages.append(["O general só poderá reunir as tropas de novo em %d s." % int(ceil(g.rally_ready - sim.time)), 0])
		return
	sfx.play("reunir")

## Choques de armas durante o corpo a corpo: um som sorteado a cada intervalo curto,
## mais alto quanto mais unidades estiverem em contato.
func _combat_sound(delta: float) -> void:
	if paused or ended:
		return
	fight_t -= delta
	if fight_t > 0.0:
		return
	var fighting: Array = []
	for u: Unit in sim.units:
		if u.state == 0 and u.contacts > 0:
			fighting.append(u)
	if fighting.is_empty():
		return
	# o choque sai de uma das unidades em combate, sorteada; com mais combates, mais choques
	var u: Unit = fighting[randi() % fighting.size()]
	sfx.play_at("choque%d" % (1 + randi() % 6), _unit_pos3(u), -6.0 + minf(u.contacts, 30) * 0.2, randf_range(0.93, 1.07))
	fight_t = randf_range(0.35, 0.8) / sqrt(minf(fighting.size(), 9))

func _sync_view(force: bool) -> void:
	for k in nodes.size():
		var u: Unit = sim.units[k]
		if not (u.dirty or force or _view_stale(k, u)):
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
			# grava x/z do mundo; a transformação do nó põe a unidade no plano tangente ao
			# terreno (ver _pose_xf) e y guarda quanto o chão de cada soldado sobe ou desce
			# em relação a esse plano, para ninguém afundar no relevo curvo
			if u.formed:
				sim.materialize(u)
			var c0 := u.center
			var h0 := terrain.height(c0.x, c0.y)
			var g0: Vector2 = terrain.grad_at(c0)
			var ps := sim.pos
			for i in range(s, s + u.n):
				var p := ps[i]
				buf[o] = p.x
				buf[o + 4] = terrain.height(p.x, p.y) - h0 - g0.dot(p - c0)
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

## Desenha os soldados mortos neste intervalo: corpo deitado e poça de sangue no chão.
## Eles não existem na simulação, então não bloqueiam nem são atingidos.
func _spawn_corpses() -> void:
	var n := sim.death_pos.size()
	if n == 0:
		return
	for i in n:
		var p: Vector2 = sim.death_pos[i]
		var key: int = sim.death_key[i]
		var h := terrain.height(p.x, p.y)
		var yaw := randf() * TAU
		var body: Basis
		var lift := 0.3
		if key % 10 == Cfg.CHARIOT:
			body = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.45)   # carro tombado de lado
			lift = 0.8
		else:
			body = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
		var c: Array = corpses[key]
		var cm: MultiMesh = c[0]
		cm.set_instance_transform(c[1] % Cfg.CORPSE_CAP, Transform3D(body, Vector3(p.x, h + lift, p.y)))
		c[1] += 1
		cm.visible_instance_count = mini(c[1], Cfg.CORPSE_CAP)
		var g := terrain.grad_at(p)
		var r := randf_range(1.4, 2.4)
		var bb := Basis(Vector3(r, r * g.x, 0), Vector3(0, 1, 0), Vector3(0, r * g.y, r))
		var slot := blood_n % Cfg.BLOOD_CAP
		var bo := Vector3(p.x, h + 0.15, p.y)
		blood_mm.set_instance_transform(slot, Transform3D(_blood_basis(bb, BLOOD_START), bo))
		blood_grow.append([slot, bb, bo, 0.0])
		blood_n += 1
	blood_mm.visible_instance_count = mini(blood_n, Cfg.BLOOD_CAP)
	sim.death_pos.clear()
	sim.death_key.clear()

## Transformação do nó de uma unidade sob controle: leva a pose em que o buffer foi
## gravado até a pose atual (movimento rígido da formação) e assenta os soldados no
## plano tangente ao terreno. Assim, unidades em marcha não regravam o buffer.
## A unidade formada andou ou girou tanto desde a última gravação do buffer que as alturas
## por soldado (relativas ao plano tangente) já não batem com o chão: regrava.
func _view_stale(k: int, u: Unit) -> bool:
	if u.state != 0 or u.n == 0:
		return false
	if u.center.distance_squared_to(view_c[k]) > VIEW_REFRESH_DIST * VIEW_REFRESH_DIST:
		return true
	return absf((view_f[k] as Vector2).angle_to(u.facing)) > VIEW_REFRESH_ANG

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
		var sling := int(sh[3]) == Cfg.SLINGER
		sfx.play_at("fundas" if sling else "flechas", a3, -2.0, randf_range(0.92, 1.08))
		var lst: Array = stone_list if sling else arrow_list
		for k in SHOTS_PER_VOLLEY:
			if lst.size() >= SHOT_MAX:
				break
			var off := Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
			lst.append([a3 + off, b3 + off * 1.3, 0.0, float(sh[2])])
	sim.shots.clear()

## Escala só o plano da mancha (x e z); a espessura (y) fica fixa.
func _blood_basis(bb: Basis, s: float) -> Basis:
	return Basis(bb.x * s, bb.y, bb.z * s)

## Faz as manchas recentes crescerem até o tamanho final em BLOOD_GROW_T segundos.
func _update_blood(dt: float) -> void:
	var k := blood_grow.size() - 1
	while k >= 0:
		var e: Array = blood_grow[k]
		e[3] = float(e[3]) + dt
		var f := minf(float(e[3]) / BLOOD_GROW_T, 1.0)
		var s := BLOOD_START + (1.0 - BLOOD_START) * (1.0 - (1.0 - f) * (1.0 - f))
		blood_mm.set_instance_transform(int(e[0]), Transform3D(_blood_basis(e[1], s), e[2]))
		if f >= 1.0:
			blood_grow.remove_at(k)
		k -= 1

func _update_arrows(dt: float) -> void:
	_update_blood(dt)
	_update_shot_list(arrows.multimesh, arrow_list, dt)
	_update_shot_list(stones.multimesh, stone_list, dt)

func _update_shot_list(mm: MultiMesh, list: Array, dt: float) -> void:
	var k := list.size() - 1
	while k >= 0:
		var a: Array = list[k]
		a[2] = float(a[2]) + dt
		if float(a[2]) >= float(a[3]):
			list.remove_at(k)
		k -= 1
	mm.visible_instance_count = list.size()
	for i in list.size():
		var a: Array = list[i]
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
	sfx.play("click", -4.0)
	if u.state != 0:
		return
	var shift := Input.is_key_pressed(KEY_SHIFT)
	if shift and sel_anchor != null and (sel_anchor as Unit).state == 0:
		# Shift: seleciona todos os cards entre a âncora e a unidade clicada
		var all := player_units()
		var a := all.find(sel_anchor)
		var b := all.find(u)
		if a >= 0 and b >= 0:
			for i in range(mini(a, b), maxi(a, b) + 1):
				var o: Unit = all[i]
				if o.state == 0 and not (o in selected):
					selected.append(o)
			return
	if additive:
		if u in selected:
			selected.erase(u)
		else:
			selected.append(u)
	else:
		selected = [u]
	sel_anchor = u

func select_all() -> void:
	sfx.play("click", -4.0)
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
	sfx.play("correr" if run else "andar")

func cmd_halt() -> void:
	_prune()
	for u: Unit in selected:
		sim.order_halt(u)
	if not selected.is_empty():
		sfx.play("parar")

func cmd_fire_toggle() -> void:
	sfx.play("menu", -6.0)
	_prune()
	if selected.is_empty():
		return
	var v: bool = not (selected[0] as Unit).fire_at_will
	for u: Unit in selected:
		u.fire_at_will = v

## Troca a postura das selecionadas: defensiva -> neutra -> agressiva -> defensiva.
## Todas recebem a postura seguinte à da primeira.
func cmd_stance_cycle() -> void:
	sfx.play("menu", -6.0)
	_prune()
	if selected.is_empty():
		return
	var v: int = ((selected[0] as Unit).stance + 1) % 3
	for u: Unit in selected:
		u.stance = v

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
			lc_held = true
			lc_start = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				rc_start = mb.position
				rc_ground = rig.pick(mb.position)
				rc_held = true
			else:
				rc_held = false
				_issue_order(mb.position)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if k == KEY_R:
			cmd_run_toggle()
		elif k == KEY_G:
			cmd_rally()
		elif k == KEY_H:
			cmd_halt()
		elif k == KEY_F:
			cmd_fire_toggle()
		elif k == KEY_T:
			cmd_stance_cycle()
		elif k == KEY_P or k == KEY_SPACE:
			paused = not paused
		elif k == KEY_A and (ev as InputEventKey).ctrl_pressed:
			select_all()
		elif k == KEY_ESCAPE:
			selected.clear()
		elif (k == KEY_ENTER or k == KEY_KP_ENTER) and deploying:
			start_battle()

## O botão esquerdo é solto aqui (e não em _unhandled_input) para que o retângulo de
## seleção termine mesmo que o mouse seja solto sobre a interface.
func _input(ev: InputEvent) -> void:
	if not lc_held or not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	var box := select_box()
	lc_held = false
	if not ready_ok or ended:
		return
	var add := mb.shift_pressed or mb.ctrl_pressed
	if box.size == Vector2.ZERO:
		var own := _own_banner_at(mb.position)
		if own != null:
			select_card(own, add)
		return
	if not add:
		selected.clear()
	for u: Unit in sim.units:
		if u.side != 0 or u.state != 0 or u in selected:
			continue
		var sp = hud.banner_pos.get(u)
		if sp != null and box.has_point(sp as Vector2):
			selected.append(u)
	sfx.play("click", -4.0)

## Retângulo de seleção em andamento, em coordenadas de tela. Tamanho zero se o botão
## esquerdo não foi arrastado o bastante.
func select_box() -> Rect2:
	if not lc_held:
		return Rect2()
	var m := get_viewport().get_mouse_position()
	if m.distance_to(lc_start) < BOX_MIN:
		return Rect2()
	return Rect2(lc_start, Vector2.ZERO).expand(m)

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

## Unidade inimiga cujo estandarte (34 x 18 px, com 4 px de folga) está sob o ponto da tela.
## Só o estandarte conta: clicar nos soldados não escolhe alvo.
func _enemy_at(screen: Vector2) -> Unit:
	var best: Unit = null
	var bd := 1e9
	for u: Unit in sim.units:
		if u.side == 0 or u.state == 2:
			continue
		var sp = hud.banner_pos.get(u)
		if sp == null:
			continue
		var d: Vector2 = (screen - (sp as Vector2)).abs()
		if d.x <= 21.0 and d.y <= 13.0 and d.length() < bd:
			bd = d.length()
			best = u
	return best

func _issue_order(release: Vector2) -> void:
	_prune()
	if selected.is_empty():
		return
	if deploying:
		_deploy_order(release)
		return
	var enemy := _enemy_at(rc_start)
	if enemy != null:
		for u: Unit in selected:
			sim.order_attack(u, enemy, u.running)
		_attack_sound()
		_flash(enemy.center)
		return
	if rc_ground == null:
		return
	var dest: Vector2 = drag_center(release)
	var facing := drag_facing(release)
	sfx.play("march")
	var width := drag_width(release) if facing != Vector2.ZERO else 0.0
	var files: Array = plan_files(width) if width > 0.0 else []
	var slots := move_slots(dest, facing, files)
	for i in selected.size():
		if not files.is_empty():
			sim.order_reform(selected[i], files[i])
		sim.order_move(selected[i], slots[i], facing, (selected[i] as Unit).running)
	var lim := Cfg.CONTROL_HALF - 25.0
	_flash(Vector2(clampf(dest.x, -lim, lim), clampf(dest.y, -lim, lim)))

## Ordem durante o posicionamento: as unidades vão direto para o posto (sem marchar), com
## a mesma frente, largura e disposição de uma ordem de mover, mas presas ao setor de Israel.
func _deploy_order(release: Vector2) -> void:
	if rc_ground == null:
		return
	var dest: Vector2 = drag_center(release)
	var facing := drag_facing(release)
	var width := drag_width(release) if facing != Vector2.ZERO else 0.0
	var files: Array = plan_files(width) if width > 0.0 else []
	var slots := move_slots(dest, facing, files)
	# as selecionadas não se bloqueiam entre si: os postos de move_slots já não se sobrepõem
	for i in selected.size():
		if not files.is_empty():
			sim.order_reform(selected[i], files[i])
		sim.place_in_sector(selected[i], slots[i], facing, selected)
	_sync_view(false)
	sfx.play("menu", -6.0)

## Frente dada arrastando o botão direito: perpendicular à linha arrastada, de modo que,
## arrastando da esquerda para a direita, as unidades olhem para "cima" (ZERO se não houve arrasto).
func drag_facing(release: Vector2) -> Vector2:
	if rc_ground == null or rc_start.distance_to(release) <= 14.0:
		return Vector2.ZERO
	var g2 = rig.pick(release)
	if g2 != null and (g2 as Vector2).distance_to(rc_ground) > 3.0:
		var d := ((g2 as Vector2) - (rc_ground as Vector2)).normalized()
		return Vector2(d.y, -d.x)
	return Vector2.ZERO

## Centro da linha: o ponto inicial, ou o meio da linha arrastada no modo de largura.
func drag_center(release: Vector2) -> Vector2:
	if drag_width(release) > 0.0:
		return ((rig.pick(release) as Vector2) + (rc_ground as Vector2)) * 0.5
	return rc_ground

## Largura da linha escolhida arrastando mais que Cfg.WIDTH_DRAG_PX: distância no chão entre
## o ponto de partida e o mouse, em metros (0 se não estiver no modo de largura).
func drag_width(release: Vector2) -> float:
	if rc_ground == null or rc_start.distance_to(release) <= Cfg.WIDTH_DRAG_PX:
		return 0.0
	var g2 = rig.pick(release)
	if g2 == null:
		return 0.0
	return (g2 as Vector2).distance_to(rc_ground)

const LINE_GAP := 8.0   # folga entre unidades lado a lado, em metros

## Soldados na frente de cada unidade selecionada (mesma ordem de `selected`) para uma linha
## de `width` metros no total: a largura é repartida na proporção dos soldados de cada
## unidade, respeitando o mínimo de Cfg.MIN_LINE_FILES.
func plan_files(width: float) -> Array:
	var out: Array = []
	var tot_n := 0
	for u: Unit in selected:
		tot_n += u.n
	var usable := maxf(width - LINE_GAP * (selected.size() - 1), 0.0)
	for u: Unit in selected:
		var w := usable * float(u.n) / maxf(tot_n, 1)
		var nf := int(round(w / float(u.t.spacing)))
		out.append(clampi(nf, mini(Cfg.MIN_LINE_FILES, u.n), u.n))
	return out

## Posição de destino de cada unidade selecionada (mesma ordem de `selected`) para uma
## ordem de mover até `dest`. Sem `facing`, mantém a disposição relativa atual; com
## `facing`, forma uma linha de frente lado a lado, perpendicular à frente e centrada
## em `dest`, preservando a ordem esquerda-direita atual das unidades. `files` (opcional)
## traz a largura planejada de cada unidade (ver plan_files).
func move_slots(dest: Vector2, facing := Vector2.ZERO, files: Array = []) -> Array:
	var out: Array = []
	var n := selected.size()
	if n == 0:
		return out
	if facing == Vector2.ZERO or n == 1 and files.is_empty():
		var cen := Vector2.ZERO
		for u: Unit in selected:
			cen += u.center
		cen /= n
		for u: Unit in selected:
			out.append(dest + (u.center - cen).limit_length(350.0))
		return out
	var r := Vector2(-facing.y, facing.x)
	var order: Array = range(n)
	order.sort_custom(func(a, b): return (selected[a] as Unit).center.dot(r) < (selected[b] as Unit).center.dot(r))
	var widths: Array = []
	var total := 0.0
	for i in n:
		var u: Unit = selected[i]
		var nf: int = files[i] if not files.is_empty() else u.files
		var w: float = nf * float(u.t.spacing) + LINE_GAP
		widths.append(w)
		total += w
	out.resize(n)
	var x := -total * 0.5
	for i: int in order:
		var u: Unit = selected[i]
		var nf: int = files[i] if not files.is_empty() else u.files
		var rows := (u.n + nf - 1) / nf
		var hd: float = maxf(float(rows) * float(u.t.spacing) * 0.5, 3.0)
		out[i] = dest + r * (x + widths[i] * 0.5) - facing * hd
		x += widths[i]
	return out

func _flash(p: Vector2) -> void:
	marker.position = Vector3(p.x, terrain.height(p.x, p.y) + 7.0, p.y)
	marker.visible = true
	marker_t = 1.2

func leave() -> void:
	finished.emit()
