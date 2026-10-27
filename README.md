# Esporos

Jogo de sobrevivência tático ciberpunk em pixel art 2D isométrico, feito em **Godot 4.7** (GDScript). Design completo em [`docs/GDD.md`](docs/GDD.md).

## Rodar
Abra a pasta no Godot 4.7+ (versão padrão, não .NET) e aperte F5. O projeto já tem presets de exportação (Windows e Linux) em `export_presets.cfg`.

**Controles:** `WASD` mover · `Espaço`/clique atacar · `E` interagir · `Tab` ou `I` menu · `X` demolir · `F5` salvar · `Esc` cancelar.

## Sistemas implementados (protótipo jogável)
- **Carga patogênica (0–100%)**: todos nascem infectados; máscara + filtro, supressor químico e purificador controlam a carga. Água contaminada acelera a infecção.
- **Mar de Esporos**: concentração sobe perto da borda do mapa; na zona letal o filtro é destruído e hordas de elite surgem sem parar.
- **Metabolismo**: calorias, carboidratos, proteínas e sede (água limpa vs. suja).
- **Medicina por membros**: 6 membros com ferida leve/profunda, sangramento, desinfecção, sutura, bandagem, antibiótico, sepse e infecção fúngica por ferida aberta.
- **Cibernética**: implantes (filtro pulmonar, HUD de escaneamento, braço reforçado) com bateria, estresse térmico, integridade e manutenção; implante danificado enfraquece a imunidade.
- **Habilidades por ação** (Mecânica, Lógica, Medicina, Engenharia/Eletrônica) e manuais; "parede de conhecimento" para construções e cirurgias (falha crítica ou morte sem o nível).
- **Perma-death com legado**: morte por infecção vira infectado de elite com inventário e implantes; morte física deixa cadáver que decompõe, atrai moscas/hordas e serve de baú.
- **Mundo procedural por seed** (FastNoiseLite), estradas, vilas com simulação em segundo plano (estoque, caravanas, risco de infestação).
- **Base-building**: pisos (TileMapLayer), paredes, portas, gerador, purificador, torre automatizada, selagem de ar.
- **Persistência de deltas**: só construções, terreno, caixas saqueadas, cadáveres, elites, vilas e legado vão para o save.

## Estrutura
```
autoload/   input_setup.gd (ações) · game.gd (log, save, legado, debug)
scripts/data/      db.gd (itens, implantes, construções) · survivor_data.gd (toda a lógica de sobrevivência)
scripts/world/     world.gd (mundo, spawn, vilas, construção, morte) · village_data.gd
scripts/entities/  structure · infected · corpse · loot_container · caravan · build_ghost
scripts/player/    player.gd
scripts/ui/        hud.gd · scan_overlay.gd
tools/             setup.sh · screenshot.sh/.gd (prints headless e comandos de debug)
```

## Ferramentas de desenvolvimento (Linux sem monitor)
```bash
tools/setup.sh
tools/screenshot.sh saida.png --frames=90 --debug="5:give:metal,10;20:tab:3"
```
