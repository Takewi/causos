# SESSION STATE: CAUSOS

## 1. Implementado até Aqui (Estado Atual do Código)

### Terreno e Relevo Procedural
- [x] **`TerrainModule`**: Geração procedural contínua de alturas via `FastNoiseLite` (SimplexSmooth + Fractal FBM), garantindo continuidade nas fronteiras entre chunks.
- [x] **Cálculo Baricêntrico de Altura (`get_mesh_height`)**: Interpolação matemática exata da superfície poligonal triangulada (32x32 segmentos por chunk), eliminando discrepâncias entre malha física e visual.
- [x] **Três Níveis de Relevo Configuráveis**: Suave (amplitude 3.5m), Normal (5.0m) e Montanhoso (7.5m).

### Vegetação e Morfologia
- [x] **`TreeMeshFactory` com 15 Variações**:
  - 5 variações altas (10m a 14m) com bifurcações em V e copas em guarda-chuva.
  - 5 variações de estrato médio (1/2 da altura: ~5m a 7m).
  - 5 variações de estrato baixo (1/3 da altura: ~3m a 4.5m).
  - Troncos sólidos com rotação e inclinação orgânicas (sem artefatos de corte vertical).
  - Variação 13 com maior densidade de ramificação e folhagens adicionais.
  - Eliminação de modelos e texturas duplicados: remoção de `lowpoly_tree.tres` (idêntico a `tree_variation_1.tres`) e `canopy_leaves.png` (cópia binária idêntica de `branch_leaves.png`), padronizando o pipeline para carregar `branch_leaves.png` e as 15 variações limpas.
  - Refatoração do `TreeMeshFactory`: remoção de mais de 1.150 linhas de código de geração procedural offline (`SurfaceTool`), convertendo a classe em um repositório de cache leve de alta performance focado exclusivamente no carregamento dos modelos `.tres` estáticos.
- [x] **Vegetação Rasteira e Clutter 3D com 9 Arquétipos (Folhas Caídas, Galhos e Flores)**:
  - Implementação de 9 arquétipos no sub-bosque mantendo o mesmo orçamento de instâncias para 0 perda de FPS:
    1. Grama Nativa Comum (`lowpoly_foliage.tres` / `foliage_grass.png`)
    2. Capim Alto Silvestre com espigas (`foliage_grass_tall.tres` / `foliage_grass_tall.png`)
    3. Samambaias da Mata com 3 frondes (`foliage_fern.tres` / `foliage_fern.png`)
    4. Arbustos Folhosos Ramificados (`foliage_bush.tres` / `foliage_bush.png`)
    5. Tufos de Palha / Capim Seco (`foliage_dry.tres` / `foliage_dry.png`)
    6. **Folhas Caídas Secas** (`foliage_leaves_dry.tres` / `foliage_leaves_dry.png`): Decalque rasteiro com relevo convexo sutil (tons ocre/castanho/agulhas).
    7. **Folhas Caídas Verdes** (`foliage_leaves_green.tres` / `foliage_leaves_green.png`): Decalque rasteiro de folhas frescas recém-caídas do dossel.
    8. **Galhos Secos Caídos** (`foliage_twigs.tres` / `foliage_twigs.png`): Gravetos e lascas de casca de árvore cruzados sobre o solo.
    9. **Flores Silvestres Raras** (`foliage_flower.tres` / `foliage_flower.png`): Tufo vertical com pequenas flores douradas e violetas raras da mata.
  - Presença ampliada de clutter (~44% da cota total do sub-bosque): folhas caídas secas (~16%), folhas verdes caídas (~12%), galhos secos (~9%) e flores silvestres (~7% baseline / 12% em canteiros), com escalas ampliadas em 20-30% para leitura nítida na câmera em primeira pessoa.
  - Geração assíncrona categorizada (`type_transforms`) e montagem eficiente com `MultiMeshInstance3D` por subcélula com AABBs agregados.
  - Particionamento espacial em **16 subcélulas** (4x4 de 25x25m) por chunk, agrupamento orgânico em reboleiras temáticas e culling de distância GPU (`visibility_range_end = 60m`).
- [x] **Melhorias e Variações de Texturas com Blender MCP (Estética Retrô Anos 90)**:
  - **4 Variações de Nuvens 2D de Folhas sem Galhos (256x256 Pixel Art)**: Dossel verde-oliva clássico (`branch_leaves.png`), folhas largas subtropicais de Mata Atlântica (`branch_leaves_lush.png`), leques de acículas de Pinheiro/Araucária gaúcha (`branch_leaves_needle.png`) e folhagem decídua outonal ressecada (`branch_leaves_dry.png`). Texturas sem galhos/gravetos desenhados, estruturadas como nuvens de folhagem pura para assentamento direto sobre os galhos tridimensionais dos 15 modelos de árvores.
  - **Textura do Solo Uniforme e Verdejante (`ground.png` - 128x128 Seamless)**: Eliminação do padrão xadrez (checkerboard) através de síntese isotrópica periódica 2D FFT e paleta contínua de baixa variância luminosa (std dev ~7.8). Tapete florestal verdejante musgoso e uniforme, sem repetição ortogonal visível em grid, com micro-agulhas de pinheiro, rosetas de trevinho e micro-grão retrô suave perfeitamente encaixado em repetição 4-way.
  - **Otimização de Performance Gráfica (Foliage & Canopy)**:
    - Sombreamento por vértice puro (`shading_mode = SHADING_MODE_PER_VERTEX`) em todos os 15 modelos de árvores e 9 de folhagem/clutter, reduzindo drasticamente o custo de fillrate e sombreamento na GPU.
    - Eliminação do passe duplo de profundidade (`depth_draw_mode = DEPTH_DRAW_OPAQUE_ONLY`) nas folhas com *alpha scissor*, cortando pela metade o custo de rasterização.
    - Filtragem *Nearest com Mipmaps* (`TEXTURE_FILTER_NEAREST_WITH_MIPMAPS`), preservando a estética pixel art em close e eliminando 100% dos *cache misses* de textura na GPU ao visualizar árvores distantes.
  - **Modularização de `ForestChunk.gd` (-77% de linhas)**:
    - Divisão em componentes especializados:
      - `ForestChunk.gd`: Orquestrador enxuto (~88 linhas) responsável pelo ciclo de vida e malha do terreno.
      - `ChunkFoliageBuilder.gd`: Responsável pela geração de dados dos 9 arquétipos botânicos e montagem das instâncias `MultiMeshInstance3D`.
      - `ChunkTreeBuilder.gd`: Responsável pela amostragem de Poisson em 2D, posicionamento por quadrantes, colisores e instâncias `MultiMeshInstance3D` das árvores.

### Iluminação & Atmosfera
- [x] **Ambiente Retrô Ensolarado com Penumbra**:
  - `WorldEnvironment` com luz ambiente verde-oliva densa e névoa volumétrica verde-escura (`fog_depth_begin = 8m`, `fog_depth_end = 45m`).
  - `DirectionalLight3D` com luz solar dourada penetrante e sombras focadas até 45m (`directional_shadow_max_distance = 45.0`).

### Mundo e Streaming de Chunks
- [x] **`ForestManager` com Streaming Assíncrono (`WorkerThreadPool`)**:
  - Grid de 1600x1600m com streaming de 3x3 chunks ativos (9 chunks carregados ao redor do jogador).
  - Geração pesada de dados (cálculo de malhas de terreno, amostragem Poisson de árvores, cálculo de matrizes de folhagem e colisores) transferida integralmente para threads secundárias via `WorkerThreadPool`, com pure data desacoplada de `SceneTree` ou `RenderingServer`.
  - Cache de grade de alturas no `TerrainModule` (`generate_chunk_height_grid` e `get_grid_mesh_height`): substitui mais de 10.000 consultas contínuas de ruído por interpolação bilinear local instantânea, acelerando a geração de folhagem e árvores.
  - Montagem instantânea na thread principal: tempo de quadro por chunk reduzido de **~41.5 ms para ~2.8 ms** (queda de 93% no uso da main thread).
  - Descarte fracionado (*time-sliced unloading*): liberação de chunks distantes limitada a 1 chunk por frame e alternada com montagem de novos chunks, eliminando os picos anteriores de 14 ms de destruição síncrona.
  - Tempo médio de CPU por frame do `ForestManager` durante travessia contínua a alta velocidade reduzido para **0.68 ms**, garantindo framerate 100% liso e sem engasgos.
  - Chunk central `(0, 0)` carregado de forma síncrona na inicialização para suporte imediato ao spawn do jogador.

### Jogador e Nascimento
- [x] **Spawn Preciso no Solo**:
  - Altura do jogador calculada dinamicamente na inicialização via `terrain_module.get_mesh_height() + 0.05m`.
  - Queda livre do céu eliminada permanentemente.
  - Raio de segurança de 2.5m ao redor do spawn livre de troncos de árvores.
  - Rede de segurança contra queda no vazio (`Y < -30m`).

### Configurações, Localização e Interface
- [x] **Sistema de Tradução Multilíngue (i18n)**:
  - Catálogo em `localization/translations.csv` com compilação para `pt_BR`, `en` e `es`.
  - Seletor de idioma interativo em tempo real tanto no `MainMenu` quanto no `PauseMenu`.
- [x] **Semente Procedural Dinâmica**:
  - Semente gerada aleatoriamente a cada inicialização pelo `GameManager` (substituindo o antigo valor fixo 1337).
- [x] **Painel de Configurações e Seletor de Resolução de Tela**:
  - Seletor de resoluções 16:9 (`1280x720`, `1366x768`, `1600x900`, `1920x1080`, `2560x1440`, `3840x2160`) integrado ao `GameManager`, redimensionando e centralizando a janela automaticamente no monitor atual.
  - Desativação dinâmica do seletor de resolução quando a opção Tela Cheia (*Fullscreen*) está ativa.
  - Limite de FPS (30, 60, 120, 144, Ilimitado), Tela Cheia (F11/Alt+Enter), V-Sync e contador de FPS no HUD.
- [x] **Suporte Completo a Controles de Videogame (Gamepad)**:
  - InputMap configurado em `project.godot` com suporte nativo a controle para movimentação (`move_*` com analógico esquerdo e D-pad), corrida (`sprint` com L3 / clique analógico e RB / R1), olhar/câmera (`look_*` com analógico direito) e pausa (`pause` com botão Start / Menu).
  - Controle de câmera no `Player.gd` com rotação analógica contínua, clamp vertical (-85° a 85°) e sensibilidade ajustável (`gamepad_sensitivity = 2.5`).
  - Acessibilidade e navegação completa por controle nos menus (`MainMenu` e `PauseMenu`), com foco programático automático (`grab_focus`) nos botões principais e suporte ao botão B / cancel para retornar telas.
- [x] **Skill de Internacionalização (`causos-translations`)**:
  - Skill encapsulada em `.agent/skills/causos-translations/SKILL.md` documentando a arquitetura de i18n, fluxo de compilação via CLI, consulta com `tr()` e reação a eventos de troca de idioma.
- [x] **Fonte Pixel Retrô da Interface (`m5x7.ttf`), Resolução Nativa e Remoção de Emojis**:
  - Resolução base de viewport atualizada para 1920x1080 com `textures/canvas_textures/default_texture_filter=0` (Nearest), eliminando interpolação bilinear e desfoque da UI em 1080p ou tela cheia.
  - Configuração do `.import` da fonte `m5x7.ttf` ajustada para `hinting=0` e `subpixel_positioning=0`, garantindo alinhamento estrito aos pixels físicos.
  - Escalas de fonte generosas e layout expandido sem economia de tela (Título 80px, Títulos de Painel 36px, Botões Principais 32px, Seletores OptionButton e Popups 28px, Rótulos e CheckBoxes 26px, painéis expandidos para 760px de largura).
  - Popups de seletores estilizados com fonte 28px e separação vertical de 12px, garantindo legibilidade e espaço amplo nas opções.
  - Inputs do tipo checkmark (`CheckBox`) sem bordas invasivas em repouso (`normal`, `hover`, `pressed`), mas com contorno de foco dourado de 2px (`#d8b86c`) em `CheckBox/styles/focus` (`StyleBoxFlat_checkbox_focus`) para navegação cristalina via controle/gamepad e teclado.
  - Remoção da borda branca externa padrão do Godot ao clicar em botões: criação do tema global `assets/ui_theme.tres` e styleboxes customizados de `focus` e `pressed` com borda dourada idêntica ao `hover` (`corner_radius = 6`, `expand_margin = 0`).
  - Suporte contínuo a seleção de resolução no modo tela cheia (`win.content_scale_size`), permitindo alternar resoluções de renderização sem bloqueio do dropdown.
  - Rastreamento de foco dinâmico via mouse (`mouse_entered`), garantindo transições suaves entre foco por controle/teclado e interação por ponteiro.
  - Ausência total de emojis em qualquer elemento visual ou textual.
- [x] **Menu de Configurações Modular em 3 Abas (`scenes/SettingsMenu.tscn`, `scripts/ui/SettingsMenu.gd`)**:
  - Unificação completa das preferências do usuário em um único componente reutilizável (`SettingsMenu.tscn`), eliminando código duplicado em `MainMenu` e `PauseMenu`.
  - Estruturação em 3 abas principais:
    - **Geral**: Seletor de idioma multilíngue (`pt_BR`, `en`, `es`).
    - **Gráficos**: Resolução de tela, limite de FPS (30, 60, 120, 144, ilimitado), modo tela cheia, V-Sync e contador de FPS na tela.
    - **Controles**: Sub-abas com alternância fluida entre "Teclado & Mouse" e "Controle (Layout Xbox)".
  - Suporte nativo a navegação por botões de ombro/bumpers do gamepad (`LB` / `RB`) e teclas de atalho (`PageUp` / `PageDown`).
- [x] **Customização de Controles, Sensibilidades e Modo Alternar Corrida**:
  - Sliders de sensibilidade para mouse (`0.5x` a `3.0x` sobre base 0.003) e analógico de câmera do controle (`0.5x` a `3.0x` sobre base 2.5) com rótulo numérico em tempo real.
  - Modo Alternar Corrida (*Toggle Sprint*): checkbox compartilhada entre teclado e controle que permite alternar entre modo clássico de segurar tecla/botão e clique único (com auto-cancelamento ao interromper movimento).
  - Remapeamento interativo de teclas de movimentação (`move_forward`, `move_back`, `move_left`, `move_right`, `sprint`) com escuta de teclas (*listening mode*) e botão para restaurar comandos padrão.
  - Legenda informativa detalhada dos comandos do controle Xbox (`LS`, `RS`, `L3 / RB`, `A`, `B`, `Menu / Start`, `D-Pad`).
  - Tipografia ampliada para 26px e dimensões confortáveis em todos os botões e rótulos dos submenus de controles.
- [x] **Persistência Multiplataforma Confiável com `user://settings.cfg`**:
  - Salvamento e carregamento via `ConfigFile` persistindo idioma, resolução, fullscreen, vsync, fps_limit, contador de fps, sensibilidades, toggle sprint e custom_keybinds.
  - Ciclo de inicialização seguro em `GameManager.gd`: configurações salvas são sempre priorizadas e auto-detecção de resolução ocorre apenas no primeiro boot, evitando que a janela inicial sobrescreva as preferências do jogador.
  - Chamadas de salvamento imediato a cada alteração em qualquer opção das abas.
- [x] **Skill de Controles e Entradas (`causos-controls`)**:
  - Criada a skill `.agent/skills/causos-controls/SKILL.md` documentando a arquitetura de inputs e passo a passo para registrar novas interações do jogador (`interact`, `flashlight`, etc.).
- [x] **Suíte de Testes Automatizada (`tests/test_settings_and_controls.gd`)**:
  - Teste automatizado cobrindo integridade de defaults, setters, persistência, remapeamento de teclas, restauração, estilo de foco de checkboxes e consistência de traduções em `pt_BR`, `en` e `es`.
- [x] **Compatibilidade com Godot 4.7 (`project.godot` e Metadados)**:
  - Atualização da flag de engine em `config/features` para `4.7` e inclusão de `compatibility/default_parent_skeleton_in_mesh_instance_3d=true`.
  - Metadados de compressão VRAM etc2/astc sincronizados nos arquivos `.import` de texturas (`branch_leaves` e `foliage`), eliminando alterações residuais automáticas do editor.
- [x] **Modularização e Organização dos Scripts por Escopo**:
  - Reorganização da pasta `scripts/` em subpastas por domínio: `core/` (`GameManager`), `player/` (`Player`), `ui/` (`MainMenu`, `PauseMenu`, `HUD`) e `world/` (`ForestChunk`, `ForestConfig`, `ForestManager`, `TerrainModule`, `TreeMeshFactory`).
  - Atualizados os caminhos em `project.godot`, cenas (`.tscn`), recursos (`.tres`) e documentação de skills.

### CI/CD & Automação de Releases
- [x] **Automação Contínua de Releases Multiplataforma (`build-release.yml`)**:
  - Qualquer alteração que entrar na branch `main` (push direto ou merge de PR/branch `dev`) dispara compilação para Windows, Linux e macOS e publicação automática da Release.
  - Cálculo semântico de tag no próprio workflow: busca a última tag `vX.Y.Z`, detecta alterações (`feat` incrementa versão minor, caso contrário incrementa patch), garantindo unicidade de tag e publicação sem pular etapas.
  - Geração automática de notas de lançamento (`generate_release_notes: true`) com pacotes `.zip` e `.tar.gz` empacotados e assinados pelo commit sha de destino.
  - Preservação do bit de execução (+x) do bundle macOS na release (PR #1), evitando descompactação intermediária pelo artifact uploader e adicionando validação com `unzip -Z`.
- [x] **Release `v0.8.0` Publicada e Branches Sincronizadas (`main` & `dev`)**:
  - Merge concluído da branch `feat/vegetation-textures-variations` nas branches `dev` e `main` (commit `9ddd37a`).
  - Sincronização remota via `git push origin main` e `git push origin dev`.
  - Workflow acionado automaticamente no GitHub Actions, gerando a tag semântica `v0.8.0` e os artefatos para Windows, Linux e macOS.
  - Bateria de testes de regressão automatizada (`test_settings_and_controls.gd`) executada e 100% aprovada.

---

## 2. Débitos Técnicos e Gargalos em Aberto

1. **Emendas / Amostragem de Poisson nas Bordas entre Chunks**:
   - Atualmente, a amostragem de Poisson de cada chunk roda isoladamente com margem zero. Em alguns pontos de divisa, árvores vizinhas de chunks adjacentes podem ficar mais próximas do que o `min_tree_distance`.
2. **Otimização de Colisores de Troncos**:
   - Todos os troncos de árvores do chunk têm `CylinderShape3D` gerados no corpo estático composto. Pode ser otimizado para manter colisores ativos apenas nas árvores em um raio próximo ao jogador.
3. **Áudio Diegético e Atmosférico**:
   - O projeto ainda não possui sistema de áudio (passos na mata, vento no dossel, estalos noturnos).
4. **Ciclo Dia/Noite e Lanternas**:
   - A atmosfera atual é fixa no entardecer; transições dinâmicas de iluminação e fontes de luz locais do jogador (lanterna/fogueira) ainda não foram estruturadas.

---

## 3. Próximos Passos (Prioridade de Desenvolvimento)

- [ ] **Prioridade 1**: Sistema de Áudio Ambiente e Passos do Jogador (SFX de passos com modulação de velocidade ao correr/andar e som contínuo de vento na mata).
- [ ] **Prioridade 2**: Lanterna do Jogador (`SpotLight3D`) com toggle e consumo de bateria/pilhas ou efeito retrô.
- [ ] **Prioridade 3**: Tratamento contínuo de Poisson nas fronteiras dos chunks para evitar árvores sobrepostas nas costuras.
- [ ] **Prioridade 4**: Otimização de colisões de árvores por proximidade do jogador para aliviar a engine de física em hardwares modestos.
- [ ] **Prioridade 5**: Elementos de gameplay e pontos de interesse (cabana abandonada, trilhas de terra batida, marcos de orientação na mata).
