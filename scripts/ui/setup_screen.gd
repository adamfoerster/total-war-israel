extends Control
## Tela de preparo: monta o exército (até 20 cards; homens por card conforme o tipo) e
## escolhe qual card leva o general e a hora do dia (posição do sol e sombras).

signal start_battle(army, hour)

const Cfg = preload("res://scripts/config.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Daylight = preload("res://scripts/daylight.gd")

var initial_army: Array = []
var initial_hour := Cfg.HOUR_DEFAULT
var hour := Cfg.HOUR_DEFAULT
var rows: Array = []          # [{type, men, general}]
var list: VBoxContainer
var summary: Label
var add_btn: Button
var sfx

func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.11, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 24)
	add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mc.add_child(vb)

	var title := Label.new()
	title.text = "Terra Prometida — Batalha de Jerusalém"
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Monte o exército de Israel: até %d unidades; o número de homens de cada uma depende do tipo. Marque qual unidade leva o general — se ele fugir ou morrer, a moral de todo o exército despenca. O exército filisteu espelha a sua composição e ataca pelo planalto ao norte." % Cfg.MAX_CARDS
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	vb.add_child(sub)

	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 12)
	vb.add_child(hr)
	var hl := Label.new()
	hl.text = "Hora do dia"
	hr.add_child(hl)
	var hs := HSlider.new()
	hs.min_value = Cfg.HOUR_MIN
	hs.max_value = Cfg.HOUR_MAX
	hs.step = 0.25
	hs.value = initial_hour
	hs.custom_minimum_size = Vector2(320, 0)
	hs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hs)
	var hv := Label.new()
	hr.add_child(hv)
	hour = initial_hour
	hv.text = "%s (%s)" % [Daylight.clock(hour), Daylight.period(hour)]
	hs.value_changed.connect(func(v: float):
		hour = v
		hv.text = "%s (%s)" % [Daylight.clock(v), Daylight.period(v)])

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	sc.add_child(list)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	vb.add_child(bar)
	add_btn = Button.new()
	add_btn.text = "+ Adicionar unidade"
	add_btn.pressed.connect(_add_row)
	bar.add_child(add_btn)
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(summary)
	var go := Button.new()
	go.text = "  Iniciar batalha  "
	go.add_theme_font_size_override("font_size", 20)
	go.pressed.connect(_go)
	bar.add_child(go)

	if initial_army.is_empty():
		for t: int in [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4]:
			rows.append({"type": t, "men": int(Cfg.TYPES[t].men_def), "general": false})
		rows[0].general = true
	else:
		rows = initial_army.duplicate(true)
	_rebuild()

func _add_row() -> void:
	sfx.play("menu")
	if rows.size() >= Cfg.MAX_CARDS:
		return
	rows.append({"type": Cfg.HEAVY, "men": int(Cfg.TYPES[Cfg.HEAVY].men_def), "general": rows.is_empty()})
	_rebuild()

func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for k in rows.size():
		var r: Dictionary = rows[k]
		var tt: Dictionary = Cfg.TYPES[r.type]
		# exército de uma partida anterior pode vir de outros limites
		r.men = clampi(int(r.men), int(tt.men_min), int(tt.men_max))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var num := Label.new()
		num.text = "%2d." % (k + 1)
		num.custom_minimum_size = Vector2(30, 0)
		hb.add_child(num)
		var opt := OptionButton.new()
		for t: Dictionary in Cfg.TYPES:
			opt.add_item(t.name)
		opt.selected = r.type
		opt.custom_minimum_size = Vector2(190, 0)
		# trocar o tipo volta ao número padrão de homens do novo tipo
		opt.item_selected.connect(func(i: int): _set_type(r, i))
		hb.add_child(opt)
		var sl := HSlider.new()
		sl.min_value = tt.men_min
		sl.max_value = tt.men_max
		sl.step = tt.men_step
		sl.value = r.men
		sl.custom_minimum_size = Vector2(260, 0)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(sl)
		var ml := Label.new()
		ml.text = "%d homens" % r.men
		ml.custom_minimum_size = Vector2(100, 0)
		hb.add_child(ml)
		sl.value_changed.connect(func(v: float): r.men = int(v); ml.text = "%d homens" % int(v); _summary())
		var gen := CheckBox.new()
		gen.text = "General"
		gen.button_group = group
		gen.button_pressed = r.general
		gen.toggled.connect(func(on: bool): if on: _set_general(r))
		hb.add_child(gen)
		var del := Button.new()
		del.text = "Remover"
		del.pressed.connect(func(): _remove(r))
		hb.add_child(del)
		list.add_child(hb)
	_summary()

func _set_type(r: Dictionary, t: int) -> void:
	r.type = t
	r.men = int(Cfg.TYPES[t].men_def)
	_rebuild.call_deferred()   # refaz o controle deslizante com os limites do novo tipo

func _set_general(r: Dictionary) -> void:
	sfx.play("click")
	for o: Dictionary in rows:
		o.general = is_same(o, r)
	_summary()

func _remove(r: Dictionary) -> void:
	sfx.play("menu")
	if rows.size() <= 1:
		return
	for k in rows.size():
		if is_same(rows[k], r):
			rows.remove_at(k)
			break
	if r.general:
		rows[0].general = true
	_rebuild()

func _summary() -> void:
	var men := 0
	var gname := "nenhum"
	for k in rows.size():
		men += int(rows[k].men)
		if rows[k].general:
			gname = "%s (unidade %d)" % [Cfg.TYPES[rows[k].type].name, k + 1]
	summary.text = "%d/%d unidades · %d homens · General: %s" % [rows.size(), Cfg.MAX_CARDS, men, gname]
	add_btn.disabled = rows.size() >= Cfg.MAX_CARDS

func _go() -> void:
	sfx.play("menu")
	# exatamente um general
	var has := false
	for r: Dictionary in rows:
		if r.general and has:
			r.general = false
		has = has or r.general
	if not has:
		rows[0].general = true
	start_battle.emit(rows.duplicate(true), hour)
