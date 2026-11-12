extends CanvasLayer
## HUD da batalha: estandartes sobre as unidades, barra de cards, botões de ordem,
## mensagens e tela de resultado.

const Cfg = preload("res://scripts/config.gd")
const Unit = preload("res://scripts/unit.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")

const ARROW_SECS := 5.0       # quanto tempo a seta de frente fica visível

var battle
var banner_pos := {}          # Unit -> Vector2 (tela)
var banners: Control
var cards: Array = []
var info: Label
var feed: Label
var feed_lines: Array = []
var feed_seen := 0
var btn_run: Button
var btn_fire: Button
var btn_pause: Button
var result: PanelContainer
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

	feed = Label.new()
	feed.position = Vector2(10, 52)
	feed.add_theme_font_size_override("font_size", 13)
	feed.add_theme_color_override("font_outline_color", Color.BLACK)
	feed.add_theme_constant_override("outline_size", 4)
	add_child(feed)

	var help := Label.new()
	help.text = "Selecione pelos cards (Ctrl/Shift = vários, Ctrl+A = todos) · Botão direito no terreno = mover (arraste = direção) · Botão direito no estandarte inimigo = atacar\nWASD/setas = câmera · Q/E = girar · roda = zoom · R correr/andar · H parar · F atirar à vontade · P pausa"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 3)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(560, 0)
	help.modulate = Color(1, 1, 1, 0.85)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.offset_left = -570
	help.offset_right = -10
	help.offset_top = 6
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help)

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
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_refresh()

func _refresh() -> void:
	var sim = battle.sim
	for c in cards:
		c.refresh(c.unit in battle.selected)
	info.text = "Israel: %d unidades, %d homens      Filisteus: %d unidades, %d homens\n%s   x%d   tick %.1f ms   %d FPS" % [
		sim.controlled(0), sim.men_alive(0), sim.controlled(1), sim.men_alive(1),
		"PAUSADO" if battle.paused else "Tempo %d:%02d" % [int(sim.time) / 60, int(sim.time) % 60],
		int(battle.speed), battle.tick_ms, Engine.get_frames_per_second()]
	while feed_seen < sim.messages.size():
		var m: Array = sim.messages[feed_seen]
		feed_lines.append(str(m[0]))
		feed_seen += 1
	while feed_lines.size() > 6:
		feed_lines.pop_front()
	feed.text = "\n".join(feed_lines)
	var sel: Array = battle.selected
	if not sel.is_empty():
		btn_run.text = "Andar (R)" if sel[0].running else "Correr (R)"
		btn_fire.text = "Atirar à vontade: %s (F)" % ("sim" if sel[0].fire_at_will else "não")
	btn_pause.text = "Continuar (P)" if battle.paused else "Pausa (P)"

## Seta no chão indicando a frente da unidade nos primeiros segundos após concluir a movimentação.
func _draw_facing_arrows() -> void:
	var now: float = battle.sim.time
	for u: Unit in battle.sim.units:
		if u.state != 0 or now - u.arrived_at > ARROW_SECS:
			continue
		var fade := clampf(ARROW_SECS - (now - u.arrived_at), 0.0, 1.0)
		_draw_arrow(u.center, u.facing, u.brad + 30.0, Color(1, 0.85, 0.2, fade))
	_draw_preview_arrow()

## Prévia da frente enquanto o botão direito está pressionado e arrastado.
func _draw_preview_arrow() -> void:
	battle._prune()
	var sel: Array = battle.selected
	if sel.is_empty():
		return
	var held: bool = battle.rc_held and battle.rc_ground != null \
		and battle._enemy_at(battle.rc_start, battle.rc_ground) == null
	if held:
		var dest: Vector2 = battle.rc_ground
		var f: Vector2 = battle.drag_facing(battle.get_viewport().get_mouse_position())
		var slots: Array = battle.move_slots(dest)
		for i in sel.size():
			var u: Unit = sel[i]
			var p: Vector2 = battle.sim.reachable(slots[i], u)
			_draw_slot(u, p, f if f != Vector2.ZERO else u.facing, Color(0.5, 1, 0.5, 0.95))
		if f != Vector2.ZERO:
			_draw_arrow(dest, f, 70.0, Color(0.5, 1, 0.5, 0.9))
	else:
		# destinos já ordenados das unidades selecionadas que ainda estão a caminho
		for u: Unit in sel:
			if u.target == null and not u.path.is_empty():
				var fd: Vector2 = u.dest_facing if u.dest_facing != Vector2.ZERO else u.facing
				_draw_slot(u, u.path[u.path.size() - 1], fd, Color(1, 1, 1, 0.8))

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
	for u: Unit in banner_pos:
		var p: Vector2 = banner_pos[u]
		var col := Color(0.16, 0.32, 0.78) if u.side == 0 else Color(0.72, 0.14, 0.11)
		var txt: String = u.t.short
		if u.state == 1:
			col = Color(0.92, 0.92, 0.92)
		var r := Rect2(p - Vector2(17, 9), Vector2(34, 18))
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
