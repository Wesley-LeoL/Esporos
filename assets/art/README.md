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
