# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa [versionamento semântico](https://semver.org/lang/pt-BR/).

## [0.17.1] - 2026-11-12

### Adicionado

- Hora do dia na tela de configurações: muda o sol, o céu e as sombras com a partida em andamento.

### Alterado

- A tela de configurações ganhou margem interna (padding).

## [0.17.0] - 2026-11-12

### Adicionado

- Tela de configurações, exibida com o jogo pausado: ligar e desligar o sol, as sombras, as sombras nas unidades e a exibição de FPS. As escolhas são salvas.

### Alterado

- O FPS saiu do texto do canto superior esquerdo e agora aparece, se ativado, no canto superior direito.

## [0.16.2] - 2026-11-12

### Alterado

- Terreno mais acidentado: uma passada de suavização a menos no mapa de elevação e relevo fino acrescentado (ruído fractal de 6 m de amplitude). Os valores estão em `tools/build_heightmap.gd` (`SMOOTH_PASSES`, `DETAIL_AMP`, `DETAIL_WAVE`).

## [0.16.1] - 2026-11-12

### Alterado

- A textura de rocha passa a valer a partir de 12° de declive (antes, só nos intransponíveis, acima de 32°).

## [0.16.0] - 2026-11-12

### Adicionado

- Textura de parede rochosa (estratos, manchas e fissuras) nos declives intransponíveis.
- Textura de vegetação rasteira em manchas nas áreas mais planas, com tufos de perto.
- Terreno desenhado por um shader próprio (`shaders/terrain.gdshader`) com texturas procedurais.

## [0.15.0] - 2026-11-12

### Adicionado

- Setas com o caminho das unidades: opaco para as selecionadas; ao passar o mouse sobre o estandarte de uma unidade amiga não selecionada, caminho e quadrado do destino com 50% de transparência.
- Desvio em volta das outras unidades no cálculo do caminho; só atravessa por entre elas quando o desvio é muito grande.

### Alterado

- A unidade espera quando outra formação bloqueia o caminho, recalcula o desvio depois de 1 s e passa por entre as unidades só depois de 5 s parada.

### Corrigido

- Soldados que não conseguiam avançar tremiam no lugar; agora só se movem quando o passo os aproxima do posto.

## [0.14.0] - 2026-11-12

### Adicionado

- Seletor de hora do dia (6:00 a 18:00) na tela de preparo.
- Sol com posição, cor e intensidade conforme a hora, e céu em tom correspondente.
- Sombras projetadas pelo terreno e pelas unidades.

## [0.13.1] - 2026-11-12

### Alterado

- Avisos do canto superior esquerdo ganham fundo preto 50% transparente e somem 5 segundos depois de aparecer.

### Removido

- Texto de atalhos do canto superior direito da tela (os atalhos continuam na tabela de Controles do README).

## [0.13.0] - 2026-11-12

### Adicionado

- Sons de combate em curso: seis choques de armas (`choque1` a `choque6`) do pacote CC0 de armas contra armas do OpenGameArt, sorteados a intervalos curtos enquanto há unidades em contato. Sem canhão nem o `sword` como marcador de dano.

## [0.12.1] - 2026-11-12

### Removido

- Som de combate em curso: o `sword` não marca mais o dano e o `batalha` (do Mixkit, com som de canhão, que não existia no mundo antigo) foi retirado. O `sword` toca só na ordem de atacar.

## [0.12.0] - 2026-11-12

### Adicionado

- Soldados mortos permanecem no campo, deitados e intangíveis (só visuais), com uma poça de sangue no chão em volta. O carro destruído tomba de lado.

### Alterado

- Os soldados mortos não somem mais do campo; só os mais antigos saem depois de 2.500 corpos por lado e tipo.

## [0.11.0] - 2026-11-12

### Adicionado

- Som de batalha campal (`batalha`, do Mixkit) enquanto há unidades em combate, junto das espadas.

## [0.10.1] - 2026-11-12

### Alterado

- Ordem de movimento volta a tocar `march`. Os sons `andar` e `correr` tocam só ao alternar entre andar e correr (tecla R).

## [0.10.0] - 2026-11-12

### Adicionado

- Novas vozes: andar, correr e parar a cada comando; fuga do general (`fuga-general`, `fuga-general2`) e de outras unidades (`fuga1`, `fuga2`); início da partida (`inicio-bom`, `inicio-medio`, `inicio-ruim`); ordem de ataque com voz de carros, arqueiros, infantaria pesada (10% das vezes) ou `ataquem` para as demais unidades.
- Reunir (tecla G, botão no HUD): o general tenta parar a debandada. Tropas num raio de 300 m ganham muita moral e as que fugiam voltam ao controle; as distantes ganham pouca moral. Uma vez por minuto, com o som `reunir`.

### Alterado

- Removido o som de marcha ao ordenar movimento, substituído por `andar` ou `correr`.

## [0.9.2] - 2026-11-12

### Alterado

- Ordem de ataque só com clique direito no estandarte inimigo; clicar nos soldados (por exemplo de uma unidade em fuga) não escolhe mais alvo.

## [0.9.1] - 2026-11-12

### Alterado

- A frente das unidades agora é perpendicular à linha arrastada com o botão direito (arrastando da esquerda para a direita, olham para cima). No modo de largura, a linha ocupa o trecho arrastado, centrada no meio dele.

## [0.9.0] - 2026-11-12

### Adicionado

- Seletor de largura da linha: ao arrastar o botão direito além de 60 px, a distância arrastada define a largura total da linha e cada unidade muda sua formação para a largura proporcional (mínimo de 10 soldados na frente). Na prévia, as caixas viram um círculo por soldado.
- Ordem de reformar a largura da formação na simulação (`order_reform`), com teste no `--simtest`.

## [0.8.0] - 2026-11-12

### Alterado

- Ao definir a frente arrastando o botão direito com várias unidades selecionadas, elas passam a formar uma linha de frente lado a lado (a prévia verde mostra cada posto), em vez de manter a posição relativa e só girar.

## [0.7.0] - 2026-11-12

### Adicionado

- Destaque vermelho no estandarte inimigo sob o mouse quando há unidades selecionadas, indicando que o botão direito ordenará um ataque.

## [0.6.0] - 2026-11-12

### Alterado

- Shift + clique em um card ou estandarte agora seleciona todas as unidades entre a última selecionada e a clicada; Ctrl + clique continua somando ou tirando uma unidade.

## [0.5.0] - 2026-11-12

### Adicionado

- Efeitos sonoros reaproveitados do jogo de tabuleiro Promised Land: cliques de seleção e de menu, marcha ao ordenar movimento, espadas ao ordenar ataque e durante o corpo a corpo, e sons de vitória e derrota na tela de resultado.

## [0.4.0] - 2026-11-12

### Adicionado

- Marcador individual no chão para cada unidade selecionada, mostrando o posto final dela ao dar uma ordem de movimento (verde durante a ordem, branco enquanto a unidade ainda está a caminho).

## [0.3.0] - 2026-11-12

### Adicionado

- Seta verde de prévia da frente enquanto se arrasta o botão direito para dar uma ordem de movimento.

## [0.2.1] - 2026-11-12

### Adicionado

- Seta amarela no chão indicando a frente da unidade por 5 s ao concluir uma movimentação.

## [0.2.0] - 2026-11-12

### Adicionado

- Seleção de unidades clicando no estandarte dela no campo; Ctrl ou Shift + clique soma ou tira da seleção.

## [0.1.0] - 2026-11-12

Primeira versão jogável.

### Adicionado

- Mapa de Jerusalém com relevo real (AWS Terrain Tiles, ~30 m), em uma área visível de 4 × 4 km com área controlável de 2,4 × 2,4 km.
- Cinco tipos de unidade: infantaria pesada, infantaria leve, fundeiros, arqueiros e carros de guerra.
- Tela de preparo para montar o exército (até 20 unidades de 100 a 300 homens) e escolher a unidade do general.
- Controle das tropas pelos cards: mover, atacar, correr ou andar, parar e atirar à vontade.
- Status por unidade que variam na batalha: soldados, moral, cansaço, força e munição.
- Efeitos do terreno: vantagem de altura no combate e no alcance dos atiradores, e cansaço maior ao subir, sobretudo correndo.
- Limites de declive: acima de 12° barra os carros, acima de 32° barra todos.
- Pânico e fuga por moral baixa, muitas baixas ou exaustão em combate, com perda de moral para quem vê aliados fugirem e perda grande quando o general foge ou morre.
- Fugitivos correm para fora da área controlável por uma rota que contorna os declives proibidos, e saem do campo 250 m depois da borda.
- Derrota do lado que ficar sem unidades sob controle, com tela de resultado.
- IA inimiga simples: avanço em faixas, atiradores que mantêm distância e carros que caçam atiradores e infantaria leve.
- Colisão entre soldados, com grade espacial incremental e processamento só dos soldados fora do posto ou em contato com o inimigo.
- Modelos simplificados sem animação, desenhados com MultiMesh, e terreno com cores por vértice.
- Export para Web sem threads e servidor estático local (`tools/serve.js`).
- Testes headless da simulação (`--simtest`) e teste de fumaça da interface (`--uitest`).

### Limitações conhecidas

- Sem muralhas nem edifícios.
- Unidades em fuga não se reagrupam.
- Soldados mortos somem do campo.
- O relógio do jogo pode desacelerar no navegador em combate geral com fuga em massa.
