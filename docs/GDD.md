# GDD: Projeto Survival Ciber-Apocalíptico "Esporos" (Godot 4)

Documento de referência do projeto. Papéis esperados do assistente: Arquiteto de Software, Game Designer Sênior e Engenheiro especialista em Godot (GDScript, arquitetura de cenas, mecânicas e gestão do repositório).

## 1. Visão geral e estilo visual
- **Engine:** Godot Engine 4.
- **Perspectiva / estilo:** Pixel Art 2D isométrico puro. Cenário e personagens 100% em pixel art 2D.
- **Movimentação:** 2D isométrica, sprites em 8 direções (N, S, L, O, NE, NO, SE, SO).
- **Inspirações:** *Project Zomboid* (complexidade de sobrevivência, microgerenciamento, proficiências, consequências severas) e *The Last of Us* (atmosfera opressiva, esporos no ar).

## 2. Premissa narrativa e ambientação
- **Cenário:** futuro distópico cyberpunk, atmosfera global corrompida por esporos fúngicos tóxicos.
- **Infecção latente ("Carga Patogênica"):** todos os sobreviventes carregam o patógeno de forma latente. O objetivo é **gerenciar a carga patogênica (0% a 100%)** com máscaras de gás, troca de filtros, supressores químicos e estações de purificação.
- **Limite do mundo ("O Mar de Esporos"):** o mapa tem raio máximo procedural. Perto da borda a concentração de esporos é letal, destrói filtros e gera hordas infinitas de infectados de elite, no lugar de paredes invisíveis.

## 3. Sistemas de sobrevivência e metabolismo
- **Metabolismo detalhado:** fome (calorias, carboidratos, proteínas) e sede (água limpa vs. contaminada, que acelera a infecção).
- **Medicina por membros:** ferimentos em membros específicos exigem desinfecção, suturas, bandagens e antibióticos para evitar sepse ou infecção fúngica na corrente sanguínea.
- **Cibernética e trade-offs:** implantes (filtros pulmonares mecânicos, HUDs de escaneamento, membros reforçados).
  - *Dilema:* implantes consomem energia de baterias e geram estresse térmico/neurológico. Danificados ou sem manutenção, enfraquecem o sistema imunológico e a infecção avança mais rápido nas áreas integradas ao metal.

## 4. Habilidades (estilo Zomboid) e pré-requisitos
- **Progressão por ação:** Mecânica, Matemática/Lógica, Medicina e Engenharia/Eletrônica evoluem com a prática no mundo ou lendo manuais e livros técnicos.
- **Parede de conhecimento:**
  - *Base-building:* construções avançadas (geradores a combustão, purificadores industriais, torres automatizadas, selagem de ar) exigem níveis específicos de Engenharia e Matemática.
  - *Implantes:* implantes de alta tecnologia exigem níveis altos em Medicina e Cibernética; operar sem o nível necessário causa falhas críticas ou morte.

## 5. Morte definitiva ("Legado")
- **Perma-death real:** ao morrer, o personagem some e o jogador renasce do zero com um novo sobrevivente aleatório em uma área segura.
- **Destino do ex-personagem:**
  - *Morte por infecção (100% de carga):* o corpo se reanima como **Infectado de Elite em pixel art**, mantendo inventário e implantes antigos, rondando o local da morte.
  - *Morte física (fome, sangramento, combate):* o corpo vira **cadáver estático** que se decompõe, atrai moscas e hordas e serve como baú recuperável se o novo personagem voltar a tempo.

## 6. Mundo procedural e base-building
- **Geração procedural:** mapa por *seed* com ruído (FastNoiseLite), estradas conectadas e pequenas vilas/acampamentos com simulação básica em segundo plano (comércio, caravanas, risco de infestação).
- **Base-building modular:** tiles isométricos 2D para paredes, pisos, portas e defesas em qualquer lugar do mundo, com materiais coletados (sucata, madeira, metal).
- **Persistência (deltas):** salvar apenas as modificações do jogador no mundo procedural (construções, terreno, estados de cadáveres/infectados antigos).

## Notas técnicas
- A partir do Godot 4.3 o nó `TileMap` está obsoleto. O projeto usa **`TileMapLayer`**, que o substitui, com `TileSet` isométrico (tiles 64x32, layout diamond-down).
- Renderizador: **Compatibility** (OpenGL), por ser o mais compatível, inclusive com renderização por software nos prints automatizados.
