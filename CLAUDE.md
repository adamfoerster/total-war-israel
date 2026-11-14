# CLAUDE.md

Jogo de batalhas táticas em Godot 4.7 (GDScript, renderer Compatibility), exportado para Web sem threads. Interface e comentários em português.

## Comandos

O Godot não está no PATH. Use o executável `_console` para rodar headless; nos comandos abaixo, `godot` é esse executável.

```bash
godot --headless --path . -- --simtest      # testes da simulação
godot --headless --path . -- --uitest       # teste de fumaça da interface
godot --headless --path . --export-release "Web" build/web/index.html
node tools/serve.js 8060                    # serve build/web
```

Para publicar online, exporte o build Web e envie os arquivos de `build/web` (sem os `*.import`) por `scp` para `reinoeterno@reinoeterno.online:/home/reinoeterno/promisedland-battles.reinoeterno.online/`. O comando completo está na seção "Publicar online" do `README.md`.

Rode `--simtest` depois de qualquer mudança em `battle_sim.gd`, `terrain_data.gd`, `ai_commander.gd` ou `config.gd`. Ele leva cerca de um minuto e termina com `FALHAS: 0` quando passa.

O build Web só reflete o código depois de um novo export.

## Estrutura

- `scripts/config.gd`: constantes do mapa, limites de declive, tabela dos tipos de unidade e limiares de moral. Todo balanceamento fica aqui.
- `scripts/terrain_data.gd`: altura, gradiente, declive por nó e as duas grades de navegação (a pé e carros).
- `scripts/battle_sim.gd`: núcleo da simulação. Não depende de nós da cena.
- `scripts/unit.gd`: estado de uma unidade (card).
- `scripts/ai_commander.gd`: IA de um lado.
- `scripts/battle.gd`: cena da batalha, desenho com MultiMesh e ordens do jogador.
- `scripts/ui/`: tela de preparo, HUD e cards.
- `scripts/sim_test.gd`: testes headless, chamados por `main.gd`.
- `tools/build_heightmap.gd`: converte os tiles de elevação em `assets/jerusalem_height.res`.

## Convenções

- Os scripts não usam `class_name` nem autoloads. Cada um carrega o que precisa com `const X = preload(...)`.
- Coordenadas do mundo: x para leste, z para sul. A simulação usa `Vector2(x, z)`.
- Controles criados por código usam `set_anchors_and_offsets_preset`; só `set_anchors_preset` deixa o tamanho em zero.
- Compare dicionários com `is_same`, porque `==` compara por valor.

## Como a simulação funciona

Os soldados não são nós. Ficam em arrays globais (`pos`, `cd`, `flag`, `col_of`, `row_of`), e cada unidade é dona do intervalo `[start, start + n)`.

Uma unidade sob controle está em um de dois modos:

- **Formada** (`u.formed`): longe de tudo, em terreno livre. As posições em `pos` ficam desatualizadas e não há custo por soldado. Chame `materialize(u)` antes de ler `pos`, ou `_unform(u)` antes de alterá-lo.
- **Na grade** (`u.in_grid`): perto de outra unidade, em terreno com declive proibido ou com soldados fora do posto. Só os soldados da lista `u.wake` são processados, e cada um consulta as células vizinhas.

A transição entre os modos acontece em `_broadphase`, a cada 3 ticks.

### Invariantes

- Toda mudança de `pos` de um soldado que está na grade passa por `_set_pos`, ou por `_unlink` e `_link`. Escrever em `pos` direto corrompe a grade.
- Não crie cópia local de `pos`, `cd`, `flag`, `head` ou `nxt` em laços que escrevem neles: a escrita dispara uma cópia do array inteiro.
- A formação é por fileiras com profundidade própria (`u.depth`). Na morte, os de trás da mesma fileira avançam; ninguém muda de fileira, exceto em `_rebalance`, pela retaguarda.
- O centro de uma unidade sob controle é sempre limitado à área controlável em `_clamp_ctrl`.

### Desempenho

O alvo é 20 × 20 unidades de 300 homens no navegador. O custo por tick vem dos soldados acordados, então evite qualquer coisa que acorde uma unidade inteira sem necessidade ou que percorra todos os soldados a cada tick. O `--simtest` imprime o tick médio e falha acima de 40 ms.

## Verificação no navegador

O painel de navegador do app cai para cerca de 1 FPS quando está oculto. Números de FPS e de tick lidos nessa situação não valem como medida.

## Novos recursos: documentação, changelog e versão

Todo recurso novo do jogo (unidade, mecânica, tela, controle, opção) só está pronto quando o mesmo commit também:

1. Descreve o recurso no `README.md`, na seção correspondente (Como jogar, Controles, Unidades, Status, Terreno etc.), e remove de "Limitações conhecidas" o que deixou de valer.
2. Registra a mudança no `CHANGELOG.md`, em uma nova seção `## [x.y.z] - AAAA-MM-DD` (Adicionado, Alterado, Corrigido), no formato Keep a Changelog.
3. Aumenta a versão (semver: recurso novo = minor, correção = patch, mudança incompatível = major) e a atualiza nos três lugares: `config/version` em `project.godot`, o título da seção do `CHANGELOG.md` e a menção da versão no início do `README.md`.
