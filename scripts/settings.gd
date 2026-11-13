extends RefCounted
## Configurações de exibição, guardadas em user://settings.cfg. Valores estáticos: valem
## para todas as telas e partidas da sessão.

const PATH := "user://settings.cfg"

static var sun := true            # luz do sol (desligada: só luz ambiente)
static var shadows := true        # sombras em geral (terreno e unidades)
static var unit_shadows := true   # sombras projetadas pelas unidades (precisa de "sombras")
static var show_fps := false      # FPS no canto superior direito
static var _loaded := false

static func load_file() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	sun = bool(cf.get_value("display", "sun", sun))
	shadows = bool(cf.get_value("display", "shadows", shadows))
	unit_shadows = bool(cf.get_value("display", "unit_shadows", unit_shadows))
	show_fps = bool(cf.get_value("display", "show_fps", show_fps))

static func save_file() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "sun", sun)
	cf.set_value("display", "shadows", shadows)
	cf.set_value("display", "unit_shadows", unit_shadows)
	cf.set_value("display", "show_fps", show_fps)
	cf.save(PATH)
