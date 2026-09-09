# Causos

Um protótipo de jogo de terror atmosférico e exploração em floresta densa com relevo orgânico contínuo e estética retrô dos anos 90 (*Low Poly*), desenvolvido com **Godot 4.x**.

> 👁️ **A Premissa & Inspiração:**  
> A ideia central do projeto é ser um **jogo de terror e isolamento psicológico**, concebido a partir de uma **experiência pessoal real vivida pelo autor na mata fechada no Rio Grande do Sul**. O objetivo é recriar a atmosfera pesada, o suspense e a desorientação de estar sozinho na mata nativa do interior gaúcho, resgatando a essência dos tradicionais "causos" — narrativas misteriosas passadas de boca em boca onde o folclore, a solidão e o medo do desconhecido na escuridão da floresta se entrelaçam.

---

## 🌲 Destaques Técnicos e Funcionalidades

- **Relevo Contínuo Procedural:**
  - Terreno modulado via `FastNoiseLite` com amostragem em coordenadas globais de mundo, garantindo emendas perfeitamente contínuas e sem quebras entre blocos.
  - Malha subdividida de terreno facetado (*flat shaded*) com colisões físicas geradas dinamicamente via `ConcavePolygonShape3D`.

- **Distribuição Orgânica por Amostragem Poisson (Bridson):**
  - Eliminação completa de padrões em grade ou corredores artificiais.
  - Otimização com *Swap-and-Pop* $O(1)$ e suporte a zonas de exclusão (`exclusion_zones`) para construções, cabanas e clareiras.

- **7 Arquétipos Botânicos Nativos & Variados:**
  1. **Copa Guarda-Chuva Clássica:** Dossel aberto amplo (12-15m de diâmetro) com galhos laterais curvos, ramificações terciárias e ramos cruzados no teto visual.
  2. **Bifurcada em "V":** Tronco com bifurcação baixa (~2.3m) dividindo em dois eixos dominantes com copas entrelaçadas.
  3. **Árvore Antiga / Torta:** Tronco grosso inclinado, bacias assimétricas, nós retorcidos e galho morto lateral.
  4. **Árvore Jovem / Esguia:** Tronco fino e copa compacta para preenchimento vertical.
  5. **Árvore Alta Multinível:** Tronco de ~14m com 3 andares horizontais de galhos e copa emergente.
  6. **Árvore Seca / Esquelética:** Esqueleto de galhos pontiagudos e quebrados sem folhas, com casca cinzenta desbotada.
  7. **Tronco Partido / Quebrado:** Tronco quebrado a meia-altura (~4.8m) com lascas pontiagudas de madeira expostas.

- **Folhagem Volumétrica 3D:**
  - Planos 2D com orientações tridimensionais completas (*Roll, Pitch e Yaw*), incluindo planos inclinados para baixo (visíveis para o jogador olhando para cima) e para cima (captando a luz solar).
  - Materiais otimizados com `TRANSPARENCY_ALPHA_SCISSOR` e `SHADING_MODE_PER_VERTEX` para eliminar gargalos de sobreposição de transparência na GPU.

- **Alta Performance & Jolt Physics Batching:**
  - Inicialização de blocos *offline* com compilação única de formas compostas no motor Jolt Physics, reduzindo o tempo de geração de **147 ms para ~27 ms** (~5.3x mais rápido).
  - Fila de streaming suave (*Chunk Streaming Queue*) que carrega 1 bloco por frame ao se locomover pelo mapa, mantendo 60 FPS estáveis sem travamentos (*stutter*).

- **Iluminação & Atmosfera:**
  - Sol quente de final de tarde com manchas de luz marcadas no chão da floresta.
  - Luz ambiente verde-oliva com intensidade balanceada para evitar áreas de breu artificial.
  - Neblina suave (*Depth Fog*) dourada com alcance visual claro em primeiro plano.

---

## 🎮 Controles

| Comando | Ação |
| :--- | :--- |
| **W, A, S, D** ou **Setas** | Movimentação do personagem |
| **Shift** | Correr (*Sprint*) |
| **Mouse** | Olhar / Rotação da câmera |
| **Esc** | Liberar / Capturar cursor do mouse |

---

## 🛠️ Como Executar

1. Tenha instalado o **Godot 4.x** (testado na versão 4.3 / 4.7+).
2. Clone o repositório:
   ```bash
   git clone git@github.com:Takewi/causos.git
   ```
3. Abra o Godot Engine, selecione **Importar**, aponte para a pasta do projeto e abra o arquivo `project.godot`.
4. Pressione `F5` para executar o projeto a partir da cena principal (`scenes/Main.tscn`).

---

## 📜 Licença (Proprietary / Source-Available)

Este projeto é disponibilizado publicamente sob uma **Licença Proprietária de Uso Não Comercial (Source-Available)**:
- **Permitido:** Leitura do código-fonte, estudo pessoal, pesquisa e execução local para fins de aprendizado e avaliação técnica.
- **Proibido:** Qualquer uso comercial, venda, monetização direta ou indireta, redistribuição, cópia total ou parcial de código ou assets visuais para outros projetos sem prévia autorização por escrito do autor.

Consulte o arquivo [LICENSE](LICENSE) para ler os termos jurídicos na íntegra.
