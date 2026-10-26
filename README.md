# Esporos

Jogo de sobrevivência tático ciberpunk em pixel art 2D isométrico, feito em **Godot 4** (GDScript). O design completo está em [`docs/GDD.md`](docs/GDD.md).

## Rodar
1. Abra a pasta no Godot 4.7+ (versão padrão, não .NET) e aperte F5.
2. Controles: `WASD` ou setas.

## Estrutura
```
autoload/   singletons globais (registro de inputs, futuramente estado do jogo)
scenes/     cenas (.tscn)
scripts/    scripts (.gd), espelhando a estrutura de scenes/
assets/     arte e áudio
tools/      scripts de desenvolvimento (setup e prints)
docs/       documentação e GDD
```

## Ferramentas de desenvolvimento (Linux, sem monitor)
```bash
tools/setup.sh                      # instala Godot, Xvfb e Mesa; importa o projeto
tools/screenshot.sh saida.png       # renderiza o jogo e salva um print
tools/screenshot.sh saida.png --frames=90 --hold=move_right:90,move_down:90
```
`--hold=acao:frame` segura uma ação de input até o frame indicado, para capturar estados em movimento.
