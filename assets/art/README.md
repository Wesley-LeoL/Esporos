# Arte provisória do Esporos

A arte atual do projeto está sendo organizada para permitir substituições sem alterar a lógica de jogo.

## Pastas

- `tiles/world/`: terreno, ruas e calçadas.
- `tiles/structures/`: prédios, módulos e ruínas.
- `tiles/props/`: objetos e detalhes de cenário.
- `ui/`: painéis, molduras e ícones da interface.

## Referência visual recebida

O arquivo `FreeSample.zip` contém sprites PNG isométricos de edifícios, blocos de construção, estradas, calçadas e antena parabólica. Preserve os PNGs originais ao importá-los; não os redimensione nem os edite por cima. Os nomes originais devem ser mantidos para facilitar a atualização do pacote.

## HUD

A paleta e os estilos dos painéis ficam centralizados em `scripts/ui/ui_theme.gd`. A interface usa quatro indicadores principais (contaminação, vida, fome e sede), enquanto informações situacionais ficam no texto auxiliar. Quando a arte final estiver pronta, substitua os estilos/recursos da interface sem misturar caminhos de textura com regras de sobrevivência.

## Pacote integrado (FreeSample)

Os PNGs originais estão em `tiles/world/`, `tiles/structures/` e `tiles/props/`, sem edição e com os nomes originais; o zip fica em `source/FreeSample.zip`. Cada PNG traz 4 vistas (rotações) lado a lado. `tools/build_art_catalog.py` mede cada vista (recorte, vértices da base e pegada em células) e gera `scripts/art/art_catalog.gd`; o jogo recorta as vistas com `scripts/art/art_db.gd`. Rode o script de novo ao atualizar o pacote.

A grade do mundo segue a do pacote: losangos de 80x40 px. Prédios de várias células são cortados em faixas verticais de 20 px para a ordenação de profundidade funcionar com o personagem em qualquer lado deles.

## Arte gerada (`generated/`)

O que o pacote não cobre foi gerado por código no mesmo estilo (projeção 2:1, luz da esquerda, contorno preto de 1 px, paleta derivada do pacote):

- `characters/`: sobrevivente em 8 direções (parado, andando, golpe) em 8 variações (máscara, braço e olho cibernéticos), infectado, elite e cadáver.
- `structures/`: parede, porta (fechada/aberta), gerador, purificador e selagem (ligado/desligado) e torre (8 direções, ligada/desligada).
- `props/`: caixas de saque (comum, médico e técnico, cheias e vazias), saco de itens largados e caravana (4 direções).
- `world/ground.png`: chão (8 tipos x 3 variações).
- `ui/icons.png`: ícones dos itens do inventário.

Para mudar ou regerar: edite os modelos em `tools/art_models.py` (personagens e objetos são montados com caixas, cilindros e elipsoides) e rode `python3 tools/gen_art.py` (requer Pillow e numpy). O script também reescreve `scripts/art/gen_catalog.gd` com tamanho de quadro, âncora e animações. Para trocar um desses sprites por arte desenhada à mão, mantenha o mesmo tamanho de quadro e âncora, ou ajuste os valores no catálogo.
