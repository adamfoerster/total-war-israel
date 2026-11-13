extends RefCounted
## Constantes globais e tabela de tipos de unidade.

# --- Mapa ---
const HALF_MAP := 2000.0        # área visível: 4 x 4 km
const CONTROL_HALF := 1200.0    # área controlável: 2,4 x 2,4 km
const EXIT_HALF := 1450.0       # fugitivos somem 250 m depois de sair da área controlável
const HM_N := 401               # nós do heightmap
const HM_CELL := 10.0           # metros por nó
const VERT_EXAG := 1.0
const SLOPE_CHARIOT := 12.0     # graus: acima disso carros não passam
const SLOPE_ROCK := 12.0       # graus: a partir daqui o terreno recebe a textura de rocha
const SLOPE_IMPASS := 32.0      # graus: acima disso ninguém passa
const NAV_N := 200
const NAV_CELL := 20.0

# --- Simulação ---
const TICK := 0.1
const GRID_CELL := 1.6
const GRID_HALF := 1440.0
const GRID_N := 1800

# --- Exércitos ---
const MAX_CARDS := 20
const LATITUDE := 31.8        # Jerusalém, para a posição do sol
const SUN_DECLINATION := 15.0 # época do ano (primavera)
const SUN_MIN_ALT := 8.0      # altura mínima do sol, em graus, para o amanhecer não escurecer a cena
const HOUR_MIN := 6.0
const HOUR_MAX := 18.0
const HOUR_DEFAULT := 10.0
const DETOUR_RATIO := 2.0     # desvio em volta de unidades: até 2x o caminho direto...
const DETOUR_ADD := 150.0     # ...mais 150 m; acima disso a unidade atravessa as outras
const BLOCK_REPLAN := 1.0     # s parada por outra unidade até recalcular o desvio
const BLOCK_THRU := 5.0       # s parada até aceitar passar por entre as unidades
const CORPSE_CAP := 2500    # corpos desenhados por lado e tipo; os mais antigos somem primeiro
const BLOOD_CAP := 8000     # poças desenhadas
const MIN_LINE_FILES := 10      # largura mínima da linha: 10 soldados na frente
const WIDTH_DRAG_PX := 60.0     # arrasto (px) a partir do qual o botão direito também escolhe a largura
const MIN_MEN := 100
const MAX_MEN := 300
const SIDE_NAMES := ["Israel", "Filisteus"]

const HEAVY := 0
const LIGHT := 1
const SLINGER := 2
const ARCHER := 3
const CHARIOT := 4

const TYPES := [
	{"name": "Infantaria Pesada", "short": "IP", "atk": 10.0, "def": 14.0, "charge": 2.0,
		"walk": 1.3, "run": 3.2, "turn": 0.8, "radius": 0.45, "spacing": 1.2, "ratio": 3.0,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.5,
		"morale": 75.0, "fat": 1.3, "mpm": 1},
	{"name": "Infantaria Leve", "short": "IL", "atk": 8.0, "def": 7.0, "charge": 3.0,
		"walk": 1.6, "run": 4.4, "turn": 1.0, "radius": 0.45, "spacing": 1.5, "ratio": 4.0,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.2,
		"morale": 60.0, "fat": 0.8, "mpm": 1},
	{"name": "Fundeiros", "short": "FU", "atk": 4.0, "def": 3.0, "charge": 0.0,
		"walk": 1.6, "run": 4.6, "turn": 1.0, "radius": 0.45, "spacing": 2.0, "ratio": 5.0,
		"range": 110.0, "ammo": 30, "reload": 3.5, "acc": 0.028, "armor": 0.05,
		"morale": 50.0, "fat": 0.8, "mpm": 1},
	{"name": "Arqueiros", "short": "AR", "atk": 4.0, "def": 3.0, "charge": 0.0,
		"walk": 1.5, "run": 4.2, "turn": 1.0, "radius": 0.45, "spacing": 2.0, "ratio": 5.0,
		"range": 150.0, "ammo": 24, "reload": 4.5, "acc": 0.03, "armor": 0.05,
		"morale": 50.0, "fat": 0.9, "mpm": 1},
	{"name": "Carros de Guerra", "short": "CG", "atk": 14.0, "def": 8.0, "charge": 14.0,
		"walk": 2.5, "run": 8.0, "turn": 0.6, "radius": 1.2, "spacing": 5.0, "ratio": 1.5,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.3,
		"morale": 70.0, "fat": 1.0, "mpm": 2},
]

# --- Moral / pânico ---
const ROUT_MORALE := 15.0
const ROUT_STRENGTH := 0.3      # fração de homens restante
const ROUT_FATIGUE := 95.0
const SEE_ROUT_DIST := 300.0
const SEE_ROUT_LOSS := 5.0
const GENERAL_FLED_LOSS := 25.0
const GENERAL_DEAD_LOSS := 30.0
const GENERAL_AURA := 250.0
const RALLY_COOLDOWN := 60.0    # s entre dois "reunir" do general
const RALLY_NEAR := 300.0       # m: tropas dentro deste raio ganham muito moral e param de fugir
const RALLY_NEAR_GAIN := 35.0
const RALLY_FAR_GAIN := 8.0
