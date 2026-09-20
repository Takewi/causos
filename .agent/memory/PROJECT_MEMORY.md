# PROJECT MEMORY: CAUSOS

## 1. Visão Geral & Direção Artística (Estética Retrô Anos 90)
- **Proposta**: Jogo de terror e exploração na mata brasileira, com forte atmosfera psicológica e imersiva.
- **Fidelidade Visual Retrô**:
  - **Shading**: Obrigatório **Flat Shading** (`shading_mode = SHADING_MODE_PER_VERTEX` ou normais calculadas por face no `SurfaceTool`). Proibido iluminação suave/PBR moderna genérica.
  - **Texturas & Filtragem**: Filtro **Nearest** para preservar os pixels e a estética retrô. Na UI e elementos 2D, usa-se `TEXTURE_FILTER_NEAREST` puro (0). Em modelos 3D com texturas repetidas e visualizadas à distância (copas de árvores, folhas caídas, gramas e clutter), é obrigatório o uso de `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` (1) para eliminar gargalos severos de GPU e cache misses sem introduzir blur bilinear.
  - **Transparência e Profundidade**: Sempre **Alpha Scissor** com threshold estrito de `0.5` (`transparency = TRANSPARENCY_ALPHA_SCISSOR`, `alpha_scissor_threshold = 0.5`) e `depth_draw_mode = DEPTH_DRAW_OPAQUE_ONLY` (0) em folhagens e árvores para evitar o passe duplo de profundidade que dobra o custo de rasterização. Proibido Alpha Blend suave em folhagens ou copas para manter a assinatura gráfica da era PS1/PC dos anos 90 e evitar problemas de ordenação.
  - **Paleta de Cores**: Tons terrosos, folhagens verde-oliva e florestais, névoa atmosférica verde-escura e iluminação quente de entardecer contrastando com sombras densas.

---

## 2. Regras Técnicas e Arquitetura Godot 4
- **Princípio da Responsabilidade Única (SRP) & Organização por Escopos**:
  - Scripts organizados em subpastas por domínio:
    * `scripts/core/`: Controle global, configurações e singletons (`GameManager`).
    * `scripts/player/`: Mecânicas de movimentação e câmera do jogador (`Player`).
    * `scripts/ui/`: Telas e elementos de interface (`MainMenu`, `PauseMenu`, `HUD`).
    * `scripts/world/`: Geração procedural de relevo (`TerrainModule`), morfologia e cache de malhas (`TreeMeshFactory`), streaming de chunks (`ForestManager`), nós locais de chunk (`ForestChunk`), construtor de árvores e Poisson (`ChunkTreeBuilder`), construtor de folhagens e clutter (`ChunkFoliageBuilder`) e parâmetros de mundo (`ForestConfig`).
  - Proibidos scripts monolíticos ou acoplamento direto entre sistemas sem mediação por nós ou singletons declarados.
- **Renderização e Densidade com MultiMeshInstance3D**:
  - Toda vegetação densa (árvores, arbustos, tufos de grama) deve ser instanciada obrigatoriamente via `MultiMeshInstance3D`.
  - Proibido criar nós individuais `MeshInstance3D` ou `Node3D` por árvore/planta para evitar sobrecarga de draw calls e overhead de cena.
- **Iluminação e Otimização de Sombras**:
  - Luz Direcional configurada com sombra ortogonal / PSSM focada em até **~45m a 50m** (`directional_shadow_max_distance = 45.0` a `50.0`).
  - A distância máxima de sombra alinha-se ao limite da névoa de profundidade opaca (fog wall a 45m), eliminando desperdício de processamento de GPU além do alcance visual do jogador.

---

## 3. Métricas e Dimensões do Mundo
- **Área Total do Cenário**: ~2.56 km² (1600m x 1600m).
- **Divisão em Chunks**:
  - Chunks modulares de **100m x 100m** (total de 16x16 chunks no grid global).
  - Malha de terreno de cada chunk com resolução de 32x32 segmentos (passo de 3.125m), calculada perfeitamente contínua nas bordas via `FastNoiseLite`.
- **Streaming Ativo**:
  - Grade ativa de **3x3 chunks** (9 chunks simultâneos) centrada dinamicamente no chunk do jogador (`active_radius = 1`).
  - Descarregamento automático de chunks distantes e enfileiramento de carga distribuído (1 chunk por frame no loop principal) para evitar micro-stutters ou quedas repentinas de framerate.

---

## 4. Catálogo Morfológico da Vegetação
- **Árvores Altas (Dossel Principal - 10m a 14m)**:
  - Troncos maciços com bifurcações orgânicas em "V" ou "Y".
  - Copas densas em formato de guarda-chuva/umbela, cobrindo o topo para criar sombras dramáticas e clareiras naturais.
  - Variações vivas ricas em folhagens e variantes mortas/secas (árvores queimadas ou descascadas, ramos retorcidos sem folhas).
- **Sub-Bosque e Estratos Médio e Baixo (1/2 e 1/3 de altura)**:
  - Árvores de porte médio (~5m a 7m) e árvores jovens/baixas (~3m a 4.5m) que quebram a uniformidade e preenchem a linha de visão horizontal.
  - Distribuição com colisão física proporcional e escalada por estrato.
- **Catálogo de Texturas de Copas / Folhas (256x256 Pixel Art - Nuvens 2D sem Galhos)**:
  - Formato de nuvem folhosa pura (sem galhos desenhados na textura, assentando-se perfeitamente sobre os galhos tridimensionais das árvores).
  - `branch_leaves.png`: Nuvem clássica verde-oliva com folíolos densos e sombreamento em 3 níveis.
  - `branch_leaves_lush.png`: Nuvem de folhas largas subtropicais (Mata Atlântica) em verde-esmeralda e toques lima.
  - `branch_leaves_needle.png`: Nuvem de acículas de Araucária / Pinheiro Gaúcho em verde-azulado.
  - `branch_leaves_dry.png`: Nuvem de folhagem outonal / decídua seca em tons ocre, âmbar e ferrugem.
  - Distribuídas estrategicamente entre as 15 variações de árvores (`tree_variation_*.tres`).
- **Folhagem Rasteira e Clutter 3D (9 Arquétipos em MultiMeshInstance3D)**:
  - `lowpoly_foliage.tres` / `foliage_grass.png`: Tufo denso de grama nativa (64x64).
  - `foliage_grass_tall.tres` / `foliage_grass_tall.png`: Capim alto com espigas esguias (64x64).
  - `foliage_fern.tres` / `foliage_fern.png`: Samambaia nativa com 3 frondes arqueadas em leque (128x128).
  - `foliage_bush.tres` / `foliage_bush.png`: Arbusto lenhoso com ramificações e folhas volumétricas (128x128).
  - `foliage_dry.tres` / `foliage_dry.png`: Moita de palha seca / capim ressecado (64x64).
  - `foliage_leaves_dry.tres` / `foliage_leaves_dry.png`: Folhas caídas secas em tons ocre e castanho com agulhas (64x64).
  - `foliage_leaves_green.tres` / `foliage_leaves_green.png`: Folhas frescas caídas em tons verde-oliva e esmeralda (64x64).
  - `foliage_twigs.tres` / `foliage_twigs.png`: Gravetos secos e lascas de galho caídos sobre o solo (64x64).
  - `foliage_flower.tres` / `foliage_flower.png`: Flores silvestres raras da mata em tons dourado e violeta (64x64).
  - Distribuição estocástica balanceada (reaproveitando a cota existente de instâncias, com 0 perda de FPS) e reboleiras temáticas em 16 subcélulas por chunk.
  - Otimizações de renderização: `shading_mode = PER_VERTEX`, remoção do depth prepass (`DEPTH_DRAW_OPAQUE_ONLY`) e `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` para máxima taxa de quadros e zero cache-miss em árvores e folhagens.
  - Arquitetura desacoplada: `ForestChunk.gd` (~88 linhas) coordena a malha do terreno e delega folhagens para `ChunkFoliageBuilder.gd` e árvores/Poisson para `ChunkTreeBuilder.gd`.
- **Textura do Solo Uniforme e Verdejante (`ground.png` - 128x128 Seamless)**:
  - Solo humoso florestal rico com tapete verdejante de musgo e micro-vegetação, gerado por síntese isotrópica periódica 2D FFT para eliminar 100% de qualquer padrão xadrez/grid ortogonal e dithering Bayer 2x2. Baixa variância de luminância para continuidade visual perfeita e homogênea na paisagem 3D, com micro-agulhas de pinheiro e rosetas sutis.

---

## 5. Interface, Controles e Persistência Multiplataforma
- **Componente Unificado de Configurações (`SettingsMenu`)**:
  - Toda a lógica e interface de preferências do usuário está centralizada no componente reutilizável `scenes/SettingsMenu.tscn` (`scripts/ui/SettingsMenu.gd`).
  - Instanciado no `MainMenu` e no `PauseMenu`, garantindo comportamento idêntico e eliminando duplicação de nós ou scripts.
  - Dividido em 3 abas principais:
    - **Geral**: Configuração de idioma (`pt_BR`, `en`, `es`).
    - **Gráficos**: Resolução de tela (com reescalonamento via `content_scale_size`), limite de FPS, modo tela cheia, V-Sync e contador de FPS.
    - **Controles**: Sub-abas dedicadas para "Teclado & Mouse" (sensibilidade, alternar corrida, remapeamento interativo de teclas com reset de padrões) e "Controle (Layout Xbox)" (sensibilidade de câmera analógica, alternar corrida e legenda visual não-customizável dos botões).
  - Suporte total a navegação por controle estilo Xbox, incluindo bumpers (`LB`/`RB`) para alternar abas e teclas `PageUp`/`PageDown`.
- **Feedback de Foco e Tipografia em Menus**:
  - Checkboxes sem bordas invasivas em repouso, mas com contorno dourado nítido `#d8b86c` ao receber foco (`StyleBoxFlat_checkbox_focus`) para navegação perfeita por controle e teclado.
  - Padrão tipográfico de 26px a 28px nos controles e botões, garantindo leitura confortável em qualquer distância (sofá/TV ou monitor).
- **Persistência de Dados com `user://` e `ConfigFile`**:
  - Preferências gravadas em `user://settings.cfg`, padrão cross-platform nativo do Godot:
    - Windows: `%APPDATA%\Godot\app_userdata\causos\settings.cfg`
    - Linux: `~/.local/share/godot/app_userdata/causos/settings.cfg`
    - macOS: `~/Library/Application Support/Godot/app_userdata/causos/settings.cfg`
  - Ciclo de inicialização seguro no `GameManager.gd`: configurações salvas são sempre respeitadas na inicialização, com auto-detecção de resolução reservada exclusivamente para o primeiro boot da aplicação.
  - Gravação atômica e imediata a cada alteração de propriedade gráfica ou de controle.
- **Extensibilidade e Skill de Controles (`causos-controls`)**:
  - Novas ações do jogador (`interact`, `flashlight`, etc.) devem ser adicionadas seguindo rigorosamente a skill `.agent/skills/causos-controls/SKILL.md` (registro no `InputMap`, traduções em `translations.csv` e inclusão nas constantes de `SettingsMenu.gd`).

---

## 6. Histórico de Versões e Automação de CI/CD (GitHub Releases)
- **Workflow Automatizado Multiplataforma (`.github/workflows/build-release.yml`)**:
  - Acionado a cada push na branch `main`.
  - Exporta binários headless com Godot CI para Windows (`.exe`, `.zip`), Linux (`.x86_64`, `.tar.gz`, `.zip`) e macOS (`.app` universal com bit `+x` preservado no `.zip`).
  - Determinação semântica automática de tags com base nos commits (`feat` -> incrementa minor, fix/outros -> incrementa patch).
- **Versões Publicadas**:
  - `v0.8.0`: Nova textura de solo uniforme via FFT 2D sem padrão xadrez, clutter 3D rasteiro com 9 arquétipos (folhas secas/verdes, galhos, flores silvestres), otimizações de shaders para GPU integrada (`PER_VERTEX`, `DEPTH_DRAW_OPAQUE_ONLY`, `NEAREST_WITH_MIPMAPS`) e refatoração modular de `ForestChunk` com `ChunkTreeBuilder` e `ChunkFoliageBuilder`.
  - `v0.7.0`: Correção da persistência de resolução e modo de exibição no primeiro boot da aplicação.
  - `v0.6.0`: Menu de configurações modular em 3 abas, suporte completo a controle Xbox, navegação por bumpers (`LB`/`RB`), remapeamento de teclado, modo alternar corrida (*toggle sprint*) e sensibilidade analógica.
  - `v0.5.1` / `v0.5.0`: Correção do bit de execução (+x) para macOS e empacotamento das releases.
  - `v0.4.1` / `v0.4.0` / `v0.3.0` / `v0.2.0` / `v0.1.0`: Streaming assíncrono com `WorkerThreadPool`, 15 variações de árvores, geração procedural contínua e protótipo inicial.
