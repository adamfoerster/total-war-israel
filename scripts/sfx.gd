extends Node
## Efeitos sonoros e vozes. Cada tela cria a sua instância: `sfx = Sfx.new(); add_child(sfx)`.
## Os sons "click", "menu", "sword", "win" e "lose" vêm do jogo de tabuleiro Promised Land;
## "choque1" a "choque6" vêm do pacote CC0 de armas contra armas do OpenGameArt (Ben Jaszczak e Brian Nelson);
## as vozes (andar, correr, parar, fugas, início, reunir, ataques) são próprias deste jogo.

const STREAMS := {
	"click": preload("res://assets/sounds/select2.mp3"),
	"menu": preload("res://assets/sounds/menu-select.mp3"),
	"sword": preload("res://assets/sounds/sword.mp3"),
	"win": preload("res://assets/sounds/win.mp3"),
	"lose": preload("res://assets/sounds/lose.mp3"),
	"choque1": preload("res://assets/sounds/choque1.wav"),
	"choque2": preload("res://assets/sounds/choque2.wav"),
	"choque3": preload("res://assets/sounds/choque3.wav"),
	"choque4": preload("res://assets/sounds/choque4.wav"),
	"choque5": preload("res://assets/sounds/choque5.wav"),
	"choque6": preload("res://assets/sounds/choque6.wav"),
	"march": preload("res://assets/sounds/march.mp3"),
	"andar": preload("res://assets/sounds/andar.mp3"),
	"correr": preload("res://assets/sounds/correr.mp3"),
	"parar": preload("res://assets/sounds/parar.mp3"),
	"ataquem": preload("res://assets/sounds/ataquem.mp3"),
	"carruagens": preload("res://assets/sounds/carruagens.mp3"),
	"arqueiros": preload("res://assets/sounds/arqueiros.mp3"),
	"infantaria-pesada": preload("res://assets/sounds/infantaria-pesada.mp3"),
	"fuga-general": preload("res://assets/sounds/fuga-general.mp3"),
	"fuga-general2": preload("res://assets/sounds/fuga-general2.mp3"),
	"fuga1": preload("res://assets/sounds/fuga1.mp3"),
	"fuga2": preload("res://assets/sounds/fuga2.mp3"),
	"inicio-bom": preload("res://assets/sounds/inicio-bom.mp3"),
	"inicio-medio": preload("res://assets/sounds/inicio-medio.mp3"),
	"inicio-ruim": preload("res://assets/sounds/inicio-ruim.mp3"),
	"reunir": preload("res://assets/sounds/reunir.mp3"),
}

# vozes: uma de cada vez, a nova interrompe a anterior
const VOICES := ["andar", "correr", "parar", "ataquem", "carruagens", "arqueiros", "infantaria-pesada",
	"fuga-general", "fuga-general2", "fuga1", "fuga2", "inicio-bom", "inicio-medio", "inicio-ruim", "reunir"]

var _players := {}
var _voice: AudioStreamPlayer

func _ready() -> void:
	for k: String in STREAMS:
		var p := AudioStreamPlayer.new()
		p.stream = STREAMS[k]
		add_child(p)
		_players[k] = p

func play(sound: String, vol_db := 0.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null:
		return
	if sound in VOICES:
		if _voice != null and _voice != p:
			_voice.stop()
		_voice = p
	p.volume_db = vol_db
	p.play()

## Toca um som sorteado da lista.
func play_any(sounds: Array, vol_db := 0.0) -> void:
	play(sounds[randi() % sounds.size()], vol_db)

func playing(sound: String) -> bool:
	var p: AudioStreamPlayer = _players.get(sound)
	return p != null and p.playing
