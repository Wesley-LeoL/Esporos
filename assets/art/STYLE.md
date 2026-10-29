# Padrão visual do Esporos

O padrão foi tirado do pacote FreeSample, que é a base do jogo. Toda a arte gerada
(`tools/gen_art.py`, `tools/gen_city.py`, `tools/gen_ground.py`) segue estas regras. Arte
nova, desenhada à mão ou de outro pacote, precisa seguir as mesmas regras para não destoar.

## Diagnóstico (29/10)

Medição de todas as artes do jogo:

| Conjunto | Cores por sprite (mediana) | Alfa parcial | Tamanho médio das áreas de cor | Situação |
|---|---|---|---|---|
| FreeSample (prédios, chão) | 24 | 0% | 9,4 px | **referência** |
| Arte gerada (estruturas) | 12 | 0% | 3,0 px | coerente; só o ruído de 1 px destoava |
| Chão gerado (antigo) | 23 | 0% | 3,5 px | **destoava**: ruído pixel a pixel |
| Neon District (64 px) | 1.282 | 30% | 1,0 px | **destoava**: arte reduzida, com anti-aliasing |
| Town Sampler | 99 | 10% | 3,6 px | **destoava**: grade de 64x32, brilhos suaves, outra paleta |

O problema era a densidade de detalhe, não a escala da janela, que já é inteira (2x). O
Neon District é arte de alta resolução reduzida para 64 px, então cada "pixel" dele é bem
menor que um pixel do FreeSample. O Town Sampler usa outra grade e brilhos com transparência.
O chão gerado tinha ruído de 1 px, que parece uma textura fina perto das superfícies lisas
do pacote.

**Solução:** os dois pacotes saíram do jogo (os arquivos estão em
`assets/art/source/extras/`, ignorados pelo Godot). Tudo o que eles cobriam foi gerado de
novo neste padrão: 17 prédios em 4 vistas, 44 objetos e 20 tipos de chão.

## Regras

1. **Projeção e grade.** A projeção é isométrica 2:1 e a célula é um losango de 80x40 px.
   1 unidade de modelo é a aresta de uma célula (56,6 px no plano). Na vertical,
   1 unidade = 49 px.
2. **Pixel 1:1.** Nada é redimensionado. Não há anti-aliasing nem alfa parcial: cada pixel
   é opaco ou transparente. O jogo é desenhado em escala inteira (2x).
3. **Contorno.** O contorno externo tem 1 px quase preto (`#000000`). As linhas internas
   aparecem só entre volumes separados, no tom mais escuro da rampa.
4. **Luz.** A luz vem da esquerda e de cima. O topo é o tom mais claro, uma face lateral é
   média e a outra escura. Há um chanfro claro de 1 px na borda do topo das caixas.
5. **Superfícies lisas.** Cada face tem uma cor sólida. O detalhe vem em **lascas**:
   - são retângulos ou paralelogramos de 2 px ou mais, alinhados à grade isométrica;
   - usam 1 ou 2 tons vizinhos da mesma rampa;
   - cobrem menos de ~10% da área;
   - **nunca** é ruído de 1 px.
6. **Linhas da grade.** Juntas, faixas e tábuas seguem os eixos da grade, em degraus de
   2 px na horizontal por 1 px na vertical.
7. **Paleta** (`tools/art_render.py`, `RAMPS`). Rampas de 5 tons derivadas do pacote:
   - base em índigo e ardósia dessaturados;
   - ferrugem e terracota como segunda cor;
   - verdes apagados (fungo, oliva) para vegetação;
   - cores saturadas (neon, luzes acesas) só em pontos de luz, em menos de 5% do sprite.
8. **Escala.**
   - Uma pessoa de 1,8 m tem cerca de 42 px.
   - Um andar mede cerca de 59 px (1,2 unidade).
   - Uma porta tem cerca de 2 m.
   - Prédios ocupam células inteiras.
9. **Vistas.** Prédios têm 4 vistas (rotações de 90°) lado a lado, como no pacote. Na vista
   0 a porta fica na face +y. Objetos de uma célula têm uma vista, com quadros para
   ligado/desligado ou variações.

## Onde fica cada coisa

| Arte | Gerador | Saída |
|---|---|---|
| Chão (20 tipos x 3 variações) | `tools/gen_ground.py` | `generated/world/ground.png` |
| Prédios da cidade, do subúrbio e do campo | `tools/gen_city.py` (`BUILDINGS`) | `generated/city/buildings/` + `scripts/art/city_catalog.gd` |
| Objetos de cenário | `tools/gen_city.py` (`PROPS`) | `generated/city/props/` |
| Personagens, construções, caixas, veículos e ícones | `tools/art_models.py` | `generated/characters/`, `structures/`, `props/`, `ui/` |

Para regerar tudo, rode `python3 tools/gen_art.py`. Uma prancha com todas as texturas sai
em `tools/make_texture_sheet.py`.
