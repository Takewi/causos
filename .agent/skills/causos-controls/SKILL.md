---
name: causos-controls
description: >-
  Explains the input and controls architecture in the Causos project, including
  keyboard rebinding, mouse and gamepad sensitivity, sprint toggle mode, Xbox
  gamepad mapping legends, and step-by-step instructions for adding new user
  interactions to the settings screen.
---

# Sistema de Controles e Mapeamento de Entradas (Causos)

Este documento descreve a arquitetura de controles, customização de teclado, exibição do layout de controle estilo Xbox, sensibilidades de câmera e o fluxo para adicionar novas ações e interações do jogador ao menu de configurações.

---

## 1. Arquitetura de Entrada

O sistema de entradas do projeto é composto por quatro componentes principais:

1. [`project.godot`](file:///home/takewi/godot/causos/project.godot): Define os nomes das ações (`InputMap`) e suas teclas e botões padrão.
2. [`scripts/core/GameManager.gd`](file:///home/takewi/godot/causos/scripts/core/GameManager.gd): Armazena as preferências do usuário (sensibilidade do mouse, sensibilidade do controle, modo de alternar corrida e remapeamentos customizados de teclado).
3. [`scripts/player/Player.gd`](file:///home/takewi/godot/causos/scripts/player/Player.gd): Lê os inputs via `Input.get_vector()`, `Input.is_action_pressed()` ou `_unhandled_input()`, aplicando as sensibilidades e regras de movimentação.
4. **Painel de Controles no Menu de Configurações**: Interface gráfica dividida em abas que permite ao jogador:
   - Ajustar sensibilidade do mouse e do analógico de câmera do controle.
   - Alternar o modo de corrida entre "Segurar" e "Clique Único (Toggle)".
   - Remapear teclas de movimentação e ações do teclado.
   - Visualizar a legenda completa dos botões do controle estilo Xbox.

---

## 2. Padrão de Nomenclatura das Ações

As ações registradas no `InputMap` seguem o formato snake_case:

| Ação | Tecla Padrão | Botão Xbox Padrão | Função |
|---|---|---|---|
| `move_forward` | `W` / `Seta Cima` | Analógico Esquerdo Cima (`LS Up`) / D-Pad Cima | Mover para frente |
| `move_back` | `S` / `Seta Baixo` | Analógico Esquerdo Baixo (`LS Down`) / D-Pad Baixo | Mover para trás |
| `move_left` | `A` / `Seta Esquerda` | Analógico Esquerdo Esquerda (`LS Left`) / D-Pad Esquerda | Mover para esquerda |
| `move_right` | `D` / `Seta Direita` | Analógico Esquerdo Direita (`LS Right`) / D-Pad Direita | Mover para direita |
| `sprint` | `Shift` | Clique Analógico Esquerdo (`L3` / `LS Click`) ou `RB` | Correr |
| `look_*` | Movimento do Mouse | Analógico Direito (`RS`) | Girar câmera |
| `pause` | `Escape` | Botão `Menu` / `Start` | Pausar o jogo |
| `interact` *(futuras)* | `E` | Botão `A` | Interagir / Usar |
| `flashlight` *(futuras)*| `F` | Botão `Y` ou D-Pad Direita | Ligar/Desligar Lanterna |

---

## 3. Como Funciona o Remapeamento de Teclado

O remapeamento é gerenciado em tempo de execução via `InputMap`:

1. Ao clicar no botão de uma ação (ex: "Mover para Frente: [W]"), o botão entra em modo de escuta (*listening mode*), exibindo `"Pressione uma tecla..."`.
2. O próximo evento `InputEventKey` válido é capturado:
   ```gdscript
   # Remove eventos de teclado anteriores da ação
   for event in InputMap.action_get_events(action_name):
       if event is InputEventKey:
           InputMap.action_erase_event(action_name, event)
   
   # Adiciona a nova tecla
   var new_event = InputEventKey.new()
   new_event.physical_keycode = captured_event.physical_keycode
   InputMap.action_add_event(action_name, new_event)
   
   # Salva no GameManager para persistência
   GameManager.set_custom_keybind(action_name, captured_event.physical_keycode)
   ```
3. O botão é atualizado com o nome legível da nova tecla (ex: `OS.get_keycode_string(physical_keycode)`).

---

## 4. Legenda de Botões do Controle (Estilo Xbox)

A seção de controle exibe um resumo visual informativo dos botões e suas funções:

- **Analógico Esquerdo (LS)**: Movimentação do Personagem
- **Analógico Direito (RS)**: Rotação da Câmera
- **L3 (Clique do Analógico Esquerdo) / RB**: Correr
- **Botão A**: Confirmar / Selecionar / Interagir
- **Botão B**: Voltar / Cancelar
- **Botão Menu / Start**: Pausar o Jogo
- **D-Pad (Direcionais)**: Navegação de Menus / Movimento alternativo

---

## 5. Como Adicionar uma Nova Interação do Jogador

Quando uma nova mecânica de interação for criada (ex: `interact`, `jump`, `flashlight`), siga rigorosamente este passo a passo para que ela apareça na tela de configurações tanto para teclado quanto para controle:

### Passo 1: Registrar a Ação no `project.godot` ou `GameManager`
Adicione a ação à lista padrão com os eventos de teclado e gamepad correspondentes:
```gdscript
# Exemplo para a ação "interact":
if not InputMap.has_action("interact"):
    InputMap.add_action("interact")
    
    # Teclado padrão: E
    var key_event = InputEventKey.new()
    key_event.physical_keycode = KEY_E
    InputMap.action_add_event("interact", key_event)
    
    # Gamepad padrão: Botão A (Xbox JOY_BUTTON_A = 0)
    var joy_event = InputEventJoypadButton.new()
    joy_event.button_index = JOY_BUTTON_A
    joy_event.device = -1
    InputMap.action_add_event("interact", joy_event)
```

### Passo 2: Adicionar Chaves de Tradução em `localization/translations.csv`
Adicione o nome da ação e a descrição do comando:
```csv
ACTION_INTERACT,"Interagir","Interact","Interactuar"
DESC_INTERACT,"Interagir com objetos e itens","Interact with objects and items","Interactuar con objetos e ítems"
```
Recompile os arquivos binários em seguida:
```bash
godot --headless -s localization/compile_translations.gd
```

### Passo 3: Registrar a Ação na Lista de Configurações
No script de configurações dos controles (`SettingsMenu.gd`), adicione a nova ação ao dicionário de ações configuráveis:
```gdscript
const REBINDABLE_ACTIONS: Array[Dictionary] = [
    {"action": "move_forward", "label_key": "ACTION_MOVE_FORWARD"},
    {"action": "move_back", "label_key": "ACTION_MOVE_BACK"},
    {"action": "move_left", "label_key": "ACTION_MOVE_LEFT"},
    {"action": "move_right", "label_key": "ACTION_MOVE_RIGHT"},
    {"action": "sprint", "label_key": "ACTION_SPRINT"},
    {"action": "interact", "label_key": "ACTION_INTERACT"}, # Nova ação adicionada aqui!
]

const XBOX_GAMEPAD_BINDINGS: Array[Dictionary] = [
    {"button": "LS", "desc_key": "DESC_MOVE"},
    {"button": "RS", "desc_key": "DESC_LOOK"},
    {"button": "L3 / RB", "desc_key": "ACTION_SPRINT"},
    {"button": "A", "desc_key": "ACTION_INTERACT"}, # Novo mapeamento exibido na legenda!
    {"button": "B", "desc_key": "DESC_BACK"},
    {"button": "Menu", "desc_key": "DESC_PAUSE"},
]
```
A interface irá instanciar a nova linha de remapeamento de teclado e atualizar a legenda do controle automaticamente.

### Passo 4: Consumir a Ação no `Player.gd`
No script de gameplay, utilize a ação registrada:
```gdscript
if Input.is_action_just_pressed("interact"):
    _try_interact()
```

---

## 6. Modo de Corrida: Segurar vs Alternar (Toggle)

- **Modo Segurar (*Hold*)**: O jogador só corre enquanto o botão `sprint` estiver pressionado (`Input.is_action_pressed("sprint")`).
- **Modo Alternar (*Toggle*)**: Um clique no botão ativa a corrida contínua; o jogador corre até pressionar o botão novamente ou parar completamente de se mover (`input_dir == Vector2.ZERO`).
- A preferência é armazenada em `GameManager.toggle_sprint: bool` e sincronizada com o `Player.gd`.
