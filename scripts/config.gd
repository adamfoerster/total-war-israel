extends RefCounted
## Constantes globais e tabela de tipos de unidade.

# --- Mapa ---
const HALF_MAP := 2000.0        # área visível: 4 x 4 km
const CONTROL_HALF := 1200.0    # área controlável: 2,4 x 2,4 km
const EXIT_HALF := 1450.0       # fugitivos somem 250 m depois de sair da área controlável
const HM_N := 401               # nós do heightmap
const HM_CELL := 10.0           # metros por nó
const VERT_EXAG := 1.0
const SLOPE_CHARIOT := 15.0     # graus: acima disso carros não passam
const SLOPE_ROCK := 12.0       # graus: a partir daqui o terreno recebe a textura de rocha
const SLOPE_IMPASS := 25.0      # graus: acima disso ninguém passa
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
const HOUR_DEFAULT := 6.0
# Setores de posicionamento: a área controlável é dividida em 3 faixas iguais no eixo
# norte-sul. Israel posiciona no sul (z > SECTOR_HALF), os filisteus no norte
# (z < -SECTOR_HALF); a faixa do meio fica livre.
const SECTOR_HALF := CONTROL_HALF / 3.0
const DEPLOY_ORIGIN := [Vector2(-450, 480), Vector2(-450, -480)]   # frente da linha inicial, por lado
const DEPLOY_FACING := [Vector2(0, -1), Vector2(0, 1)]
const DETOUR_RATIO := 2.0     # perseguição de alvo: desvio em volta de unidades: até 2x o caminho direto...
const DETOUR_ADD := 150.0     # ...mais 150 m; acima disso a unidade atravessa as outras
# Postura: defensiva só luta se atacada; neutra ataca inimigos a menos de STANCE_ENGAGE m;
# agressiva também ataca e persegue quem foge.
const STANCE_DEFENSIVE := 0
const STANCE_NEUTRAL := 1
const STANCE_AGGRESSIVE := 2
const STANCE_NAMES := ["defensiva", "neutra", "agressiva"]
const STANCE_ENGAGE := 50.0   # m entre as bordas das formações para o ataque automático
const CORPSE_CAP := 2500    # corpos desenhados por lado e tipo; os mais antigos somem primeiro
const BLOOD_CAP := 8000     # poças desenhadas
const MIN_LINE_FILES := 10      # largura mínima da linha: 10 soldados na frente
const SQUEEZE_MIN_FILES := 3    # frente mínima ao estreitar para passar por um vão
const SQUEEZE_CHECK := 0.5      # s entre medições do vão à frente
const SQUEEZE_PROBE_STEP := 8.0 # m entre os pontos de medição do vão ao longo da coluna
const WIDTH_DRAG_PX := 60.0     # arrasto (px) a partir do qual o botão direito também escolhe a largura
const SIDE_NAMES := ["Israel", "Filisteus"]

const HEAVY := 0
const LIGHT := 1
const SLINGER := 2
const ARCHER := 3
const CHARIOT := 4

const SURRENDER_RATIO := 1.0 / 3.0   # a IA se rende com menos que essa fração da força do inimigo

# men_min / men_def / men_max: homens por unidade na tela de preparo (mínimo, padrão, máximo);
# men_step: passo do controle deslizante; power: pontos de força por modelo (soldado, ou
# carro de guerra com seus 2 homens), usados na barra de força e na rendição da IA
const TYPES := [
	{"name": "Infantaria Pesada", "short": "IP", "atk": 10.0, "def": 14.0, "charge": 2.0,
		"walk": 1.3, "run": 3.2, "turn": 0.8, "radius": 0.45, "spacing": 1.2, "ratio": 3.0,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.5,
		"morale": 75.0, "fat": 1.3, "mpm": 1,
		"men_min": 20, "men_def": 70, "men_max": 100, "men_step": 10, "power": 2},
	{"name": "Infantaria Leve", "short": "IL", "atk": 8.0, "def": 7.0, "charge": 3.0,
		"walk": 1.6, "run": 4.4, "turn": 1.0, "radius": 0.45, "spacing": 1.5, "ratio": 4.0,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.2,
		"morale": 60.0, "fat": 0.8, "mpm": 1,
		"men_min": 20, "men_def": 100, "men_max": 160, "men_step": 10, "power": 1},
	{"name": "Fundeiros", "short": "FU", "atk": 4.0, "def": 3.0, "charge": 0.0,
		"walk": 1.6, "run": 4.6, "turn": 1.0, "radius": 0.45, "spacing": 2.0, "ratio": 5.0,
		"range": 110.0, "ammo": 30, "reload": 3.5, "acc": 0.028, "armor": 0.05,
		"morale": 50.0, "fat": 0.8, "mpm": 1,
		"men_min": 20, "men_def": 60, "men_max": 100, "men_step": 10, "power": 1},
	{"name": "Arqueiros", "short": "AR", "atk": 4.0, "def": 3.0, "charge": 0.0,
		"walk": 1.5, "run": 4.2, "turn": 1.0, "radius": 0.45, "spacing": 2.0, "ratio": 5.0,
		"range": 150.0, "ammo": 24, "reload": 4.5, "acc": 0.03, "armor": 0.05,
		"morale": 50.0, "fat": 0.9, "mpm": 1,
		"men_min": 20, "men_def": 60, "men_max": 100, "men_step": 10, "power": 2},
	{"name": "Carros de Guerra", "short": "CG", "atk": 14.0, "def": 8.0, "charge": 14.0,
		"walk": 2.5, "run": 8.0, "turn": 0.6, "radius": 1.2, "spacing": 5.0, "ratio": 1.5,
		"range": 0.0, "ammo": 0, "reload": 0.0, "acc": 0.0, "armor": 0.3,
		"morale": 70.0, "fat": 1.0, "mpm": 2,
		"men_min": 10, "men_def": 20, "men_max": 50, "men_step": 2, "power": 4},
]

# --- Moral / pânico ---
const ROUT_MORALE := 15.0
const ROUT_STRENGTH := 0.3      # fração de homens restante
const ROUT_FATIGUE := 95.0
const SEE_ROUT_DIST := 300.0
const SEE_ROUT_LOSS := 5.0
const ROUT_CREDIT_GAIN := 15.0   # moral para quem atacava a unidade que entrou em pânico
const ROUT_CREDIT_WINDOW := 6.0  # s: só conta quem golpeou ou acertou disparos nesse intervalo
const GENERAL_FLED_LOSS := 25.0
const GENERAL_DEAD_LOSS := 30.0
const GENERAL_AURA := 250.0
const RALLY_COOLDOWN := 60.0    # s entre dois "reunir" do general
const RALLY_NEAR := 300.0       # m: tropas dentro deste raio ganham muito moral e param de fugir
const RALLY_NEAR_GAIN := 35.0
const RALLY_FAR_GAIN := 8.0
