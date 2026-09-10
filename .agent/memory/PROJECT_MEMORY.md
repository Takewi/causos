# PROJECT MEMORY: CAUSOS

## 1. Visão Geral & Direção Artística (Estética Retrô Anos 90)
- **Proposta**: Jogo de terror e exploração na mata brasileira, com forte atmosfera psicológica e imersiva.
- **Fidelidade Visual Retrô**:
  - **Shading**: Obrigatório **Flat Shading** (`shading_mode = SHADING_MODE_PER_VERTEX` ou normais calculadas por face no `SurfaceTool`). Proibido iluminação suave/PBR moderna genérica.
  - **Texturas & Filtragem**: Sempre filtro **Nearest** (`texture_filter = TEXTURE_FILTER_NEAREST`), sem mipmaps borrados ou interpolação trilinear.
  - **Transparência**: Sempre **Alpha Scissor** com threshold estrito de `0.5` (`transparency = TRANSPARENCY_ALPHA_SCISSOR`, `alpha_scissor_threshold = 0.5`). Proibido Alpha Blend suave em folhagens ou copas para evitar problemas de ordenação e manter a assinatura gráfica da era PS1/PC dos anos 90.
  - **Paleta de Cores**: Tons terrosos, folhagens verde-oliva e florestais, névoa atmosférica verde-escura e iluminação quente de entardecer contrastando com sombras densas.

---

## 2. Regras Técnicas e Arquitetura Godot 4
- **Princípio da Responsabilidade Única (SRP) & Organização por Escopos**:
  - Scripts organizados em subpastas por domínio:
    * `scripts/core/`: Controle global, configurações e singletons (`GameManager`).
    * `scripts/player/`: Mecânicas de movimentação e câmera do jogador (`Player`).
    * `scripts/ui/`: Telas e elementos de interface (`MainMenu`, `PauseMenu`, `HUD`).
    * `scripts/world/`: Geração procedural de relevo (`TerrainModule`), morfologia e cache de malhas (`TreeMeshFactory`), streaming de chunks (`ForestManager`), nós locais de chunk (`ForestChunk`) e parâmetros de mundo (`ForestConfig`).
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
- **Folhagem Volumétrica**:
  - Cards 2D e planos angulados cruzados, sem normais invertidas ou troncos cortados.
  - Tufos de vegetação rasteira distribuídos em 16 subcélulas espaciais por chunk com alturas baricêntricas precisas nos triângulos do terreno.
