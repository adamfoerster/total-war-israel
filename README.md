# Terra Prometida — Batalhas

Jogo de batalhas táticas em tempo real ambientado na Terra Prometida nos tempos do Antigo Testamento. Feito em Godot 4 e jogado no navegador.

A versão 0.19.0 tem um único mapa, Jerusalém, construído a partir de dados reais de elevação, e uma batalha contra a IA.

## Como jogar

1. Na tela de preparo, monte o exército de Israel: até 20 unidades. O número de homens de cada uma depende do tipo (tabela em [Unidades](#unidades)); ao trocar o tipo, a unidade volta ao número padrão do novo tipo.
2. Marque qual unidade leva o general.
3. Escolha a hora do dia, das 6:00 às 18:00 (padrão 6:00). A hora define a posição do sol, a cor da luz e a direção das sombras.
4. Inicie a batalha. O exército filisteu espelha a sua composição e ataca pelo planalto ao norte.
5. Posicione as unidades. A área controlável é dividida em 3 faixas iguais de norte a sul: Israel se posiciona na faixa sul (azul), os filisteus na faixa norte (vermelha), e a faixa do meio fica livre. Nessa fase o tempo não corre: selecione as unidades e use o botão direito como numa ordem de mover (arrastando para escolher frente e largura). Elas vão direto para o posto, sem marchar, e nunca saem da faixa azul. Clique em **Iniciar batalha** ou tecle Enter para começar; as faixas somem.

Perde o lado que ficar sem nenhuma unidade sob controle, ou que se render.

A força de cada lado soma pontos pelos soldados das unidades sob controle (em fuga não contam): 1 por soldado de infantaria leve ou fundeiro, 2 por infantaria pesada ou arqueiro e 4 por carro de guerra. Uma barra no alto da tela mostra a força atual dos dois lados (azul Israel, vermelho filisteus) com os pontos de cada um; o traço branco marca onde os filisteus se rendem. O computador se rende quando a força dele fica abaixo de um terço da sua. Você pode se render a qualquer momento pelo botão **Render-se**, que pede confirmação e dá a vitória aos filisteus.

### Controles

| Ação | Controle |
| --- | --- |
| Selecionar unidade | Clique no card ou no estandarte dela no campo |
| Selecionar várias | Ctrl + clique soma ou tira uma unidade; Shift + clique seleciona todos os cards entre a última unidade selecionada e a clicada |
| Selecionar por área | Arraste com o botão esquerdo no campo: seleciona as unidades cujo estandarte fica dentro do retângulo. Com Ctrl ou Shift, soma à seleção atual |
| Selecionar todas | Ctrl+A |
| Mover | Botão direito no terreno. Arraste antes de soltar para desenhar a linha de frente: as unidades ficam de frente perpendicular à linha (arrastando da esquerda para a direita, olham para cima). Com várias unidades selecionadas, elas formam essa linha lado a lado, centrada no ponto inicial e mantendo a ordem esquerda-direita atual (sem arrasto, mantêm a disposição relativa). Enquanto o botão está pressionado, cada unidade selecionada mostra um retângulo verde com o posto final dela, a linha arrastada e uma seta verde com a direção. Depois da ordem, o destino de cada unidade a caminho fica marcado em branco. Ao concluir o movimento, uma seta amarela no chão mostra a frente por 5 s |
| Escolher a largura da linha | Continue arrastando o botão direito além de 60 px: o comprimento da linha arrastada vira a largura total da linha, repartida entre as unidades selecionadas (mínimo de 10 soldados na frente de cada uma), centrada no meio do trecho arrastado. A prévia troca as caixas por um círculo para cada soldado |
| Atacar | Botão direito no estandarte inimigo (só o estandarte conta; clicar nos soldados não escolhe alvo). Com unidades selecionadas, o estandarte sob o mouse fica com destaque vermelho |
| Correr / andar | R |
| Parar | H |
| Reunir as tropas | G (só a unidade do general, uma vez por minuto): tropas num raio de 300 m ganham muita moral e as que fugiam voltam ao controle; as mais distantes ganham pouca moral |
| Atirar à vontade | F |
| Iniciar a batalha (fim do posicionamento) | Enter ou botão **Iniciar batalha** |
| Render-se | Botão **Render-se** (pede confirmação) |
| Pausa | P ou Espaço |
| Câmera | WASD ou setas, Q/E para girar, roda do mouse para zoom |

As unidades só são selecionadas pelos cards. Ordens para fora da área controlável (linha clara no chão) são limitadas à borda.

### Unidades

| Tipo | Papel | Homens (padrão / mínimo–máximo) |
| --- | --- | --- |
| Infantaria Pesada | Linha de frente: lenta, bem protegida, cansa mais rápido | 70 / 20–100 |
| Infantaria Leve | Rápida, boa nos flancos e na perseguição | 100 / 20–160 |
| Fundeiros | Atiradores de alcance médio, mais munição | 60 / 20–100 |
| Arqueiros | Atiradores de alcance longo | 60 / 20–100 |
| Carros de Guerra | Carga forte, 2 homens por carro, não sobem declives acima de 15° | 20 / 10–50 |

### Status de cada unidade

- **Soldados:** vivos sobre o total inicial.
- **Moral:** cai com baixas, ataques pelo flanco, cansaço, inimigo em terreno mais alto e ao ver aliados fugirem. Cai muito se o general fugir ou morrer.
- **Cansaço:** sobe ao correr, lutar e subir; desce com a unidade parada.
- **Força:** multiplicador de combate, resultado de cansaço, moral e diferença de altura para o oponente.
- **Munição:** só para fundeiros e arqueiros.

Uma unidade entra em pânico e foge quando a moral fica muito baixa, quando restam 30% dos homens ou quando está exausta em combate. Unidades em fuga não podem ser comandadas e correm para fora da área controlável.

Quando uma unidade inimiga entra em pânico, as unidades que a atacavam ganham 15 de moral, sem passar do teto (a moral base, mais 10 perto do general). Só contam as que a golpearam no corpo a corpo ou acertaram disparos nela nos últimos 6 s. Quem estava apenas marchando até ela não ganha nada.

### Configurações

Com o jogo pausado (tecla P ou botão Pausa) aparece a tela de configurações, com estas opções:

- **Hora do dia:** muda a hora (6:00 a 18:00) durante a partida; o sol, o céu e as sombras acompanham na hora.
- **Sol:** liga e desliga a luz do sol. Desligado, a cena fica só com luz ambiente.
- **Sombras:** liga e desliga todas as sombras (terreno e unidades).
- **Sombras nas unidades:** liga e desliga as sombras projetadas pelas unidades (precisa de Sombras ligadas).
- **Mostrar FPS:** exibe os quadros por segundo no canto superior direito (desligado por padrão).
- **Depuração: pintar acesso do terreno:** cobre o relevo com cores conforme quem consegue passar: vermelho onde nem soldados a pé passam, amarelo onde só eles passam (carros não) e verde onde todos passam.
- **Declive máximo a pé** e **Declive máximo dos carros** (2° a 60°; padrão 25° e 15°): mudam, durante a partida, o declive que cada um consegue vencer. Os caminhos e a camada de cores são refeitos 0,3 s depois de soltar o controle. O limite dos carros nunca passa do limite a pé.

As escolhas são guardadas em `user://settings.cfg` e valem nas próximas partidas, exceto os dois declives máximos, que voltam ao padrão a cada partida.

### Caminhos e desvios

- O caminho de uma ordem de movimento ou de ataque só desvia de obstáculos do terreno (declives que o tipo da unidade não vence). Outras unidades no trajeto não são contornadas: muitas vezes já terão saído do caminho quando a unidade chegar lá.
- Se encontra outras unidades no trajeto, a unidade passa pelo vão entre elas estreitando a frente: o vão é medido à frente dela e a nova frente é o número de soldados que cabem no vão menos um (arredondado para baixo; num vão de 6, a frente vira 5). Depois de passar, volta à largura original. Abaixo de 3 soldados na frente ela não estreita e passa por entre as unidades, como antes.
- Soldados só andam quando o passo os aproxima do posto: os que não têm espaço ficam parados em vez de tremer no lugar.
- Unidades selecionadas mostram o caminho que vão percorrer, em seta branca opaca. Ao passar o mouse sobre o estandarte de uma unidade amiga não selecionada que esteja em movimento, aparecem o caminho e o quadrado do destino com 50% de transparência.

### Luz e sombras

O sol segue a posição real em Jerusalém na primavera: nasce a leste, passa ao sul ao meio-dia e se põe a oeste. De manhã e no fim da tarde a luz é mais quente e fraca e as sombras são longas; ao meio-dia são curtas. O terreno e as unidades projetam sombra; os corpos dos mortos não. A hora escolhida é lembrada ao voltar ao preparo. Perto das 6:00 e das 18:00 o sol é mantido a pelo menos 8° do horizonte para a cena não escurecer demais.

### Mortos

Quem morre fica no campo: o corpo cai deitado (o carro tomba de lado) e uma poça de sangue escurece o chão em volta. Os mortos são só visuais, não bloqueiam ninguém e não são atingidos. O jogo desenha até 2.500 corpos por lado e tipo de unidade e 8.000 poças; depois disso os mais antigos desaparecem primeiro. Quem foge para fora do mapa não deixa corpo.

### Terreno

- Quem está mais baixo que o oponente luta pior; quem está mais alto luta melhor e atira mais longe.
- Subir cansa, e correr na subida cansa mais.
- Declives acima de 15° barram os carros.
- Declives acima de 25° barram todos. A partir de 12° o terreno aparece como rocha, com estratos e fissuras.
- Algumas áreas planas têm vegetação rasteira, com tufos visíveis de perto.
- A área visível (4 × 4 km) é maior que a área controlável (2,4 × 2,4 km).

## Sons

Os sons ficam em `assets/sounds/` e são tocados por `scripts/sfx.gd`. Os cliques e os sons de vitória e derrota vêm do jogo de tabuleiro Promised Land; as vozes são próprias deste jogo. Os gritos de dor são trechos de [Male Grunt/Yelling sounds](https://opengameart.org/content/male-gruntyelling-sounds), de HaelDB (OpenGameArt, CC0), cortados e convertidos para mono. Os sons de flechas e fundas são sintetizados por `tools/gen_sounds.js` (`node tools/gen_sounds.js` os recria). Só uma voz toca por vez: a nova interrompe a anterior.

Os sons de fuga, de dor e de disparo saem do ponto do mapa onde está a unidade: a câmera é o ouvinte, então uma unidade fora da tela à esquerda é ouvida pela esquerda, e o volume cai com a distância. Os choques do combate também saem das unidades em combate. Os demais sons (ordens, interface) tocam sem posição.

| Interação | Som |
| --- | --- |
| Selecionar unidade (card ou estandarte) e escolher o general | `select2` |
| Botões do preparo e tecla de atirar à vontade | `menu-select` |
| Início da partida | `inicio-bom`, `inicio-medio` ou `inicio-ruim`, sorteado |
| Ordem de movimento | `march` |
| Passar a andar (tecla R) | `andar` |
| Passar a correr (tecla R) | `correr` |
| Parar (H) | `parar` |
| Ordem de ataque | `sword` em 90% das vezes. Nos outros 10%, a voz da unidade: `carruagens`, `arqueiros` ou `infantaria-pesada`; as demais unidades usam `ataquem`. A unidade vem de um sorteio entre as selecionadas |
| Combate em curso | `choque1` a `choque6` (armas contra armas, OpenGameArt, CC0), cada um vindo de uma unidade em combate sorteada; mais frequentes com mais unidades em combate e mais altos com mais soldados em contato. O `sword` toca só na ordem de atacar |
| Pânico da unidade do general (suas tropas) | `fuga-general` ou `fuga-general2`, sorteado, vindo da unidade |
| Pânico de outra unidade sua | `fuga1` ou `fuga2`, sorteado, vindo da unidade |
| Unidade perde homens (qualquer lado) | `dor01` a `dor12` (4 vozes), sorteados, vindos da unidade; no máximo um a cada ~1,6 s por unidade, mais alto com mais baixas de uma vez |
| Volley de arqueiros | `flechas`, vindo da unidade que dispara |
| Volley de fundeiros | `fundas`, vindo da unidade que dispara |
| General reúne as tropas (G) | `reunir` |
| Fim da batalha | `win` ou `lose` |

## Como rodar

É preciso o Godot 4.7 com os export templates de Web, e o Node para servir o build.

Exportar o build Web:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

Servir em `http://localhost:8060`:

```bash
node tools/serve.js 8060
```

Também é possível abrir o projeto no editor do Godot e rodar a cena principal.

## Testes

Testes da simulação (regras de terreno, moral, general e uma batalha IA × IA de 20 × 20 unidades):

```bash
godot --headless --path . -- --simtest
```

A batalha usa uma semente aleatória, impressa no início. Para repetir uma rodada exata, passe a semente; `--so-batalha` pula os testes curtos:

```bash
godot --headless --path . -- --simtest --so-batalha --seed 87122
```

Teste de fumaça da interface (preparo, batalha, ordens, resultado):

```bash
godot --headless --path . -- --uitest
```

## Mapa

O relevo vem dos AWS Terrain Tiles (formato Terrarium, derivado de SRTM de ~30 m), recortado em 4 × 4 km ao redor da Cidade de Davi e reamostrado para uma grade de 10 m. Na conversão, uma passada leve de suavização remove os degraus da reamostragem e um ruído fractal de 6 m acrescenta relevo fino (parâmetros em `tools/build_heightmap.gd`). O heightmap já convertido está em `assets/jerusalem_height.res`.

Para gerá-lo de novo, baixe os quatro tiles de zoom 13 (x 4897–4898, y 3332–3333) para `tools/dem_raw/` e rode:

```bash
godot --headless --path . -s tools/build_heightmap.gd
```

## Limitações conhecidas

- Os dados de 30 m suavizam as escarpas e incluem a superfície moderna da cidade.
- Não há muralhas nem edifícios.
- O relevo divide o terreno dos carros em regiões separadas por declives acima de 15°. Carros posicionados numa região pequena só alcançam inimigos que entrem nela; a IA não manda carros (nem infantaria) atrás de inimigos de outra região.
- Unidades em fuga só voltam ao controle se o general as reunir (tecla G, a uma distância curta).
- Os corpos mais antigos desaparecem depois do limite de 2.500 por lado e tipo.
- Em combate geral com fuga em massa, o relógio do jogo pode desacelerar no navegador; o número de soldados nunca é reduzido.
