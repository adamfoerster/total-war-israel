extends CanvasLayer
## HUD da batalha: estandartes sobre as unidades, barra de cards, botões de ordem,
## mensagens e tela de resultado.

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const Settings = preload("res://scripts/settings.gd")
const Daylight = preload("res://scripts/daylight.gd")

const ARROW_SECS := 5.0       # quanto tempo a seta de frente fica visível

var battle
var banner_pos := {}          # Unit -> Vector2 (tela)
var banners: Control
var cards: Array = []
var info: Label
var feed: Label
var feed_panel: PanelContainer
const FEED_SECS := 5.0   # tempo que cada aviso fica na tela
var feed_lines: Array = []
var feed_seen := 0
var btn_rally: Button
var btn_run: Button
var btn_fire: Button
var btn_pause: Button
var result: PanelContainer
var fps_label: Label
var settings_panel: PanelContainer
var _t := 0.0

func _ready() -> void:
	banners = Control.new()
	banners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banners.draw.connect(_draw_banners)
	add_child(banners)

	info = Label.new()
	info.position = Vector2(10, 6)
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 4)
	add_child(info)

	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 15)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 4)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fps_label.offset_left = -120
	fps_label.offset_right = -10
	fps_label.offset_top = 6
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = Settings.show_fps
	add_child(fps_label)
	_build_settings()

	feed_panel = PanelContainer.new()
	feed_panel.position = Vector2(10, 52)
	feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_content_margin_all(6)
	feed_panel.add_theme_stylebox_override("panel", bg)
	feed_panel.visible = false
	add_child(feed_panel)
	feed = Label.new()
	feed.add_theme_font_size_override("font_size", 13)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_panel.add_child(feed)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -4
	bottom.add_theme_constant_override("separation", 4)
	add_child(bottom)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	bottom.add_child(row)
	btn_run = _btn(row, "Correr (R)", battle.cmd_run_toggle)
	_btn(row, "Parar (H)", battle.cmd_halt)
	btn_rally = _btn(row, "Reunir (G)", battle.cmd_rally)
	btn_fire = _btn(row, "Atirar à vontade (F)", battle.cmd_fire_toggle)
	_btn(row, "Selecionar todos", battle.select_all)
	btn_pause = _btn(row, "Pausa (P)", func(): battle.paused = not battle.paused)
	_btn(row, "Velocidade", _cycle_speed)
	_btn(row, "Abandonar", battle.leave)

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	bottom.add_child(flow)
	for u: Unit in battle.player_units():
		var c := UnitCard.new()
		c.unit = u
		c.clicked.connect(battle.select_card)
		flow.add_child(c)
		cards.append(c)
	_refresh()

## Tela de configurações, mostrada enquanto o jogo está pausado.
func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_panel.visible = false
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	settings_panel.add_child(pad)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pad.add_child(vb)
	var title := Label.new()
	title.text = "Pausado — Configurações"
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	vb.add_child(hr)
	var hl := Label.new()
	hl.text = "Hora do dia"
	hr.add_child(hl)
	var hs := HSlider.new()
	hs.min_value = Cfg.HOUR_MIN
	hs.max_value = Cfg.HOUR_MAX
	hs.step = 0.25
	hs.value = battle.hour
	hs.custom_minimum_size = Vector2(200, 0)
	hs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hs.focus_mode = Control.FOCUS_NONE
	hr.add_child(hs)
	var hv := Label.new()
	hv.text = "%s (%s)" % [Daylight.clock(battle.hour), Daylight.period(battle.hour)]
	hr.add_child(hv)
	hs.value_changed.connect(func(v: float):
		battle.set_hour(v)
		hv.text = "%s (%s)" % [Daylight.clock(v), Daylight.period(v)])
	var cb_sun := _check(vb, "Sol", Settings.sun)
	var cb_sh := _check(vb, "Sombras", Settings.shadows)
	var cb_un := _check(vb, "Sombras nas unidades", Settings.unit_shadows)
	var cb_fps := _check(vb, "Mostrar FPS (canto superior direito)", Settings.show_fps)
	var sync := func():
		cb_un.disabled = not Settings.shadows
	cb_sun.toggled.connect(func(on: bool): Settings.sun = on; _changed())
	cb_sh.toggled.connect(func(on: bool): Settings.shadows = on; sync.call(); _changed())
	cb_un.toggled.connect(func(on: bool): Settings.unit_shadows = on; _changed())
	cb_fps.toggled.connect(func(on: bool): Settings.show_fps = on; fps_label.visible = on; _changed())
	sync.call()
	var resume := Button.new()
	resume.text = "Continuar (P)"
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(func(): battle.paused = false)
	vb.add_child(resume)
	add_child(settings_panel)

func _check(parent: Node, text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	parent.add_child(c)
	return c

func _changed() -> void:
	Settings.save_file()
	battle.apply_settings()

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _cycle_speed() -> void:
	battle.speed = 2.0 if battle.speed == 1.0 else (4.0 if battle.speed == 2.0 else 1.0)

func _process(delta: float) -> void:
	if battle == null or not battle.ready_ok:
		return
	var cam: Camera3D = battle.rig.cam
	banner_pos.clear()
	for u: Unit in battle.sim.units:
		if u.state == 2:
			continue
		var w := Vector3(u.center.x, battle.terrain.height(u.center.x, u.center.y) + 7.0, u.center.y)
		if u.vel != Vector2.ZERO:
			w += Vector3(u.vel.x, 0, u.vel.y) * battle.since_tick
		if cam.is_position_behind(w):
			continue
		banner_pos[u] = cam.unproject_position(w)
	banners.queue_redraw()
	settings_panel.visible = battle.paused and not battle.ended
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_refresh()

func _refresh() -> void:
	var sim = battle.sim
	for c in cards:
		c.refresh(c.unit in battle.selected)
	info.text = "Israel: %d unidades, %d homens      Filisteus: %d unidades, %d homens\n%s   x%d   tick %.1f ms" % [
		sim.controlled(0), sim.men_alive(0), sim.controlled(1), sim.men_alive(1),
		"PAUSADO" if battle.paused else "Tempo %d:%02d" % [int(sim.time) / 60, int(sim.time) % 60],
		int(battle.speed), battle.tick_ms]
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	while feed_seen < sim.messages.size():
		var m: Array = sim.messages[feed_seen]
		feed_lines.append([str(m[0]), Time.get_ticks_msec() + int(FEED_SECS * 1000.0)])
		feed_seen += 1
	var now := Time.get_ticks_msec()
	feed_lines = feed_lines.filter(func(l): return l[1] > now)
	while feed_lines.size() > 6:
		feed_lines.pop_front()
	feed_panel.visible = not feed_lines.is_empty()
	feed.text = "\n".join(feed_lines.map(func(l): return l[0]))
	feed_panel.size = Vector2.ZERO   # encolhe junto com o texto
	var sel: Array = battle.selected
	if not sel.is_empty():
		btn_run.text = "Andar (R)" if sel[0].running else "Correr (R)"
		btn_fire.text = "Atirar à vontade: %s (F)" % ("sim" if sel[0].fire_at_will else "não")
	var gen: Unit = null
	for u: Unit in sim.units:
		if u.side == 0 and u.is_general and u.general_alive and u.state == 0:
			gen = u
	btn_rally.disabled = gen == null
	if gen != null:
		var wait := int(ceil(gen.rally_ready - sim.time))
		btn_rally.text = "Reunir (G)" if wait <= 0 else "Reunir (%d s)" % wait
	btn_pause.text = "Continuar (P)" if battle.paused else "Pausa (P)"

## Seta no chão indicando a frente da unidade nos primeiros segundos após concluir a movimentação.
func _draw_facing_arrows() -> void:
	var now: float = battle.sim.time
	for u: Unit in battle.sim.units:
		if u.state != 0 or now - u.arrived_at > ARROW_SECS:
			continue
		var fade := clampf(ARROW_SECS - (now - u.arrived_at), 0.0, 1.0)
		_draw_arrow(u.center, u.facing, u.brad + 30.0, Color(1, 0.85, 0.2, fade))
	_draw_paths()
	_draw_preview_arrow()

## Caminho que as unidades vão percorrer: opaco para as selecionadas; para uma unidade amiga
## não selecionada sob o mouse, caminho e quadrado do destino com 50% de transparência.
func _draw_paths() -> void:
	for u: Unit in battle.selected:
		if u.state == 0 and not u.path.is_empty():
			_draw_path(u, 1.0)
	if battle.ended:
		return
	var h: Unit = battle._own_banner_at(battle.get_viewport().get_mouse_position())
	if h != null and not (h in battle.selected) and not h.path.is_empty():
		_draw_path(h, 0.5)
		if h.target == null:
			var fd: Vector2 = h.dest_facing if h.dest_facing != Vector2.ZERO else h.facing
			_draw_slot(h, h.path[h.path.size() - 1], fd, Color(1, 1, 1, 0.5))

func _proj(wp: Vector2) -> Variant:
	var w3 := Vector3(wp.x, battle.terrain.height(wp.x, wp.y) + 1.5, wp.y)
	if battle.rig.cam.is_position_behind(w3):
		return null
	return battle.rig.cam.unproject_position(w3)

## Linha do centro da unidade até o destino, com pontas de seta a cada ~100 m e no fim.
func _draw_path(u: Unit, alpha: float) -> void:
	var pts: Array = [u.center]
	for i in range(u.path_i, u.path.size()):
		pts.append(u.path[i])
	var col := Color(1, 1, 1, alpha)
	var edge := Color(0, 0, 0, alpha)
	var line := PackedVector2Array()
	var heads: Array = []     # [posição na tela, direção na tela]
	var acc := 0.0
	var next_head := 100.0
	var last_s = null
	for k in range(pts.size() - 1):
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var seg := a.distance_to(b)
		var n := maxi(1, int(seg / 20.0))
		for j in range(n + 1):
			if k > 0 and j == 0:
				continue
			var wp := a.lerp(b, float(j) / n)
			var s = _proj(wp)
			if s == null:
				last_s = null
				continue
			line.append(s)
			if last_s != null and j > 0:
				acc += seg / n
				if acc >= next_head and (s - last_s).length() > 2.0:
					heads.append([s, ((s as Vector2) - (last_s as Vector2)).normalized()])
					next_head += 100.0
			last_s = s
	if line.size() < 2:
		return
	banners.draw_polyline(line, edge, 5.0)
	banners.draw_polyline(line, col, 2.5)
	var end_dir: Vector2 = (line[line.size() - 1] - line[line.size() - 2]).normalized()
	heads.append([line[line.size() - 1], end_dir])
	for hd: Array in heads:
		var tip: Vector2 = hd[0]
		var d: Vector2 = hd[1]
		var nrm := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([tip, tip - d * 16.0 + nrm * 8.0, tip - d * 16.0 - nrm * 8.0])
		banners.draw_colored_polygon(tri, col)
		banners.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), edge, 1.5)

## Prévia da frente enquanto o botão direito está pressionado e arrastado.
func _draw_preview_arrow() -> void:
	battle._prune()
	var sel: Array = battle.selected
	if sel.is_empty():
		return
	var held: bool = battle.rc_held and battle.rc_ground != null \
		and battle._enemy_at(battle.rc_start) == null
	if held:
		var mouse: Vector2 = battle.get_viewport().get_mouse_position()
		var dest: Vector2 = battle.drag_center(mouse)
		var f: Vector2 = battle.drag_facing(mouse)
		var width: float = battle.drag_width(mouse) if f != Vector2.ZERO else 0.0
		var files: Array = battle.plan_files(width) if width > 0.0 else []
		var slots: Array = battle.move_slots(dest, f, files)
		for i in sel.size():
			var u: Unit = sel[i]
			var p: Vector2 = battle.sim.reachable(slots[i], u)
			var fu: Vector2 = f if f != Vector2.ZERO else u.facing
			if files.is_empty():
				_draw_slot(u, p, fu, Color(0.5, 1, 0.5, 0.95))
			else:
				_draw_soldiers(u, p, fu, files[i], Color(0.5, 1, 0.5, 0.95))
		if f != Vector2.ZERO:
			banners.draw_line(battle.rc_start, mouse, Color(0, 0, 0, 0.7), 5.0)
			banners.draw_line(battle.rc_start, mouse, Color(0.5, 1, 0.5, 0.9), 2.0)
		if f != Vector2.ZERO:
			_draw_arrow(dest, f, 70.0, Color(0.5, 1, 0.5, 0.9))
	else:
		# destinos já ordenados das unidades selecionadas que ainda estão a caminho
		for u: Unit in sel:
			if u.target == null and not u.path.is_empty():
				var fd: Vector2 = u.dest_facing if u.dest_facing != Vector2.ZERO else u.facing
				_draw_slot(u, u.path[u.path.size() - 1], fd, Color(1, 1, 1, 0.8))

## Um círculo por soldado nos postos que a unidade ocupará com `nf` soldados na frente.
func _draw_soldiers(u: Unit, c: Vector2, f: Vector2, nf: int, col: Color) -> void:
	var cam: Camera3D = battle.rig.cam
	var sp: float = u.t.spacing
	var rows := (u.n + nf - 1) / nf
	var r := Vector2(-f.y, f.x)
	var base: Vector2 = c - r * (sp * (nf - 1) * 0.5) + f * (sp * (rows - 1) * 0.5)
	var h: float = battle.terrain.height(c.x, c.y) + 1.5
	var c3 := Vector3(c.x, h, c.y)
	if cam.is_position_behind(c3):
		return
	var sc := cam.unproject_position(c3)
	var rad := maxf(cam.unproject_position(Vector3(c.x + r.x * float(u.t.radius), h, c.y + r.y * float(u.t.radius))).distance_to(sc), 1.5)
	var edge := Color(0, 0, 0, col.a)
	for j in u.n:
		var wp: Vector2 = base + r * (sp * (j % nf)) - f * (sp * (j / nf))
		var w3 := Vector3(wp.x, h, wp.y)
		if cam.is_position_behind(w3):
			continue
		var s := cam.unproject_position(w3)
		banners.draw_circle(s, rad + 0.8, edge)
		banners.draw_circle(s, rad, col)

## Retângulo no chão com o espaço que a unidade ocupará no destino, com marca da frente e sigla.
func _draw_slot(u: Unit, c: Vector2, f: Vector2, col: Color) -> void:
	var cam: Camera3D = battle.rig.cam
	var sp: float = u.t.spacing
	var hw: float = maxf(u.files * sp * 0.5, 3.0)
	var hd: float = maxf(float(u.rows0) * sp * 0.5, 3.0)
	var r := Vector2(-f.y, f.x)
	var pts := PackedVector2Array()
	for k in [[-1, -1], [1, -1], [1, 1], [-1, 1], [-1, -1]]:
		var wp: Vector2 = c + r * (hw * k[0]) + f * (hd * k[1])
		var w3 := Vector3(wp.x, battle.terrain.height(wp.x, wp.y) + 1.5, wp.y)
		if cam.is_position_behind(w3):
			return
		pts.append(cam.unproject_position(w3))
	var fill := col
	fill.a = 0.18
	banners.draw_colored_polygon(pts.slice(0, 4), fill)
	banners.draw_polyline(pts, Color(0, 0, 0, col.a), 4.0)
	banners.draw_polyline(pts, col, 2.0)
	# lado da frente reforçado
	banners.draw_line(pts[2], pts[3], col, 5.0)
	var mid := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
	banners.draw_string(ThemeDB.fallback_font, mid + Vector2(-10, 5), u.t.short, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

func _draw_arrow(origin: Vector2, dir: Vector2, len_w: float, col: Color) -> void:
	var cam: Camera3D = battle.rig.cam
	var a := Vector3(origin.x, battle.terrain.height(origin.x, origin.y) + 1.5, origin.y)
	var tp: Vector2 = origin + dir * len_w
	var b := Vector3(tp.x, battle.terrain.height(tp.x, tp.y) + 1.5, tp.y)
	if cam.is_position_behind(a) or cam.is_position_behind(b):
		return
	var sa := cam.unproject_position(a)
	var sb := cam.unproject_position(b)
	var d := sb - sa
	if d.length() < 4.0:
		return
	d = d.normalized()
	var n := Vector2(-d.y, d.x)
	var edge := Color(0, 0, 0, col.a)
	banners.draw_line(sa, sb - d * 8.0, edge, 6.0)
	banners.draw_line(sa, sb - d * 8.0, col, 3.0)
	var head := PackedVector2Array([sb, sb - d * 20.0 + n * 11.0, sb - d * 20.0 - n * 11.0])
	banners.draw_colored_polygon(head, col)
	banners.draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), edge, 1.5)

func _draw_banners() -> void:
	_draw_facing_arrows()
	var font := ThemeDB.fallback_font
	var hover: Unit = null
	if not battle.selected.is_empty() and not battle.ended:
		var mpos: Vector2 = battle.get_viewport().get_mouse_position()
		hover = battle._enemy_at(mpos)
	for u: Unit in banner_pos:
		var p: Vector2 = banner_pos[u]
		var col := Color(0.16, 0.32, 0.78) if u.side == 0 else Color(0.72, 0.14, 0.11)
		var txt: String = u.t.short
		if u.state == 1:
			col = Color(0.92, 0.92, 0.92)
		var r := Rect2(p - Vector2(17, 9), Vector2(34, 18))
		if u == hover:
			banners.draw_rect(r.grow(5.0), Color(1, 0.1, 0.1, 0.35))
			banners.draw_rect(r.grow(5.0), Color(1, 0.15, 0.15), false, 3.0)
		banners.draw_rect(r, col)
		var sel: bool = u in battle.selected
		var bc := Color(1, 0.85, 0.2) if (sel or u.is_general) else Color(0, 0, 0)
		banners.draw_rect(r, bc, false, 3.0 if sel else (2.0 if u.is_general else 1.0))
		banners.draw_string(font, p + Vector2(-13, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color.BLACK if u.state == 1 else Color.WHITE)
		if u.is_general and u.general_alive:
			banners.draw_string(font, p + Vector2(6, 5), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.2))
		if u.state == 0:
			var frac := float(u.men()) / u.men_init
			banners.draw_rect(Rect2(p + Vector2(-17, 10), Vector2(34, 3)), Color(0, 0, 0, 0.6))
			banners.draw_rect(Rect2(p + Vector2(-17, 10), Vector2(34 * frac, 3)), Color(0.3, 0.9, 0.3))
			banners.draw_rect(Rect2(p + Vector2(-17, 13), Vector2(34 * u.morale / 100.0, 2)), Color(1, 0.9, 0.3))

func show_result() -> void:
	var sim = battle.sim
	result = PanelContainer.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result.grow_vertical = Control.GROW_DIRECTION_BOTH
	var mc := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 24)
	result.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	mc.add_child(vb)
	var title := Label.new()
	title.text = "VITÓRIA!" if sim.winner == 0 else "DERROTA"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var body := Label.new()
	body.text = "%s não tem mais nenhuma unidade sob controle.\n\nIsrael — mortos: %d, fugiram do campo: %d\nFilisteus — mortos: %d, fugiram do campo: %d\nDuração: %d:%02d" % [
		Cfg.SIDE_NAMES[1 - sim.winner], sim.losses[0], sim.fled[0], sim.losses[1], sim.fled[1],
		int(sim.time) / 60, int(sim.time) % 60]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	_btn(vb, "Voltar ao preparo", battle.leave)
	add_child(result)
