# Changelog

Todas as mudanças relevantes deste projeto são registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa [versionamento semântico](https://semver.org/lang/pt-BR/).

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
