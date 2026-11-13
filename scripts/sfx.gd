extends Node
## Efeitos sonoros e vozes. Cada tela cria a sua instância: `sfx = Sfx.new(); add_child(sfx)`.
## Os sons "click", "menu", "sword", "win" e "lose" vêm do jogo de tabuleiro Promised Land;
## "choque1" a "choque6" vêm do pacote CC0 de armas contra armas do OpenGameArt (Ben Jaszczak e Brian Nelson);
## as vozes (andar, correr, parar, fugas, início, reunir, ataques) são próprias deste jogo;
## "dor01" a "dor12" são trechos de "Male Grunt/Yelling sounds", de HaelDB (OpenGameArt, CC0),
## cortados e convertidos para mono; "flechas" e "fundas" são sintetizados por tools/gen_sounds.js.
##
## play() toca sem posição (voz do comandante, interface). play_at() toca no ponto do mapa:
## a câmera é o ouvinte, então o som vem do lado certo e cai com a distância.

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
	"dor01": preload("res://assets/sounds/dor01.wav"),
	"dor02": preload("res://assets/sounds/dor02.wav"),
	"dor03": preload("res://assets/sounds/dor03.wav"),
	"dor04": preload("res://assets/sounds/dor04.wav"),
	"dor05": preload("res://assets/sounds/dor05.wav"),
	"dor06": preload("res://assets/sounds/dor06.wav"),
	"dor07": preload("res://assets/sounds/dor07.wav"),
	"dor08": preload("res://assets/sounds/dor08.wav"),
	"dor09": preload("res://assets/sounds/dor09.wav"),
	"dor10": preload("res://assets/sounds/dor10.wav"),
	"dor11": preload("res://assets/sounds/dor11.wav"),
	"dor12": preload("res://assets/sounds/dor12.wav"),
	"flechas": preload("res://assets/sounds/flechas.wav"),
	"fundas": preload("res://assets/sounds/fundas.wav"),
}

const PAIN := ["dor01", "dor02", "dor03", "dor04", "dor05", "dor06",
	"dor07", "dor08", "dor09", "dor10", "dor11", "dor12"]
const POOL_3D := 24         # sons posicionados simultâneos; o mais antigo é cortado
const UNIT_SIZE_3D := 160.0  # m em que o som posicionado toca no volume cheio
const MAX_DIST_3D := 4500.0

# vozes: uma de cada vez, a nova interrompe a anterior
const VOICES := ["andar", "correr", "parar", "ataquem", "carruagens", "arqueiros", "infantaria-pesada",
	"fuga-general", "fuga-general2", "fuga1", "fuga2", "inicio-bom", "inicio-medio", "inicio-ruim", "reunir"]

var _players := {}
var _voice: Node              # AudioStreamPlayer ou AudioStreamPlayer3D da voz atual
var _pool: Array = []         # AudioStreamPlayer3D
var _pool_i := 0
var _voice3d: AudioStreamPlayer3D

func _ready() -> void:
	for k: String in STREAMS:
		var p := AudioStreamPlayer.new()
		p.stream = STREAMS[k]
		add_child(p)
		_players[k] = p
	for i in POOL_3D:
		_pool.append(_make_3d())
	_voice3d = _make_3d()

func _make_3d() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = UNIT_SIZE_3D
	p.max_distance = MAX_DIST_3D
	p.max_db = 3.0
	p.panning_strength = 1.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	return p

func _stop_voice(keep: Node) -> void:
	if _voice != null and _voice != keep:
		_voice.stop()
	_voice = keep

func play(sound: String, vol_db := 0.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null:
		return
	if sound in VOICES:
		_stop_voice(p)
	p.volume_db = vol_db
	p.play()

## Toca o som no ponto `at` do mundo. Vozes usam um player próprio e interrompem a voz
## anterior, como em play(); os demais sons revezam num grupo de POOL_3D players.
func play_at(sound: String, at: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var st: AudioStream = STREAMS.get(sound)
	if st == null:
		return
	var p: AudioStreamPlayer3D
	if sound in VOICES:
		p = _voice3d
		_stop_voice(p)
	else:
		p = _pool[_pool_i]
		_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = st
	p.global_position = at
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()

## Toca no ponto `at` um som sorteado da lista.
func play_any_at(sounds: Array, at: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	play_at(sounds[randi() % sounds.size()], at, vol_db, pitch)

## Toca um som sorteado da lista.
func play_any(sounds: Array, vol_db := 0.0) -> void:
	play(sounds[randi() % sounds.size()], vol_db)

func playing(sound: String) -> bool:
	var p: AudioStreamPlayer = _players.get(sound)
	return p != null and p.playing
