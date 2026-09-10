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
- [x] **Vegetação Rasteira / Folhagem Otimizada**:
  - Particionamento espacial em **16 subcélulas** (4x4 de 25x25m) por chunk com AABBs individuais.
  - Culling de distância GPU (`visibility_range_end = 60m`, além da névoa de 45m), eliminando qualquer popping visual ou clareiras estéreis.
  - Amostragem Poisson e assentamento a `+0.02m` do solo poligonal.

### Iluminação & Atmosfera
- [x] **Ambiente Retrô Ensolarado com Penumbra**:
  - `WorldEnvironment` com luz ambiente verde-oliva densa e névoa volumétrica verde-escura (`fog_depth_begin = 8m`, `fog_depth_end = 45m`).
  - `DirectionalLight3D` com luz solar dourada penetrante e sombras focadas até 45m (`directional_shadow_max_distance = 45.0`).

### Mundo e Streaming de Chunks
- [x] **`ForestManager`**:
  - Grid de 1600x1600m com streaming de 3x3 chunks ativos (9 chunks carregados ao redor do jogador).
  - Processamento distribuído de 1 chunk por frame para manter o framerate estável.
  - Chunk central `(0, 0)` carregado de forma síncrona na inicialização.

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
- [x] **Painel de Configurações**:
  - Limite de FPS (30, 60, 120, 144, Ilimitado), Tela Cheia (F11/Alt+Enter), V-Sync e contador de FPS no HUD.
- [x] **Skill de Internacionalização (`causos-translations`)**:
  - Skill encapsulada em `.agent/skills/causos-translations/SKILL.md` documentando a arquitetura de i18n, fluxo de compilação via CLI, consulta com `tr()` e reação a eventos de troca de idioma.
- [x] **Fonte Pixel Retrô da Interface (`m5x7.ttf`)**:
  - Fonte organizada em `assets/fonts/m5x7.ttf` com antialiasing desativado (`antialiasing=0`) para máxima nitidez pixel-art.
  - Aplicada globalmente no projeto via `gui/theme/custom_font="res://assets/fonts/m5x7.ttf"` no `project.godot`, herdada automaticamente por todos os nós de UI (`MainMenu`, `PauseMenu`, `HUD`).

### CI/CD & Automação de Releases
- [x] **Automação Contínua de Releases Multiplataforma (`build-release.yml`)**:
  - Qualquer alteração que entrar na branch `main` (push direto ou merge de PR/branch `dev`) dispara compilação para Windows, Linux e macOS e publicação automática da Release.
  - Cálculo semântico de tag no próprio workflow: busca a última tag `vX.Y.Z`, detecta alterações (`feat` incrementa versão minor, caso contrário incrementa patch), garantindo unicidade de tag e publicação sem pular etapas.
  - Geração automática de notas de lançamento (`generate_release_notes: true`) com pacotes `.zip` e `.tar.gz` empacotados e assinados pelo commit sha de destino.

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
