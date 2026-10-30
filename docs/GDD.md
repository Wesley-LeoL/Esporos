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
- **Veículos:** entram no escopo (habilidade Mecânica: reparo e ligação direta). Modelos escolhidos na fase 8: picape blindada e moto elétrica (detalhes abaixo).
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

### Cibernética neural (fase 4)

- **Núcleo neural:** sem processador o corpo aguenta 1 implante geral. Processador neural Mk1 (até 2) e Mk2 (até 4) ocupam o encaixe do cérebro e gastam bateria. Instalar além do limite causa rejeição imediata: o implante se perde, o membro é ferido e o estresse sináptico vai a 100%.
- **Estresse sináptico (0-100%):** cada implante ativo soma estresse (Cibernética e o processador reduzem; superaquecimento aumenta).
- **Sobrecarga:** mais implantes do que o cérebro suporta (bateria vazia, processador danificado ou removido) ou estresse ≥ 80%. Efeitos: o controle chega atrasado e desviado, espasmos empurram o personagem, os golpes saem em direção errada, o HUD treme e muda de cor, ações complexas (tratar, fabricar, operar, construir, consertar) ficam bloqueadas, o calor sobe e a cabeça sofre dano lento.
- **Implantes novos:** pernas hidráulicas (+12% de velocidade, corrida mais barata) e malha subdérmica (-25% de dano). Implantes podem ser removidos com um kit cirúrgico (Cibernética reduz o risco).

### Itens, armas de fogo, som e furtividade (fase 5)

- **Ferramentas** (não se gastam): martelo (também arma), chave de fenda, alicate e serra. Construções de madeira pedem martelo e pregos; elétricas pedem chave de fenda, alicate, fios e sucata eletrônica; torre e selagem pedem serra. Receitas novas: pregos, fios, munição 9 mm e cartuchos.
- **Utilidades e médicos:** lanterna (gasta carga; pilhas recarregam), cantil (3 goles, enche com água limpa), gaze (vale como bandagem), álcool 70% (5 usos, vale como antisséptico), analgésico (2 min sem penalidade de membros feridos).
- **Armas de fogo:** pistola 9 mm (pente 12, 430 px) e espingarda calibre 12 (2 cartuchos, 6 chumbos). Miram no mouse, têm dispersão (Pontaria reduz; cansaço aumenta), desgastam, engasgam quando gastas e quebram. [R] recarrega com a munição do inventário. A pistola cabe no coldre.
- **Som:** passos (andando 110, correndo 270, agachado 35 px; Furtividade reduz; Barulhento e sobrecarga aumentam), golpes, tiros (900 e 1300 px), portas, construções, demolições e torres fazem barulho. Infectados no raio vão investigar o local.
- **Furtividade:** [C] agacha (mais lento, quase silencioso, visto de 55% da distância). Correr e lanterna acesa aumentam a distância de visão. Infectados lembram do alvo por alguns segundos e depois vão até onde o viram. Andar agachado perto de infectados treina Furtividade. Camuflagem por áreas escuras fica para quando houver ciclo de luz.

### Ações com tempo e medicina cooperativa (fase 6)

- **Ações com tempo:** tratar (2 a 8 s), operar (14 s), remover implante (10 s), manutenção (5 s), fabricar, consertar, recarregar (1,6 s pistola, 2,4 s espingarda), comer, beber, vestir mochila ou máscara, trocar filtro e ler manuais. Uma barra aparece no HUD e sobre a cabeça do personagem (todos veem). Andar ou levar um golpe interrompe. Medicina, Cibernética e Pontaria encurtam o tempo.
- **Tratar um aliado:** na aba Corpo escolha o paciente (aliados a até ~2 tiles). Curativos, antibiótico, sutura, instalação e remoção de implantes usam os suprimentos e as habilidades de quem trata. Os dois ficam parados e vulneráveis; se qualquer um se mexer ou for atacado, o procedimento para. Tratar outra pessoa é 25% mais rápido e rende 50% mais experiência; suturar a si mesmo falha mais e operar a si mesmo deixa o implante com integridade 80%.

### Ferimentos, roupas e armaduras (fase 12)

- **Golpe nem sempre sangra.** A chance de abrir ferida cresce com o dano (10% + 2,2% por ponto, até 75%). Golpes de menos de 4 pontos nunca sangram. A roupa reduz o dano ("defesa") e a chance de sangrar ("anti-corte").
- **Uma ferida por vez.** Com uma ferida aberta, um novo corte não abre outra em outro membro: ele piora o sangramento da que já existe (e a reabre, se estava enfaixada). Um golpe forte (16+) a torna profunda. O dano de vida continua indo para o membro atingido.
- **Roupas:** 5 espaços (cabeça, tronco, mãos, pernas, pés), além da máscara. Cada espaço cobre membros: o tronco cobre também 60% dos braços, as mãos 50% dos braços, os pés 40% das pernas. A defesa somada vai até 80%. As peças gastam ao absorver golpes; em farrapos (0%) protegem 40% do normal. Conserto com fita, como as outras coisas.
- **Conjuntos:** cada peça dá um bônus pequeno, e o conjunto completo soma um bônus maior:
  - *Mecânico* (macacão, luvas e botas de trabalho): consertos de itens, veículos e muros mais rápidos;
  - *Médico* (jaleco, luvas cirúrgicas e calça hospitalar): tratamentos mais rápidos e suturas mais seguras;
  - *Tático* (capacete, colete, luvas, calça e botas militares): mais dano corpo a corpo e recarga mais rápida;
  - *Anti-esporos* (traje, luvas e botas de borracha): menos carga patogênica e menos gasto de filtro;
  - *Sucata* (capacete, armadura e caneleiras, fabricados na bancada): só proteção, e pesa.
- **Onde achar:** roupas comuns nas caixas comuns, as médicas em clínicas, as de mecânico, anti-esporos e militares nas caixas técnicas (as militares são raras). Todo sobrevivente começa de camiseta ou moletom, calça jeans e tênis.
- **Aba Corpo:** à esquerda ficam os espaços de roupa (botão direito: tirar ou consertar), os conjuntos e os bônus, e as roupas do inventário com o botão "Vestir". À direita, os 6 membros em linha, só com o nome: o contorno é vermelho neon e pulsa quando o membro está machucado. Clicar num membro mostra a vida, o estado, a proteção da roupa e o tratamento.

### Mundo em chunks e vilas vivas (fase 7)

- **Mapa: cidades pequenas e aldeias (29/10):**
  - *Sem metrópole.* O mapa tem 6 cidades pequenas e cerca de 22 aldeias no campo. As cidades têm praça no centro, uma rua em anel e quatro ruas saindo dela, com lojas, mercado, bar, clínica, oficina e casas de frente para a rua. As aldeias são uma clareira com casas, celeiro e lavouras. Não há mais Abrigo Alfa: as 16 vilas vivas ficam espalhadas, cada uma cercada por uma cerca de chapas com portões onde as estradas passam (infectados não atravessam nem escolhem quem está lá dentro) e com NPCs.
  - *Estados de cada lugar:* **viva** (as 16 vilas, com NPCs e comércio), **abandonada** (janelas quebradas, paredes caídas, telhados faltando, entulho e mais saque) ou **tomada por esporos** (fungo no chão, nas paredes e dentro das casas, ar pesado em volta e mais infectados). Também há casas isoladas na beira das estradas, quase todas abandonadas.
  - *Estradas:* asfalto entre cidades e terra batida para as aldeias. Ao longo delas há carcaças e veículos abandonados.
  - *Prédios exploráveis:*
    - o piso é do chão (madeira, cerâmica, concreto); as paredes ficam nas bordas das células, com porta, janelas, vitrine, parede quebrada ou tomada por fungo, em 5 materiais;
    - as casas maiores têm uma divisória com passagem;
    - os móveis ficam encostados nas paredes: cama, armário, sofá, TV, cozinha, prateleiras, balcão, macas etc.;
    - as caixas de saque ficam nos cômodos.
  - *Corte estilo The Sims:* dentro de um prédio, o telhado some e as paredes entre o jogador e a câmera descem. As paredes que o jogador constrói seguem a mesma regra.
  - *Visto de fora:* não dá para ver o interior. Prédios sem telhado (ruínas) mostram o interior em sombra. Colado numa janela, vitrine ou buraco na parede, o jogador espia: o telhado some e o interior aparece com pouca sombra, mas as paredes continuam inteiras. Logo atrás do prédio, o telhado fica translúcido sobre o interior escuro.
- **Cerco às vilas (29/10):**
  - *Cerca com vida e níveis.* Cada trecho tem vida própria. Os níveis são: 1, chapa remendada (400); 2, chapa reforçada (800); 3, muralha de concreto com espetos (1500). A vila sobe de nível sozinha quando prospera (nível de prosperidade 2 e 3) e tem sucata no estoque. Os moradores consertam os trechos danificados e reconstroem os derrubados (um por vez, com sucata e sem infectado dentro). O jogador conserta com [E] por 2 sucatas (+35%, e ganha reputação).
  - *Infectados atacam.* Quem enxerga gente lá dentro (jogador ou morador) vai até uma brecha ou portão aberto. Se não houver, bate no trecho de muro mais perto até derrubar.
  - *Hordas.* Com jogador por perto, uma horda de 4 a 12+ infectados vem de tempos em tempos (maior com mais infestação), e chega um aviso. Longe dos jogadores, a horda é simulada: a força dela contra a defesa (nível da cerca e da vila) decide a infestação e as perdas.
  - *Defesa.* Os guardas lutam e os moradores fogem e podem morrer (cadáver). Há armadilhas de espetos do lado de fora dos portões e torres automáticas nos cantos, que só funcionam com cerca de nível 2 ou mais. A armadilha de espetos também entra no menu de construção.
  - *Queda.* Infectados dentro da cerca aumentam a infestação, e cada morador morto também. Com infestação em 100% ou sem moradores, a vila cai: os portões ficam abertos, os NPCs somem e ela vira zona morta. Limpar a área devolve a vila aos sobreviventes.
- **Começo e renascimento:** o primeiro sobrevivente acorda num prédio sorteado (vivo ou abandonado, longe dos esporos); quem entra depois no co-op acorda no mesmo prédio; após uma morte, numa cama da equipe ou, sem cama, num prédio novo sorteado.
- **HUD:** vitais só com ícone e barra; sem faixa de comandos; barra rápida de 5 espaços na direita (o item continua no inventário; 1 a 5 ou clique usam; botão direito tira). Curativos na barra tratam o membro mais ferido.
- **Modo construção [B]:** faixa única embaixo com as abas Fundação/Utilidades/Decoração por cima; escolher um item não fecha nada; moldura amarela na tela; a câmera desce para o personagem ficar no alto; a HUD normal some. B/Esc saem; X demolição.
- **Mundo maior:** raio de 150 tiles (antes 64) e 16 vilas. A geração planeja tudo em dados a partir da seed (igual em todos os peers); só os chunks de 16×16 células perto dos jogadores viram nós e tiles. O anfitrião carrega ao redor de todos os jogadores; cada cliente, ao redor de si. Caixas, construções, baús e pisos ficam em dados e valem com o chunk carregado ou não.
- **Vilas vivas:** prosperidade (nível 0 a 3) aumenta a produção, o número de guardas e as ofertas do comerciante. NPCs (comerciante, guardas, moradores) aparecem quando alguém se aproxima; guardas atacam infectados perto da vila. [E] num NPC abre o painel da vila.
- **Pedidos de socorro:** a vila pede comida, remédios, materiais ou peças eletrônicas, ou que se eliminem infectados por perto, com prazo de 6 minutos (aviso para todos e lista na aba Mundo). Atender sobe prosperidade, reputação e população e dá recompensa a quem entregou. Ignorar faz a vila perder moradores e acumular infestação, até cair.
- **Reputação:** doações e pedidos atendidos dão reputação da equipe com aquela vila; o comerciante troca itens da especialidade da vila por reputação.
- **Zonas mortas:** vila que cai fica sem NPCs, cercada de infectados e com esporos densos ao redor. Limpar a área por 30 s liberta a vila.
- Saves de antes desta fase: o mapa mudou, então só os sobreviventes (de volta ao abrigo), o legado e o tempo de jogo são aproveitados.

### Agricultura, culinária e veículos (fase 8)

- **Agricultura:** canteiro (3 madeiras + 4 pregos, martelo). [E] com enxada e sementes planta; regar (regador com 4 regas ou uma garrafa de água, limpa ou suja) dá ~150 s de água; a planta só cresce regada e com ar limpo (esporos < 0,35, ou dentro de uma selagem de ar); em esporos densos (≥ 0,6) ela morre. Batata (5 min), milho (6 min) e tomate (4 min). Agricultura acelera o crescimento e aumenta a colheita e a chance de recuperar sementes. O crescimento é calculado pelo relógio do mundo, então continua mesmo com o chunk descarregado.
- **Culinária:** fogareiro (2 metais + 3 sucatas) e panela. Receitas: sopa de batata, ensopado (feijão + batata + tomate), milho assado e ferver água suja (vira água limpa). Comida cozida dá "bem alimentado" por 3 min (estamina recupera 50% mais rápido). Sem prática, a comida pode queimar; Culinária também reduz a intoxicação de comida estragada.
- **Veículos (escolhidos):**
  - *Picape blindada:* 2,4x a velocidade a pé, 4 lugares (motorista + 3), porta-malas de 60 L, gasta combustível (galões), barulhenta (520 px), atropela forte.
  - *Moto elétrica:* 3,2x, só o piloto, porta-malas de 8 L, gasta baterias, quase silenciosa (240 px), atropela fraco.
  - Ficam abandonados na beira das estradas, trancados, com pouca energia e desgastados. Ligação direta exige Mecânica 2 (pode dar choque); consertar pede martelo, chave de fenda, 1 metal e 2 sucatas. Atropelar desgasta; abaixo de 30% de estado o veículo perde velocidade e a 0% não anda. Quem dirige controla o movimento (como a pé); passageiros acompanham. O porta-malas abre na janela de saque e os veículos vão para o save.
- **Construção estilo The Sims:** o piso ocupa a célula do losango; paredes, meia parede, parede com janela, porta e portão ficam nas **bordas** da célula (aponte o mouse para o lado do quadrado). As antigas paredes e portas em bloco saíram do jogo. A janela de construção [B] tem 3 abas:
  - *Fundação:* pisos (metal, madeira, concreto), paredes, janelas, portas e portões.
  - *Utilidades:* bancada de fabricação (receitas técnicas exigem estar perto dela), mesa de reparos, fogareiro, gerador a combustão, gerador eólico, banco de baterias, purificador, torre, selagem de ar, coletor de chuva, canteiro, baú e cama.
  - *Decoração:* luminária de chão, poste de luz, letreiro neon, mesa, cadeira, sofá, tapete, vaso e estante.
- **Energia por produção e consumo:** construções de energia a até 10 tiles umas das outras formam uma rede. O eólico gera 22 W por módulo do mastro (1 a 5; [E] sobe um módulo por 2 metais + 2 sucatas) vezes o vento; prédios e construções por perto atrapalham o vento. O gerador a combustão (100 W) só queima o combustível que falta na rede. Os bancos de baterias guardam a sobra e cobrem a falta. Quando falta energia, a prioridade é selagem, purificador, torre e depois as luzes. As luzes só gastam à noite.
- **Mesa de reparos:** armas de fogo (fita + 1 sucata), mochilas e coldres só se consertam nela. Nela, todo conserto rende +45% (em vez de +30% com fita em qualquer lugar).
- **Dia, noite e clima:** um dia dura 24 minutos (1 hora do jogo = 1 minuto). À noite o mundo escurece; luzes acesas, a lanterna e os postes iluminam. No escuro, os infectados enxergam até 40% mais perto, exceto quem está com lanterna ou sob luz. Os climas são:
  - *Céu limpo* e *nublado*;
  - *Chuva:* abafa os passos (75%), rega os canteiros e enche os coletores;
  - *Tempestade:* vento forte (bom para os eólicos), passos a 55% e visão menor;
  - *Névoa de esporos:* +0,12 de esporos e visão a 60%.
  O clima muda a cada 3 a 7 minutos. O HUD mostra a hora e o clima.

## Estado da implementação

| Fase | Conteúdo | Situação |
|---|---|---|
| 1 | Base de rede: sessão (hospedar, entrar, solo), personagens sincronizados, infectados, construção, saque, vilas, morte e legado com autoridade no anfitrião, save por jogador | **feito** |
| 2 | Inventário por peso e volume (bolsos, mochilas, coldre, sobrecarga), itens com estado próprio (durabilidade, validade, cargas), janela de saque, baú, abridor de latas | **feito** |
| 3 | Criação por pontos (atributos, habilidades, traços), 12 habilidades, estamina e corrida | **feito** |
| 4 | Cibernética neural (processador, limite de implantes, rejeição, estresse e sobrecarga sináptica, remoção de implantes) | **feito** |
| 5 | Ferramentas e materiais, lanterna, cantil, médicos novos, armas de fogo com munição, som e furtividade | **feito** |
| 6 | Ações com tempo (barra, interrupção por movimento ou dano) e medicina cooperativa (curativos e cirurgias em aliados) | **feito** |
| 7 | Mundo em chunks (raio 150), vilas vivas com NPCs, prosperidade, reputação, comércio, pedidos de socorro e zonas mortas | **feito** |
| 8 | Agricultura (canteiro, sementes, rega, colheita), culinária (fogareiro, receitas, água fervida) e veículos (picape blindada e moto elétrica) | **feito** |
| 10 | Padrão visual único (STYLE.md), arte própria no lugar do Town Sampler e do Neon District | **feito** |
| 11 | Cidades pequenas e aldeias (vivas, abandonadas, tomadas por esporos), prédios exploráveis com corte estilo The Sims | **feito** |
| 12 | Ferimentos com chance de sangrar (uma ferida por vez), roupas e armaduras com defesa, desgaste e conjuntos com bônus, aba Corpo em neon | **feito** |
| 9 | Construção em bordas (estilo The Sims) com 3 abas, utilidades e decoração, rede de energia (eólico, combustão, baterias), mesa de reparos, dia/noite, clima e iluminação | **feito** |
