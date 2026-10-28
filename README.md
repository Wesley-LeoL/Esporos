# Esporos

Jogo de sobrevivência tático ciberpunk em pixel art 2D isométrico, feito em **Godot 4.7** (GDScript). Design completo em [`docs/GDD.md`](docs/GDD.md).

## Rodar
Abra a pasta no Godot 4.7+ (versão padrão, não .NET) e aperte F5. O projeto já tem presets de exportação (Windows e Linux) em `export_presets.cfg`.

**Controles:** `WASD` mover · `Espaço`/clique atacar · `E` interagir · `Tab` ou `I` menu · `X` demolir · `F5` salvar · `Esc` cancelar · `F1` ou `` ` `` console de testes.

## Co-op (2 a 4 jogadores)
- **Hospedar:** na tela de título, ligue **CO-OP: ABERTO** e clique em Novo jogo ou Continuar. O jogo abre a porta UDP **7777**, e o anfitrião é a autoridade da sessão: simula o mundo e guarda o save.
- **Entrar:** digite o IP do anfitrião e clique em **ENTRAR NA SESSÃO**. O mundo é gerado pela mesma seed, e só as alterações vêm pela rede.
- **Na mesma rede local:** use o IP local do anfitrião (por exemplo 192.168.0.10). O Windows pode pedir para liberar o jogo no firewall.
- **Pela internet:** o anfitrião precisa redirecionar a porta UDP 7777 no roteador para o próprio PC, ou o grupo pode usar uma rede virtual (Tailscale, ZeroTier, Radmin VPN) e entrar pelo IP dessa rede.
- **Sobreviventes:** cada um fica salvo pelo nome do jogador. Ao voltar para a sessão com o mesmo nome, o jogador continua com o mesmo personagem, se ele ainda estiver vivo.
- **Menu e console:** no co-op, o menu (Tab) não pausa o mundo. Os comandos do console (F1) rodam no anfitrião, sobre o personagem de quem digitou.

Para testar o co-op numa máquina só: `godot --path . -- --autostart=host --name=A` em uma janela e `godot --path . -- --autostart=join:127.0.0.1 --name=B` em outra.

## Sistemas implementados (protótipo jogável)
- **Carga patogênica (0–100%)**: todos nascem infectados; máscara + filtro, supressor químico e purificador controlam a carga. Água contaminada acelera a infecção.
- **Mar de Esporos**: concentração sobe perto da borda do mapa; na zona letal o filtro é destruído e hordas de elite surgem sem parar.
- **Inventário por peso e volume**: bolsos, mochilas e coldre com capacidade em litros, sobrecarga que deixa lento, itens com durabilidade (armas e máscara), validade (perecíveis estragam) e carga (bateria, combustível, antisséptico, fita). Janela de saque com o recipiente e o inventário lado a lado; baú para guardar.
- **Metabolismo**: fome (calorias) e sede (água limpa vs. suja); carboidratos e proteínas foram removidos do protótipo.
- **Medicina por membros**: 6 membros com ferida leve/profunda, sangramento, desinfecção, sutura, bandagem, antibiótico, sepse e infecção fúngica por ferida aberta.
- **Cibernética**: implantes (filtro pulmonar, HUD de escaneamento, braço reforçado) com bateria, estresse térmico, integridade e manutenção; implante danificado enfraquece a imunidade.
- **Habilidades por ação** (Mecânica, Lógica, Medicina, Engenharia/Eletrônica) e manuais; "parede de conhecimento" para construções e cirurgias (falha crítica ou morte sem o nível).
- **Perma-death com legado**: morte por infecção vira infectado de elite com inventário e implantes; morte física deixa cadáver que decompõe, atrai moscas/hordas e serve de baú.
- **Mundo procedural por seed** (FastNoiseLite), estradas, vilas com simulação em segundo plano (estoque, caravanas, risco de infestação).
- **Base-building**: pisos (TileMapLayer), paredes, portas, gerador, purificador, torre automatizada, selagem de ar.
- **Persistência de deltas**: só construções, terreno, caixas saqueadas, baús, cadáveres, elites, vilas e legado vão para o save (saves da versão anterior são convertidos).

## Console de testes (cheats)
`F1` ou `` ` `` abre o terminal (pausa o jogo). Digite `ajuda`. Comandos: `dar <item> [qtd]`, `dano <membro|todos> <n>`, `spawn [normal|elite] [n]`, `tp <x> <y>` (ou `abrigo`, `vila <n>`, `borda`, `cadaver`, `elite`), `set` (patogeno, sangue, calorias, agua, bateria, filtro, calor), `skill`, `curar`, `restaurar`, `implante`, `god`, `matar`, `infectar`, `limpar`, `pos`, `salvar`. Códigos prontos: `kit`, `kit_medico`, `kit_build`, `kit_cyber`. Tab completa, ↑↓ navega no histórico.

## Arte
Pacote FreeSample (prédios, ruas, calçadas, anúncios) mais a arte gerada no mesmo estilo para personagens, construções, caixas, chão e ícones. Prédios noturnos do *Town Sampler* e objetos de rua do *Neon District* completam a cidade. A interface (HUD, menu, título, tela de morte) é pixel art ciberpunk gerada por `tools/gen_ui.py`, com a fonte Jersey 10 (OFL). Detalhes e como regerar em [`assets/art/README.md`](assets/art/README.md).

## Estrutura
```
autoload/   input_setup.gd (ações) · net.gd (sessão co-op, ENet, replicação) · game.gd (mensagens, save, legado, debug)
scripts/data/      db.gd (itens, implantes, construções) · items.gd (instâncias e listas de itens) · survivor_data.gd (toda a lógica de sobrevivência)
scripts/world/     world.gd (mundo, spawn, vilas, construção, morte) · village_data.gd
scripts/entities/  structure · infected · corpse · loot_container · caravan · build_ghost
scripts/player/    player.gd
scripts/ui/        hud.gd (layout) · ui_theme.gd (cores, fonte, tema) · pixel_bar.gd · scan_overlay.gd · dev_console.gd
tools/             setup.sh · screenshot.sh/.gd (prints headless) · gen_art.py, art_models.py, art_render.py (arte gerada) · build_art_catalog.py
scripts/art/       art_db.gd + art_catalog.gd (pacote) · gen_art.gd + gen_catalog.gd (arte gerada)
```

## Ferramentas de desenvolvimento (Linux sem monitor)
```bash
tools/setup.sh
tools/screenshot.sh saida.png --frames=90 --debug="5:give:metal,10;20:tab:3"
godot --headless --path . -s res://tools/test_inventory.gd   # teste da lógica do inventário
```
