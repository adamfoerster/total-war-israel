# Terra Prometida — Batalhas

Jogo de batalhas táticas em tempo real ambientado na Terra Prometida nos tempos do Antigo Testamento. Feito em Godot 4 e jogado no navegador.

A versão 0.1.0 tem um único mapa, Jerusalém, construído a partir de dados reais de elevação, e uma batalha contra a IA.

## Como jogar

1. Na tela de preparo, monte o exército de Israel: até 20 unidades, de 100 a 300 homens cada.
2. Marque qual unidade leva o general.
3. Inicie a batalha. O exército filisteu espelha a sua composição e ataca pelo planalto ao norte.

Perde o lado que ficar sem nenhuma unidade sob controle.

### Controles

| Ação | Controle |
| --- | --- |
| Selecionar unidade | Clique no card |
| Selecionar várias | Ctrl ou Shift + clique no card |
| Selecionar todas | Ctrl+A |
| Mover | Botão direito no terreno (arraste para definir a direção da frente) |
| Atacar | Botão direito no estandarte inimigo |
| Correr / andar | R |
| Parar | H |
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

### Terreno

- Quem está mais baixo que o oponente luta pior; quem está mais alto luta melhor e atira mais longe.
- Subir cansa, e correr na subida cansa mais.
- Declives acima de 12° barram os carros.
- Declives acima de 32° barram todos.
- A área visível (4 × 4 km) é maior que a área controlável (2,4 × 2,4 km).

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

O relevo vem dos AWS Terrain Tiles (formato Terrarium, derivado de SRTM de ~30 m), recortado em 4 × 4 km ao redor da Cidade de Davi e reamostrado para uma grade de 10 m. O heightmap já convertido está em `assets/jerusalem_height.res`.

Para gerá-lo de novo, baixe os quatro tiles de zoom 13 (x 4897–4898, y 3332–3333) para `tools/dem_raw/` e rode:

```bash
godot --headless --path . -s tools/build_heightmap.gd
```

## Limitações conhecidas

- Os dados de 30 m suavizam as escarpas e incluem a superfície moderna da cidade.
- Não há muralhas nem edifícios.
- Unidades em fuga não se reagrupam.
- Soldados mortos somem do campo.
- Em combate geral com fuga em massa, o relógio do jogo pode desacelerar no navegador; o número de soldados nunca é reduzido.
