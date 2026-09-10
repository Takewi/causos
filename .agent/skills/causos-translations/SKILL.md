---
name: causos-translations
description: >-
  Explains the localization and translation architecture in the Causos project,
  including how to add new text keys to translations.csv, recompile .translation binary
  resources with compile_translations.gd, consume translations in GDScript via tr(),
  and handle runtime language changes across menus.
---

# Sistema de Localização e Traduções (Causos)

Este guia documenta o funcionamento da internacionalização (i18n) no projeto **Causos**, detalhando o fluxo de trabalho para adicionar novas chaves, compilar recursos de tradução e consumir os textos localizados no código GDScript e nas cenas.

---

## 1. Arquitetura Geral

O projeto suporta três idiomas por padrão:
- **Português do Brasil (`pt_BR`)** - Idioma padrão
- **Inglês (`en`)**
- **Espanhol (`es`)**

### Estrutura de Arquivos
- [`localization/translations.csv`](file:///home/takewi/godot/causos/localization/translations.csv): **Fonte da verdade**. Tabela CSV com todas as chaves e suas respectivas traduções.
- [`localization/translations.*.translation`](file:///home/takewi/godot/causos/localization/): Recursos binários nativos da Godot gerados pelo compilador (`translations.pt_BR.translation`, `translations.en.translation`, `translations.es.translation`).
- [`localization/compile_translations.gd`](file:///home/takewi/godot/causos/localization/compile_translations.gd): Script de compilação sem dependências externas que gera os arquivos binários `.translation` a partir do CSV.
- [`project.godot`](file:///home/takewi/godot/causos/project.godot): Seção `[internationalization]` que registra os arquivos de tradução carregados pela engine.

---

## 2. Como Adicionar ou Modificar Textos

Para adicionar um novo texto na interface ou no jogo:

1. **Abra o arquivo CSV**:
   Edite [`localization/translations.csv`](file:///home/takewi/godot/causos/localization/translations.csv) e adicione a nova chave na primeira coluna, seguida pelos textos nas 3 linguagens:
   ```csv
   keys,pt_BR,en,es
   NOVA_CHAVE,"Texto em Português","Text in English","Texto en Español"
   ```
   > **Atenção**: Sempre use aspas duplas em textos com vírgulas ou caracteres especiais.

2. **Recompile as Traduções**:
   Execute o script utilitário de compilação via terminal:
   ```bash
   godot --headless -s localization/compile_translations.gd
   ```
   Esse comando atualiza instantaneamente os 3 arquivos `.translation` do projeto sem precisar abrir o editor gráfico da Godot.

---

## 3. Como Usar no Código GDScript

### 3.1 Consulta de Texto Traduzido
Utilize a função nativa `tr(key)` disponível globalmente em qualquer nó ou classe herdada de `Object`:
```gdscript
var titulo = tr("MENU_TITLE")
label.text = tr("BTN_PLAY")
```

### 3.2 Reagir à Troca de Idioma em Tempo Real
Quando o jogador troca o idioma nas configurações, a Godot emite a notificação `NOTIFICATION_TRANSLATION_CHANGED` para todos os nós da árvore.

Implemente o padrão padrão do projeto em menus e controles:
```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED:
        if is_node_ready():
            _update_localized_texts()

func _update_localized_texts() -> void:
    if not is_node_ready():
        return
    
    # Atualiza textos estáticos
    play_btn.text = tr("BTN_PLAY")
    settings_btn.text = tr("BTN_SETTINGS")
    quit_btn.text = tr("BTN_QUIT")
    
    # Se houver OptionButton com textos traduzíveis, recarregue preservando o índice:
    _refresh_options()
```

> **Importante**: Sempre valide `if is_node_ready():` antes de acessar variáveis `@onready` dentro de `_notification`, pois `NOTIFICATION_TRANSLATION_CHANGED` pode ser disparado antes da conclusão do `_ready()`.

---

## 4. Integração com o `GameManager`

O singleton [`scripts/GameManager.gd`](file:///home/takewi/godot/causos/scripts/GameManager.gd) centraliza o estado do idioma do jogo:

```gdscript
# Obter código do idioma atual
var idioma = GameManager.current_locale # "pt_BR", "en" ou "es"

# Alterar idioma programaticamente
GameManager.set_locale("en")
```

A função `GameManager.set_locale(code)`:
1. Atualiza `GameManager.current_locale`.
2. Executa `TranslationServer.set_locale(code)`.
3. Dispara o sinal `GameManager.settings_changed`.

---

## 5. Menus com Seletor de Idioma
Tanto o [`MainMenu.gd`](file:///home/takewi/godot/causos/scripts/MainMenu.gd) quanto o [`PauseMenu.gd`](file:///home/takewi/godot/causos/scripts/PauseMenu.gd) possuem o array canônico de idiomas:

```gdscript
const LANGUAGES: Array[Dictionary] = [
    {"code": "pt_BR", "label": "Português (Brasil)"},
    {"code": "en", "label": "English"},
    {"code": "es", "label": "Español"}
]
```

Os rótulos dos idiomas são mantidos em seus nomes nativos para facilitar a identificação por falantes de qualquer língua.
