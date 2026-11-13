# Terra Prometida — Batalhas

Jogo de batalhas táticas em tempo real ambientado na Terra Prometida nos tempos do Antigo Testamento. Feito em Godot 4 e jogado no navegador.

A versão 0.17.1 tem um único mapa, Jerusalém, construído a partir de dados reais de elevação, e uma batalha contra a IA.

## Como jogar

1. Na tela de preparo, monte o exército de Israel: até 20 unidades, de 100 a 300 homens cada.
2. Marque qual unidade leva o general.
3. Escolha a hora do dia, das 6:00 às 18:00 (padrão 10:00). A hora define a posição do sol, a cor da luz e a direção das sombras.
4. Inicie a batalha. O exército filisteu espelha a sua composição e ataca pelo planalto ao norte.

Perde o lado que ficar sem nenhuma unidade sob controle.

### Controles

| Ação | Controle |
| --- | --- |
| Selecionar unidade | Clique no card ou no estandarte dela no campo |
| Selecionar várias | Ctrl + clique soma ou tira uma unidade; Shift + clique seleciona todos os cards entre a última unidade selecionada e a clicada |
| Selecionar todas | Ctrl+A |
| Mover | Botão direito no terreno. Arraste antes de soltar para desenhar a linha de frente: as unidades ficam de frente perpendicular à linha (arrastando da esquerda para a direita, olham para cima). Com várias unidades selecionadas, elas formam essa linha lado a lado, centrada no ponto inicial e mantendo a ordem esquerda-direita atual (sem arrasto, mantêm a disposição relativa). Enquanto o botão está pressionado, cada unidade selecionada mostra um retângulo verde com o posto final dela, a linha arrastada e uma seta verde com a direção. Depois da ordem, o destino de cada unidade a caminho fica marcado em branco. Ao concluir o movimento, uma seta amarela no chão mostra a frente por 5 s |
| Escolher a largura da linha | Continue arrastando o botão direito além de 60 px: o comprimento da linha arrastada vira a largura total da linha, repartida entre as unidades selecionadas (mínimo de 10 soldados na frente de cada uma), centrada no meio do trecho arrastado. A prévia troca as caixas por um círculo para cada soldado |
| Atacar | Botão direito no estandarte inimigo (só o estandarte conta; clicar nos soldados não escolhe alvo). Com unidades selecionadas, o estandarte sob o mouse fica com destaque vermelho |
| Correr / andar | R |
| Parar | H |
| Reunir as tropas | G (só a unidade do general, uma vez por minuto): tropas num raio de 300 m ganham muita moral e as que fugiam voltam ao controle; as mais distantes ganham pouca moral |
| Atirar à vontade | F |
| Pausa | P ou Espaço |
| Câmera | WASD ou setas, Q/E para girar, roda do mouse para zoom |

As unidades só são selecionadas pelos cards. Ordens para fora da área controlável (linha clara no chão) são limitadas à borda.

### Unidades

| Tipo | Papel |
| --- | --- |
| Infantaria Pesada | Linha de frente: lenta, bem protegida, cansa mais rápido |
| Infantaria Leve | Rápida, boa nos flancos e na perseguição |
| Fundeiros | Atiradores de alcance médio, mais munição |
| Arqueiros | Atiradores de alcance longo |
| Carros de Guerra | Carga forte, 2 homens por carro, não sobem declives acima de 12° |

### Status de cada unidade

- **Soldados:** vivos sobre o total inicial.
- **Moral:** cai com baixas, ataques pelo flanco, cansaço, inimigo em terreno mais alto e ao ver aliados fugirem. Cai muito se o general fugir ou morrer.
- **Cansaço:** sobe ao correr, lutar e subir; desce com a unidade parada.
- **Força:** multiplicador de combate, resultado de cansaço, moral e diferença de altura para o oponente.
- **Munição:** só para fundeiros e arqueiros.

Uma unidade entra em pânico e foge quando a moral fica muito baixa, quando restam 30% dos homens ou quando está exausta em combate. Unidades em fuga não podem ser comandadas e correm para fora da área controlável.

### Configurações

Com o jogo pausado (tecla P ou botão Pausa) aparece a tela de configurações, com estas opções:

- **Hora do dia:** muda a hora (6:00 a 18:00) durante a partida; o sol, o céu e as sombras acompanham na hora.
- **Sol:** liga e desliga a luz do sol. Desligado, a cena fica só com luz ambiente.
- **Sombras:** liga e desliga todas as sombras (terreno e unidades).
- **Sombras nas unidades:** liga e desliga as sombras projetadas pelas unidades (precisa de Sombras ligadas).
- **Mostrar FPS:** exibe os quadros por segundo no canto superior direito (desligado por padrão).

As escolhas são guardadas em `user://settings.cfg` e valem nas próximas partidas.

### Caminhos e desvios

- Ao receber uma ordem de movimento ou de ataque, a unidade dá a volta nas formações das outras unidades. Só atravessa por entre elas se o desvio for muito grande (mais que o dobro do caminho direto mais 150 m) ou se não houver caminho livre.
- Se outra unidade entrar no caminho, ela espera em vez de empurrar os soldados dela; depois de 1 s recalcula o desvio, e depois de 5 s parada aceita passar por entre as unidades.
- Soldados só andam quando o passo os aproxima do posto: os que não têm espaço ficam parados em vez de tremer no lugar.
- Unidades selecionadas mostram o caminho que vão percorrer, em seta branca opaca. Ao passar o mouse sobre o estandarte de uma unidade amiga não selecionada que esteja em movimento, aparecem o caminho e o quadrado do destino com 50% de transparência.

### Luz e sombras

O sol segue a posição real em Jerusalém na primavera: nasce a leste, passa ao sul ao meio-dia e se põe a oeste. De manhã e no fim da tarde a luz é mais quente e fraca e as sombras são longas; ao meio-dia são curtas. O terreno e as unidades projetam sombra; os corpos dos mortos não. A hora escolhida é lembrada ao voltar ao preparo. Perto das 6:00 e das 18:00 o sol é mantido a pelo menos 8° do horizonte para a cena não escurecer demais.

### Mortos

Quem morre fica no campo: o corpo cai deitado (o carro tomba de lado) e uma poça de sangue escurece o chão em volta. Os mortos são só visuais, não bloqueiam ninguém e não são atingidos. O jogo desenha até 2.500 corpos por lado e tipo de unidade e 8.000 poças; depois disso os mais antigos desaparecem primeiro. Quem foge para fora do mapa não deixa corpo.

### Terreno

- Quem está mais baixo que o oponente luta pior; quem está mais alto luta melhor e atira mais longe.
- Subir cansa, e correr na subida cansa mais.
- Declives acima de 12° barram os carros.
- Declives acima de 32° barram todos. A partir de 12° o terreno aparece como rocha, com estratos e fissuras.
- Algumas áreas planas têm vegetação rasteira, com tufos visíveis de perto.
- A área visível (4 × 4 km) é maior que a área controlável (2,4 × 2,4 km).

## Sons

Os sons ficam em `assets/sounds/` e são tocados por `scripts/sfx.gd`. Os cliques e os sons de vitória e derrota vêm do jogo de tabuleiro Promised Land; as vozes são próprias deste jogo. Só uma voz toca por vez: a nova interrompe a anterior.

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
| Combate em curso | `choque1` a `choque6`, sorteados a cada fração de segundo (armas contra armas, OpenGameArt, CC0), mais altos com mais unidades em contato. O `sword` toca só na ordem de atacar |
| Pânico da unidade do general (suas tropas) | `fuga-general` ou `fuga-general2`, sorteado |
| Pânico de outra unidade sua | `fuga1` ou `fuga2`, sorteado |
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
- Unidades em fuga só voltam ao controle se o general as reunir (tecla G, a uma distância curta).
- Os corpos mais antigos desaparecem depois do limite de 2.500 por lado e tipo.
- Em combate geral com fuga em massa, o relógio do jogo pode desacelerar no navegador; o número de soldados nunca é reduzido.
