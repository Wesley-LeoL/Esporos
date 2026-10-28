# GDD & Contexto de Desenvolvimento: Projeto Esporos (Godot 4 - Multiplayer Co-op Tático)

**Papel da IA:** Arquiteto de Software, Game Designer Sênior e Engenheiro especialista em Godot Engine. Você vai me orientar passo a passo no desenvolvimento de um jogo de sobrevivência tática complexo em **multiplayer cooperativo**, ajudando a escrever scripts (GDScript, RPCs, sincronização de estado), criar a arquitetura de cenas, implementar mecânicas de rede e gerenciar o repositório do projeto.

---

## 0. Instruções de Setup Inicial (Instalação, Godot & Git Multiplayer)
Antes de iniciarmos a lógica, preciso que você me oriente a:
1. **Instalar a Godot Engine 4** (versão estável mais recomendada).
2. **Configurar o Repositório Git:** Criar a pasta do projeto vinculada ao repositório **`esporos`** no GitHub, com um `.gitignore` otimizado para Godot.
3. **Arquitetura de Rede Inicial (Multiplayer Peer-to-Peer / Server-Client):** Definir a estrutura básica de conexões usando o sistema nativo de `ENetMultiplayerPeer` da Godot 4 para suportar sessões cooperativas.

---

## 1. Visão Geral, Estilo Visual e Multiplayer
* **Engine:** Godot Engine 4.
* **Perspectiva / Estilo:** **Pixel Art 2D Isométrico puro** (cenários e personagens).
* **Movimentação do Personagem:** 2D Isométrica com movimentação e sprites em **8 direções** (Norte, Sul, Leste, Oeste, Nordeste, Noroeste, Sudeste, Sudoeste).
* **Estrutura Multiplayer Co-op:**
  * Foco em **sobrevivência cooperativa online** (Joga-se em equipe para fortificar bases, caçar suprimentos e realizar cirurgias uns nos outros).
  * Sincronização de estado rigorosa (posição, animações em 8 direções, inventários, ações de crafting e estado de infecção via RPCs e MultiplayerSynchronizer).

---

## 2. Premissa Narrativa e Ambientação
* **Cenário:** Futuro distópico cyberpunk com a atmosfera corrompida por esporos fúngicos tóxicos.
* **A Infecção Latente ("Carga Patogênica"):** Todos carregam o patógeno (0% a 100%). Gerenciada por máscaras de gás, troca de filtros, supressores e purificadores.
* **O Limite do Mundo ("O Mar de Esporos"):** Raiz procedural com raio de borda vasto e expandido. Perto do perímetro extremo, a concentração de esporos torna-se letal instantaneamente, destruindo filtros e gerando hordas infinitas.

---

## 3. Sistemas de Sobrevivência, Metabolismo e Medicina
* **Metabolismo Direto:** 
  * **Fome:** Necessidade de ingestão calórica para manter a estamina e a regeneração.
  * **Sede:** Água limpa vs. Água contaminada. Beber água de poças/fontes não tratadas acelera perigosamente a carga patogênica.
* **Medicina por Membros (Cooperativa):** 
  * Ferimentos localizados que exigem desinfecção, suturas, bandagens e antibióticos.
  * *Mecânica Co-op:* Um jogador pode realizar cirurgias de campo ou aplicar curativos em um aliado ferido, exigindo tempo estático e gerando vulnerabilidade para la dupla.

---

## 4. O Sistema de Cibernética e o Implante Cerebral
* **O Dilema dos Implantes:** Implantes melhoram capacidades (filtros pulmonares, visão térmica, força mecânica), mas consomem energia de baterias e geram estresse térmico/neurológico, acelerando a infecção nas áreas integradas.
* **A Regra de Ouro: O Núcleo Neural (Implante Cerebral):**
  * **Capacidade Base:** Sem nenhum implante cerebral avançado, o corpo humano suporta **apenas 1 implante geral** (ex: um par de braços reforçados ou um filtro pulmonar). Tentar instalar mais sem suporte neural causa rejeição imediata.
  * **O Implante Cerebral (Processador Neural):** Módulo de expansão que aumenta o limite de slots de implantes gerais que o personagem pode carregar simultaneamente.
  * **Sobrecarga Sináptica (O Limite da Mente):** 
    * Se o jogador ultrapassar o limite atual suportado pelo seu cérebro (por falha de hardware, bateria esgotada ou remoção do processador), o sistema entra em colapso (*Brain Overload*).
    * **Efeitos da Sobrecarga:** Espasmos musculares, perda de controle direcional (falhas/atrasos no input de movimento), distorções de HUD e incapacidade temporária de mirar ou realizar ações complexas.

---

## 5. Sistema de Inventário, Equipamentos e Itens (Estilo Zomboid)
* **Arquitetura de Inventário Baseada em Peso e Volume:** Mochilas, bolsos, coldres e rigidez de capacidade de carga.
* **Categorias de Itens Essenciais no Mundo:**
  * **Ferramentas e Utilitários:** Chaves de fenda, martelos, serras, alicates, lanternas (com pilhas gastáveis), fitas adesivas (*Duct Tape*) para reparos de improviso.
  * **Recursos de Construção e Sucata:** Chapas de metal, tábuas de madeira, pregos, fios elétricos, sucatas eletrônicas e galões de combustível.
  * **Sobrevivência e Proteção Respiratória:** Máscaras de gás (com durabilidade de vedação), filtros de carvão ativado (descartáveis), galões de água limpa e cantis.
  * **Suprimentos Médicos:** Bandagens esterilizadas, gaze, kits de sutura (agulha e linha), desinfetantes (álcool/iodo), antibióticos de uso restrito e analgésicos.
  * **Alimentação:** Comidas enlatadas (exigem abridor de latas ou faca), alimentos perecíveis que estragam no inventário com o tempo, sementes e ferramentas agrícolas.
  * **Armas e Munições:** Armas brancas improvisadas (com degradação e risco de quebrar no meio do combate), armas de fogo e caixas de munição específica.

---

## 6. Sistema de Criação de Personagem e Árvore de Habilidades

### 6.1. Criação de Personagem por Pontos
* Sistema inicial onde o jogador gasta uma quantidade fixa de **Pontos de Personagem** para moldar seu sobrevivente, investindo em atributos, perícias iniciais ou escolhendo traços/defeitos que ajustam o saldo de pontos.

### 6.2. Árvore Completa de Habilidades (Progressão por Uso)
* **A. Combate e Sobrevivência Física:**
  * *Luta Corpo a Corpo (CQC / Lâminas e Contundentes):* Afeta dano, consumo de estamina e durabilidade de armas brancas.
  * *Pontaria:* Reduz dispersão, acelera recarga e minimiza o ruído de armas de fogo.
  * *Atletismo e Agilidade:* Melhora fôlego, velocidade e tolerância a peso de carga.
  * *Furtividade:* Reduz raio sonoro de passos e aumenta camuflagem em áreas escuras.
* **B. Engenharia, Técnica e Ofício (Crafting):**
  * *Mecânica:* Reparo e customização de veículos, capacidade de fazer *hotwire*.
  * *Eletrônica e Automação:* Circuitos, armadilhas, geradores e painéis.
  * *Carpintaria e Construção:* Paredes, barricadas, pisos e estruturas de base.
  * *Metalurgia e Soldagem:* Blindagens pesadas em metal e portões industriais.
* **C. Suporte, Ciência e Biologia:**
  * *Medicina e Primeiros Socorros:* Eficácia de bandagens, suturas e cirurgias de campo.
  * *Cibernética:* Reduz estresse sináptico e rejeição de implantes corporais.
  * *Agricultura e Botânica:* Cultivo de alimentos e identificação de plantas.
  * *Culinária:* Reduz intoxicação e garante bônus temporários de estamina.

---

## 7. O Sistema de Morte Definitiva ("Legado") e Co-op
* **Perma-death Real:** Ao morrer, o sobrevivente perece e o jogador renasce com um novo personagem em uma zona segura.
* **O Destino do Ex-Personagem:**
  * *Morte por Infecção (100%):* O corpo reanima como um **Infectado de Elite**, mantendo todo o loot e os implantes cibernéticos antigos, rondando a área para atormentar a equipe.
  * *Morte Física:* Vira um cadáver estático que atrai hordas, servindo como um baú recuperável se a equipe conseguir limpar a área.

---

## 8. Mundo Procedural, Assentamentos Vivos e Base-Building Cooperativo
* **Geração de Mundo Aleatória e Vasta (FastNoiseLite):** 
  * O mapa é gerado proceduralmente com um raio de borda amplo e expandido, garantindo longas distâncias para exploração.
  * **Dualidade do Mundo:** Contém tanto **estruturas abandonadas e ruínas** focadas puramente em looting e perigo, quanto **vilas e acampamentos ainda vivos** habitados por outros NPCs sobreviventes.
* **Ecologia Dinâmica e Evolução dos Assentamentos (O Mundo Vivo):**
  * O mundo simula o tempo e eventos em segundo plano. As vilas vivas não são estáticas: elas podem **evoluir, expandir o comércio e fortificar defesas** caso recebam ajuda do jogador (levando suprimentos, limpando zumbis ao redor ou consertando geradores), OU podem **decair, ser invadidas por hordas e ser tomadas por esporos**, virando zonas mortas e hostiles caso o jogador ignore seus pedidos de socorro ou escolha deixá-las à própria sorte.
* **Base-Building Modular:** Construção livre de paredes, pisos, geradores e sistemas de purificação de ar centralizados para a base usando `TileMap` isométrico.
* **Persistência em Rede:** Salvamento de deltas no mundo para garantir que as alterações feitas por qualquer jogador da sessão persistam corretamente no servidor.

---

## Decisões registradas (28/10/2026)

- **Modelo de rede:** um jogador hospeda e é a autoridade (servidor ENet, porta 7777). Os outros entram pelo IP. O jogo solo usa o mesmo código, numa sessão local sem rede.
- **Jogadores por sessão:** de 2 a 4.
- **Veículos:** entram no escopo (habilidade Mecânica: reparo e ligação direta). Os modelos ainda serão escolhidos e depois registrados aqui.
- **Matemática/Lógica:** sai da árvore de habilidades. Os requisitos de construção que a usavam passam para Eletrônica, Carpintaria e Metalurgia (fase 3).

### Inventário (fase 2)

- **Recipientes:** bolsos (4 L, sempre), mochila vestida (escolar 14 L; trilha 24 L, conteúdo pesa 25% menos; militar 34 L, 40% menos) e coldre de cinto (só armas, 2 L). Itens recebidos procuram espaço nessa ordem: coldre, mochila, bolsos. O que não cabe cai no chão num saco.
- **Peso:** acima da carga confortável o personagem fica lento (até -45%); o limite depende de Força e Atletismo (fase 3).
- **Estado por item:** armas e máscara têm durabilidade (a máscara vaza mais com a vedação baixa e perde vedação com golpes na cabeça; armas gastam a cada golpe que acerta e quebram). Perecíveis guardam o instante em que estragam no relógio do mundo: fresco, passado (75% das calorias) e estragado (40% e infecção). Bateria, galão de combustível, antisséptico (4 usos) e fita adesiva (5 usos) têm carga.
- **Ferramentas:** fita adesiva conserta armas e máscara (+30%). Enlatados exigem abridor, faca ou machete.
- **Saque:** [E] abre uma janela com o recipiente e o seu inventário lado a lado (pegar, pegar tudo, vestir direto, guardar). O baú construído guarda itens sem limite.

### Personagem (fase 3)

- **Criação por pontos (20):** Força e Resistência (2 a 9, base 5, 2 pontos por passo), habilidades iniciais até o nível 3 (2/5/9 pontos) e traços. Qualidades: Pulmões de aço, Imunidade forte, Metabolismo lento, Atleta, Organizado, Mãos firmes. Defeitos (devolvem até 10): Pulmão fraco, Glutão, Asmático, Sangue fino, Desajeitado, Lento, Barulhento. Há cinco modelos prontos (Equilibrado, Médica de campo, Engenheiro, Batedora, Brutamontes). A ficha é feita ao entrar na sessão e a cada morte; o anfitrião valida.
- **12 habilidades:** Luta corpo a corpo, Pontaria, Atletismo, Furtividade, Mecânica, Eletrônica, Carpintaria, Metalurgia, Medicina, Cibernética, Agricultura, Culinária. Construções: madeira com Carpintaria; gerador, purificador e torre com Eletrônica + Metalurgia; selagem com as três. Implantes pedem Medicina + Cibernética. Saves antigos: Engenharia vira Eletrônica e Lógica vira Metalurgia.
- **Estamina:** Shift corre (+55% de velocidade) gastando estamina; cada golpe também gasta (armas pesadas mais; Luta reduz). Sem estamina não corre e o golpe enfraquece. Fome, sede, sobrecarga e infecção alta atrasam a recuperação.
- **Peso:** carga confortável = 16 kg + 1,2 por ponto de Força acima de 5 + 0,6 por nível de Atletismo.

## Estado da implementação

| Fase | Conteúdo | Situação |
|---|---|---|
| 1 | Base de rede: sessão (hospedar, entrar, solo), personagens sincronizados, infectados, construção, saque, vilas, morte e legado com autoridade no anfitrião, save por jogador | **feito** |
| 2 | Inventário por peso e volume (bolsos, mochilas, coldre, sobrecarga), itens com estado próprio (durabilidade, validade, cargas), janela de saque, baú, abridor de latas | **feito** |
| 3 | Criação por pontos (atributos, habilidades, traços), 12 habilidades, estamina e corrida | **feito** |
| 4 | Cibernética neural (processador, limite de implantes, sobrecarga sináptica) | a fazer |
| 5 | Itens novos, armas que quebram, armas de fogo, som e furtividade | a fazer |
| 6 | Ações com tempo e medicina cooperativa | a fazer |
| 7 | Mundo em chunks, vilas vivas com NPCs e pedidos de socorro | a fazer |
| 8 | Agricultura e culinária; veículos | a fazer |
