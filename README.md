# Controlador de Tráfego em VHDL

Trabalho prático de **Circuitos Lógicos** — Opção C: controlador digital para uma interseção de duas vias (Via A e Via B), implementado em VHDL.

O projeto separa **unidade de controle** (FSM) e **caminho de dados** (temporizador, tabela de durações e registrador de configuração). Cada estado do semáforo dura exatamente **D ciclos de clock**, onde D é um **dado de entrada** (portas `DUR_*`), lido quando o `START` é aceito.

## Organização das pastas

```
circuitos-logicos/
├── pacote_semaforo.vhdl          # tipos e constantes compartilhados
├── temporizador.vhdl             # contador regressivo programável
├── tabela_duracao.vhdl           # estado -> duração em ciclos
├── decodificador_luzes.vhdl      # estado -> luzes das duas vias
├── registrador_config.vhdl       # captura durações e rounds no START (com bypass)
├── fsm_semaforo.vhdl             # unidade de controle (FSM de Moore)
├── semaforo_top.vhdl             # top-level: liga todos os módulos
├── tests/
│   ├── run_all.sh                    # roda todos os testbenches e mostra o resumo
│   ├── tb_casos_semaforo.vhdl        # testbench completo do enunciado: 10 conjuntos de dados
│   ├── tabela_casos.sh               # gera a tabela a partir do tb_casos_semaforo
│   ├── pacote_tb.vhdl                # procedimento EXECUTA_CASO, usado pelos testbenches por caso
│   ├── casos/
│   │   └── tb_caso_01.vhdl ... tb_caso_10.vhdl   # um testbench por caso de teste
│   ├── run_caso.sh                   # roda UM caso (ex.: ./tests/run_caso.sh 3)
│   ├── run_todos_casos.sh            # roda os 10 casos, um por um, e mostra a tabela
│   └── _compila.sh                   # funções compartilhadas pelos scripts dos casos
└── build/                        # gerado automaticamente (não versionar)
```

Os arquivos de código ficam na raiz do projeto. Os testbenches e seus scripts ficam em `tests/`. A pasta `build/` é criada pelos scripts e contém os arquivos intermediários do GHDL, os logs e as formas de onda (`.ghw`).

## Arquitetura

```
 DUR_*, N_ROUNDS
        │
        ▼
 ┌───────────────────┐   CAPTURA (= ESTADO é OCIOSO)
 │ REGISTRADOR_CONFIG│◄───────────────────────────────┐
 └───┬───────────┬───┘                                │
     │ CONFIG    │ N_ROUNDS                           │
     ▼           ▼                                    │
┌──────────────┐ ┌────────────────────┐ ESTADO        │
│TABELA_DURACAO│ │                    │───────────────┤
└──────┬───────┘ │                    │               │
       ▲  │      │    FSM_SEMAFORO    │ ESTADO        ▼
ESTADO_│  │DURA- │    (controle)      │────────► ┌─────────────┐
 PROX  │  │CAO   │                    │          │DECODIFICADOR│──► LUZ_A, LUZ_B
       │  ▼      │                    │          │   _LUZES    │
       │ ┌───────┴────┐   CARREGA,    │          └─────────────┘
       │ │TEMPORIZADOR│◄─ BUSY(=HABILITA)
       │ └──────┬─────┘               │
       │        │ TC                  │──► BUSY, DONE
       └────────┼────────────────────►│
                └────────────────────►│◄── START, RESET
                                      └
```

Fluxo: ao entrar em um estado, a FSM manda o temporizador carregar a duração daquele estado (que a tabela entrega a partir de `ESTADO_PROX`). O temporizador conta até `TC = '1'`, a FSM passa para o estado seguinte e o decodificador converte o estado atual nas luzes das duas vias. A FSM não sabe quanto dura cada estado, só olha `TC`. As durações e o número de rounds chegam pelas portas do top-level e passam pelo `REGISTRADOR_CONFIG`, que as trava quando a execução começa.

## O que cada arquivo faz

### `pacote_semaforo.vhdl`

Package com as definições compartilhadas, para que cada coisa seja definida **uma única vez**:

| Item | Descrição |
|---|---|
| `T_ESTADO` | Tipo enumerado dos estados da FSM: `OCIOSO`, `VERDE_A`, `AMARELO_A`, `VERDE_B`, `AMARELO_B`, `FIM` |
| `LARGURA_DUR` | Largura em bits do contador e da duração (8 bits, durações de 1 a 255 ciclos) |
| `T_CONFIG` | Registro com os dados de entrada: `DUR_VERDE_A`, `DUR_AMARELO_A`, `DUR_VERDE_B`, `DUR_AMARELO_B`, `N_ROUNDS` (todos `UNSIGNED(LARGURA_DUR-1 DOWNTO 0)`) |
| `CONFIG_ZERO` | Constante `T_CONFIG` com tudo zero |

### `temporizador.vhdl`

Contador regressivo programável.

| Porta | Direção | Função |
|---|---|---|
| `CLK` | entrada | Clock |
| `RESET` | entrada | Reset síncrono, ativo em `'1'`; zera o contador |
| `CARREGA` | entrada | Carrega uma nova duração |
| `HABILITA` | entrada | Permite a contagem; em `'0'` o contador congela |
| `DURACAO` | entrada | Duração em ciclos (`UNSIGNED`, `LARGURA_DUR` bits) |
| `TC` | saída | *Terminal count*: `'1'` quando o contador chegou a 0 (último ciclo do estado) |

Convenção: carregar `DURACAO = D` faz o contador receber `D-1` e decrementar até 0, então o estado dura **exatamente D ciclos**. Se `DURACAO = 0`, a entrada é tratada como 1. Depois de chegar a 0, `TC` permanece em `'1'` até uma nova carga.

### `tabela_duracao.vhdl`

Tabela combinacional que, dado um estado, devolve a duração dele em ciclos.

| Porta | Direção | Descrição |
|---|---|---|
| `CONFIG` | entrada | Durações dos 4 estados de luz (`T_CONFIG`) |
| `ESTADO` | entrada | Estado (`T_ESTADO`) |
| `DURACAO` | saída | Duração correspondente, em `UNSIGNED` |

Não há mais generics nem `ASSERT`: como as durações têm `LARGURA_DUR` bits por tipo, nunca excedem a largura. Para `OCIOSO` e `FIM` a tabela devolve 1, valor que a FSM não usa de fato.

### `decodificador_luzes.vhdl`

Decodificador combinacional: converte o estado da FSM nas luzes das duas vias. Cada via tem 3 bits: bit 2 = vermelho, bit 1 = amarelo, bit 0 = verde (`"100"`, `"010"`, `"001"`).

| Estado | `LUZ_A` | `LUZ_B` |
|---|---|---|
| `OCIOSO` | vermelho | vermelho |
| `VERDE_A` | verde | vermelho |
| `AMARELO_A` | amarelo | vermelho |
| `VERDE_B` | vermelho | verde |
| `AMARELO_B` | vermelho | amarelo |
| `FIM` | vermelho | vermelho |

### `registrador_config.vhdl`

Registrador de configuração **com bypass**: guarda as durações e o número de rounds quando a execução começa, para que mexer nas entradas no meio da execução não afete o round em andamento.

| Porta | Direção | Função |
|---|---|---|
| `CLK`, `RESET` | entrada | Clock e reset síncrono (zera o registrador) |
| `CAPTURA` | entrada | `'1'`: a saída acompanha a entrada e o registrador a copia a cada clock. `'0'`: a saída fica travada |
| `ENTRADA` | entrada | Configuração viva (`T_CONFIG`) |
| `SAIDA` | saída | Configuração usada pelo sistema (`T_CONFIG`) |

No top, `CAPTURA = '1'` enquanto a FSM está em `OCIOSO`. O bypass é necessário porque, no clock em que o `START` é amostrado, a tabela já precisa da duração do primeiro estado (`ESTADO_PROX = VERDE_A`), antes de o registrador ter guardado qualquer coisa. No mesmo clock a FSM sai de `OCIOSO`, `CAPTURA` cai para `'0'` e o valor fica travado.

### `fsm_semaforo.vhdl`

Unidade de controle, uma FSM de Moore (as saídas dependem só do estado atual, exceto `CARREGA` e `ESTADO_PROX`, que dependem também das entradas `START` e `TC`, ou seja, da transição; isso evita perder um ciclo entre estados).

| Porta | Direção | Função |
|---|---|---|
| `CLK`, `RESET` | entrada | Clock e reset síncrono, ativo em `'1'` |
| `START` | entrada | Inicia a execução (só é lido em `OCIOSO`) |
| `N_ROUNDS` | entrada | Ciclos completos (A + B) por `START`; `0` é tratado como `1` |
| `TC` | entrada | Fim da contagem do estado atual |
| `ESTADO` | saída | Estado atual |
| `ESTADO_PROX` | saída | Próximo estado (vai para a `TABELA_DURACAO`) |
| `CARREGA` | saída | `'1'` ao entrar em um dos 4 estados de luz |
| `BUSY` | saída | `'1'` enquanto executa os rounds (4 estados de luz) |
| `DONE` | saída | `'1'` por 1 ciclo no estado `FIM` |

Transições:

| Estado | Sai quando | Próximo estado |
|---|---|---|
| `OCIOSO` | `START = '1'` | `VERDE_A` |
| `VERDE_A` | `TC = '1'` | `AMARELO_A` |
| `AMARELO_A` | `TC = '1'` | `VERDE_B` |
| `VERDE_B` | `TC = '1'` | `AMARELO_B` |
| `AMARELO_B` | `TC = '1'` e ainda há rounds | `VERDE_A` |
| `AMARELO_B` | `TC = '1'` e era o último round | `FIM` |
| `FIM` | sempre (1 ciclo) | `OCIOSO` |

O contador interno `RODADA` conta os rounds já concluídos; o sinal `ULTIMO` (`RODADA + 1 >= N_ROUNDS`) indica o último round. `RODADA` volta a 0 no último, então não precisa de limpeza separada. `RESET` também o zera. `START` recebido fora de `OCIOSO` é ignorado.

### `semaforo_top.vhdl`

Top-level: instancia e conecta `REGISTRADOR_CONFIG` (`U_CONFIG`), `FSM_SEMAFORO` (`U_FSM`), `TABELA_DURACAO` (`U_TABELA`), `TEMPORIZADOR` (`U_TEMPORIZADOR`) e `DECODIFICADOR_LUZES` (`U_DECODIFICADOR`). Os dados do algoritmo (durações e rounds) entram por portas.

| Porta | Direção | Função |
|---|---|---|
| `CLK`, `RESET`, `START` | entrada | Interface de controle |
| `DUR_VERDE_A`, `DUR_AMARELO_A`, `DUR_VERDE_B`, `DUR_AMARELO_B` | entrada | Durações dos estados, em ciclos (`UNSIGNED`, `LARGURA_DUR` bits). `0` é tratado como `1` |
| `N_ROUNDS` | entrada | Ciclos completos por `START`. `0` é tratado como `1` |
| `LUZ_A`, `LUZ_B` | saída | Luzes das duas vias (`(2)` vermelho, `(1)` amarelo, `(0)` verde) |
| `BUSY` | saída | Executando |
| `DONE` | saída | Pulso de 1 ciclo ao concluir |

Detalhes de ligação:

- A tabela recebe `ESTADO_PROX` (não o estado atual), então a duração já está pronta no mesmo clock em que o estado muda e o temporizador carrega. Por isso não se perde ciclo entre estados.
- `HABILITA` do temporizador está ligado a `BUSY`: ele só conta durante a execução.
- As entradas `DUR_*` e `N_ROUNDS` devem estar estáveis no clock em que `START` é amostrado. Depois disso o `REGISTRADOR_CONFIG` as trava até o `DONE`.

Tempo de execução: de `START` até `DONE` são exatamente `N_ROUNDS × (DUR_VERDE_A + DUR_AMARELO_A + DUR_VERDE_B + DUR_AMARELO_B)` ciclos, sem overhead, porque o estado muda no mesmo clock que amostra `START`. O número de ciclos **depende dos dados de entrada** (durações e `N_ROUNDS`), mas não do tempo em que `START` fica ativo. Exemplo: durações 10, 3, 10, 3 e 2 rounds dão 2 × 26 = 52 ciclos. Com valores `0`, vale a regra "0 = 1".

## Testes

Todos os testes são de **sistema completo**: o testbench trata o `SEMAFORO_TOP` como uma caixa-preta, aplica dados nas portas e confere apenas o que sai (luzes, `BUSY`, `DONE`) e quantos ciclos a execução levou.

| Testbench | Módulo testado | Verificações | O que confere |
|---|---|---|---|
| `tb_casos_semaforo` | sistema completo | 40 | **Testbench do enunciado:** 10 conjuntos de dados (`G_A, Y_A, G_B, Y_B, N`), cada um com 4 verificações: ciclos = `N × soma`, luzes ciclo a ciclo (nunca verde nas duas vias, `BUSY = 1`), `DONE`/`BUSY`/vermelho ao terminar, e volta a `OCIOSO` |

### O que cada entrada significa

Cada conjunto de dados tem 5 valores, que entram pelas portas do `SEMAFORO_TOP`. Todos são contados em **ciclos de clock** e cabem em 8 bits (0 a 255).

| Entrada | Porta | O que significa |
|---|---|---|
| `G_A` | `DUR_VERDE_A` | Quantos ciclos a Via A fica **verde** (Via B vermelha) |
| `Y_A` | `DUR_AMARELO_A` | Quantos ciclos a Via A fica **amarela** (Via B ainda vermelha) |
| `G_B` | `DUR_VERDE_B` | Quantos ciclos a Via B fica **verde** (Via A vermelha) |
| `Y_B` | `DUR_AMARELO_B` | Quantos ciclos a Via B fica **amarela** (Via A ainda vermelha) |
| `N` | `N_ROUNDS` | Quantas vezes o ciclo completo (A verde, A amarela, B verde, B amarela) se repete por `START` |

`CLK`, `RESET` e `START` também são entradas, mas não fazem parte dos "dados": quem gera o clock, aplica o reset e dá o pulso de `START` é o testbench.

**Regra do zero:** qualquer duração ou `N_ROUNDS` igual a `0` é tratado como `1`.

### Como o resultado esperado é calculado

Um **round** executa os quatro estados em sequência, então dura `G_A + Y_A + G_B + Y_B` ciclos. Com `N` rounds:

```
ciclos = N × (G_A + Y_A + G_B + Y_B)        (com 0 tratado como 1)
```

Os ciclos são contados do clock em que `START` é amostrado até o `DONE`, sem overhead.

Exemplo, caso 2 (`G_A=4, Y_A=2, G_B=3, Y_B=2, N=2`): um round tem 4 + 2 + 3 + 2 = 11 ciclos, e 2 rounds dão 22. Em cada round:

| Ciclos do round | Estado | Via A | Via B |
|---|---|---|---|
| 1 a 4 | `VERDE_A` | verde | vermelha |
| 5 e 6 | `AMARELO_A` | amarela | vermelha |
| 7 a 9 | `VERDE_B` | vermelha | verde |
| 10 e 11 | `AMARELO_B` | vermelha | amarela |

### O que o testbench faz em cada caso

Para cada conjunto de dados, o testbench segue o roteiro do enunciado (itens 4 e 5):

1. **Reset**, para partir de um estado conhecido.
2. **Aplica os dados** em `DUR_*` e `N_ROUNDS`.
3. **Pulso de `START`** de 1 ciclo.
4. **Aguarda o `DONE`**, contando os ciclos e conferindo as luzes a cada ciclo.
5. **Verifica o resultado** com as 4 verificações abaixo.

| # | Verificação | O que garante |
|---|---|---|
| 1 | Ciclos obtidos = `N × soma` | A temporização inteira está correta |
| 2 | Luzes corretas em todos os ciclos, nunca verde nas duas vias, `BUSY = 1` | A sequência de estados está correta e é segura |
| 3 | Ao terminar: `DONE = 1`, `BUSY = 0`, tudo vermelho | O fim da execução é sinalizado corretamente |
| 4 | Um ciclo depois: `DONE = 0`, `BUSY = 0` | `DONE` dura 1 ciclo e o sistema voltou a `OCIOSO` |

4 verificações × 10 casos = 40 verificações.

### Os 10 casos

Os mesmos 10 conjuntos de dados existem de duas formas: todos juntos em um único testbench (`tb_casos_semaforo`, uma única forma de onda com `caso_atual` mostrando qual caso roda) e **cada um em seu próprio arquivo** (`tests/casos/tb_caso_01.vhdl` ... `tb_caso_10.vhdl`). Os arquivos por caso são pequenos: cada um só declara os dados (`G_A, Y_A, G_B, Y_B, N`), liga o DUT e chama `EXECUTA_CASO` (em `tests/pacote_tb.vhdl`), que faz o roteiro do enunciado: reset, dados, `START`, espera `DONE`, verificação.

```
./tests/run_caso.sh 3            # roda só o caso 3
./tests/run_caso.sh 3 ondas      # roda o caso 3 e abre as ondas no GTKWave
./tests/run_todos_casos.sh       # roda os 10 casos, um por um, e imprime a tabela
```

Cada caso gera `build/tb_caso_NN.log` e `build/tb_caso_NN.ghw`. Os sinais ficam na hierarquia `tb_caso_NN` → `dut` → ...

### Tabela dos 10 casos

O resultado correto é conhecido de antemão: `ciclos = N × (G_A + Y_A + G_B + Y_B)`, com `0` tratado como `1`. Para gerar a tabela do relatório (depois de `./tests/run_all.sh`):

```
./tests/tabela_casos.sh
```

| Caso | G_A | Y_A | G_B | Y_B | N | Esperado (ciclos) | Obtido (ciclos) | Resultado |
|---|---|---|---|---|---|---|---|---|
| 1 | 10 | 3 | 10 | 3 | 2 | 52 | 52 | OK |
| 2 | 4 | 2 | 3 | 2 | 2 | 22 | 22 | OK |
| 3 | 1 | 1 | 1 | 1 | 1 | 4 | 4 | OK |
| 4 | 1 | 1 | 1 | 1 | 5 | 20 | 20 | OK |
| 5 | 5 | 2 | 7 | 3 | 1 | 17 | 17 | OK |
| 6 | 255 | 1 | 1 | 255 | 1 | 512 | 512 | OK |
| 7 | 0 | 0 | 0 | 0 | 0 | 4 | 4 | OK |
| 8 | 3 | 1 | 8 | 2 | 4 | 56 | 56 | OK |
| 9 | 7 | 7 | 7 | 7 | 3 | 84 | 84 | OK |
| 10 | 1 | 1 | 1 | 1 | 255 | 1020 | 1020 | OK |

### A ideia de cada caso

| Caso | Dados | Conta | Ideia |
|---|---|---|---|
| 1 | 10, 3, 10, 3, N=2 | (10+3+10+3) × 2 = 52 | **Funcionamento normal**, com os valores padrão do projeto: verde longo, amarelo curto e 2 rounds. Inclui a volta de `AMARELO_B` para `VERDE_A`. |
| 2 | 4, 2, 3, 2, N=2 | 11 × 2 = 22 | O mesmo tipo de caso em **escala pequena**, com as vias já ligeiramente diferentes. Cabe inteiro numa tela do GTKWave, bom para figura. |
| 3 | 1, 1, 1, 1, N=1 | 4 × 1 = 4 | **Mínimo absoluto:** cada estado dura 1 ciclo e há 1 round. Com `D = 1` o temporizador carrega 0 e `TC` já vem em `'1'`, então erros de "off-by-one" na contagem aparecem aqui. |
| 4 | 1, 1, 1, 1, N=5 | 4 × 5 = 20 | Duração mínima com **vários rounds**: a troca de estado ocorre a cada clock e a volta de `AMARELO_B` para `VERDE_A` não tem folga. Testa o contador de rounds nas condições mais apertadas. |
| 5 | 5, 2, 7, 3, N=1 | 17 × 1 = 17 | **Quatro durações diferentes entre si.** Se a tabela trocasse duas durações, o total de ciclos continuaria igual; quem detecta o erro é a conferência das luzes ciclo a ciclo. |
| 6 | 255, 1, 1, 255, N=1 | 512 × 1 = 512 | **Limite de 8 bits nas durações**, com estados muito longos ao lado de estados muito curtos. Testa a contagem de 254 até 0 sem estouro. |
| 7 | 0, 0, 0, 0, N=0 | 4 × 1 = 4 | **Regra `0 = 1`.** Sem ela, o contador carregaria `0 - 1` e cada estado duraria 255 ciclos; e `N_ROUNDS = 0` não terminaria corretamente. |
| 8 | 3, 1, 8, 2, N=4 | 14 × 4 = 56 | **Caso mais completo:** durações todas diferentes, vias assimétricas e 4 rounds. O contador `rodada` passa por 0, 1, 2 e 3, e cada round repete exatamente a mesma sequência. É a melhor figura de "execução completa". |
| 9 | 7, 7, 7, 7, N=3 | 28 × 3 = 84 | **Caso simétrico:** todas as durações iguais, como contraste com os casos 5 e 8. Um número de rounds ímpar e diferente de 2 evita que um erro de contagem passe despercebido. |
| 10 | 1, 1, 1, 1, N=255 | 4 × 255 = 1020 | **Limite de 8 bits em rounds:** `rodada` sobe até 254 e a comparação `rodada + 1 >= N_ROUNDS` precisa funcionar sem estourar. Usa durações mínimas para manter a simulação curta. |

Resumo por grupo:

| Grupo | Casos | O que cobre |
|---|---|---|
| Típicos | 1, 2 | Funcionamento normal |
| Mínimo | 3, 4 | `D = 1`, com troca de estado a cada clock |
| Durações diferentes | 5, 8 | Cada estado recebe a duração certa; as vias são tratadas separadamente |
| Extremos | 6, 10 | Limites de 8 bits em duração e em rounds |
| Regra especial | 7 | Entradas `0` tratadas como `1` |
| Controle | 9 | Caso simétrico, sem diferença entre as durações |

## Como rodar os testes

### Requisitos

- [GHDL](https://github.com/ghdl/ghdl) (com suporte a VHDL-2008)
- GTKWave (opcional, para ver as formas de onda)

### Rodando todos os testes

```
cd ~/circuitos-logicos
chmod +x tests/run_all.sh
./tests/run_all.sh
```

Saída esperada:

```
PASSOU  tb_casos_semaforo   (TODOS OS 40 TESTES)
----------------------------------------
1 de 1 testbenches passaram
```

Se algum falhar, aparece `FALHOU` e o log completo fica em `build/<testbench>.log`. O script pode ser chamado de qualquer pasta.


### Ver as formas de onda

Cada testbench gera `build/<testbench>.ghw`:

```
gtkwave build/tb_semaforo_top.ghw
```

No GTKWave, para o sistema completo, expanda `tb_semaforo_top` → `dut` e adicione: `clk`, `reset`, `start`, `luz_a`, `luz_b`, `busy`, `done`, as entradas `dur_*` e `n_rounds`, e os sinais internos `s_estado`, `s_estado_prox`, `s_carrega`, `s_tc`, `s_duracao`, `s_captura` e `s_cfg`. Dentro de `u_fsm`, `rodada` mostra os rounds concluídos. Dentro de `u_temporizador`, o sinal `cont` mostra a contagem regressiva de cada estado. Para o temporizador isolado, use `tb_temporizador` → `dut` → `cont`.

### Sobre as ondas

- `100` - Vermelho
- `010` - Amarelo
- `001` - Verde

## Convenções do projeto

- Nomes em português e código em MAIÚSCULAS (o VHDL não diferencia maiúsculas de minúsculas, então isso é só padrão de estilo).
- Reset síncrono, ativo em `'1'`.
- Duração D = exatamente D ciclos de clock.
- Cada parâmetro é definido uma única vez (tipos e constantes no package). Durações e rounds são dados de entrada do top-level, não generics.

## Limitações conhecidas

- `START` é lido por nível, só no estado `OCIOSO`. Se ficar em `'1'` depois do `DONE`, a FSM inicia outra execução imediatamente. Um sincronizador com detector de borda (`start_sync`) evitaria isso, mas não é necessário para o funcionamento em simulação.
- Durações e número de rounds limitados a 255 (`LARGURA_DUR = 8`); basta aumentar a constante no pacote para valores maiores.
- As entradas `DUR_*` e `N_ROUNDS` precisam estar estáveis no clock em que `START` é amostrado; não há sincronização nem validação de faixa (o valor `0` vira `1`).
