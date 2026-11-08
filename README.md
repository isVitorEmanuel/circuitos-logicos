# Controlador de Tráfego em VHDL

Trabalho prático de **Circuitos Lógicos** — Opção C: controlador digital para uma interseção de duas vias (Via A e Via B), implementado em VHDL.

O projeto separa **unidade de controle** (FSM) e **caminho de dados** (temporizador e tabela de durações). Cada estado do semáforo dura exatamente **D ciclos de clock**, onde D vem da tabela de durações.

## Organização das pastas

```
circuitos-logicos/
├── pacote_semaforo.vhdl          # tipos e constantes compartilhados
├── temporizador.vhdl             # contador regressivo programável
├── tabela_duracao.vhdl           # estado -> duração em ciclos
├── decodificador_luzes.vhdl      # estado -> luzes das duas vias
├── fsm_semaforo.vhdl             # unidade de controle (FSM de Moore)
├── semaforo_top.vhdl             # top-level: liga todos os módulos
├── tests/
│   ├── run_all.sh                    # roda todos os testbenches e mostra o resumo
│   ├── run_test_temporizador.sh      # roda só o teste do temporizador
│   ├── tb_temporizador.vhdl          # testbench do temporizador
│   ├── tb_tabela_duracao.vhdl        # testbench da tabela de durações
│   ├── tb_decodificador_luzes.vhdl   # testbench do decodificador
│   └── tb_semaforo_top.vhdl          # testbench do sistema completo
└── build/                        # gerado automaticamente (não versionar)
```

Os arquivos de código ficam na raiz do projeto. Os testbenches e seus scripts ficam em `tests/`. A pasta `build/` é criada pelos scripts e contém os arquivos intermediários do GHDL, os logs e as formas de onda (`.ghw`).

## Arquitetura

```
                     START ──────────────┐
                                         ▼
   ┌────────────────────┐  ESTADO_PROX  ┌──────────────────┐
   │                    │──────────────►│  TABELA_DURACAO  │
   │    FSM_SEMAFORO    │               └────────┬─────────┘
   │   (controle)       │                        │ DURACAO
   │                    │  CARREGA, BUSY(=HABILITA)
   │                    │──────────────►┌────────▼─────────┐
   │                    │◄──────────────│   TEMPORIZADOR   │
   └──┬────────────┬────┘      TC       └──────────────────┘
      │ ESTADO     │
      ▼            ▼
┌─────────────┐   BUSY, DONE
│DECODIFICADOR│
│   _LUZES    │──► LUZ_A, LUZ_B
└─────────────┘
```

Fluxo: ao entrar em um estado, a FSM manda o temporizador carregar a duração daquele estado (que a tabela entrega a partir de `ESTADO_PROX`). O temporizador conta até `TC = '1'`, a FSM passa para o estado seguinte e o decodificador converte o estado atual nas luzes das duas vias. A FSM não sabe quanto dura cada estado, só olha `TC`.

## O que cada arquivo faz

### `pacote_semaforo.vhdl`

Package com as definições compartilhadas, para que cada coisa seja definida **uma única vez**:

| Item | Descrição |
|---|---|
| `T_ESTADO` | Tipo enumerado dos estados da FSM: `OCIOSO`, `VERDE_A`, `AMARELO_A`, `VERDE_B`, `AMARELO_B`, `FIM` |
| `LARGURA_DUR` | Largura em bits do contador e da duração (8 bits, durações de 1 a 255 ciclos) |

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

| Elemento | Descrição |
|---|---|
| Generics | `DUR_VERDE_A`, `DUR_AMARELO_A`, `DUR_VERDE_B`, `DUR_AMARELO_B` (padrão: 10, 3, 10, 3) |
| Porta `ESTADO` | Estado (`T_ESTADO`) de entrada |
| Porta `DURACAO` | Duração correspondente, em `UNSIGNED` |

Há `ASSERT` em tempo de elaboração que falha se alguma duração não couber em `LARGURA_DUR` bits. Para `OCIOSO` e `FIM` a tabela devolve 1, valor que a FSM não usa de fato.

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

### `fsm_semaforo.vhdl`

Unidade de controle, uma FSM de Moore (as saídas dependem só do estado atual, exceto `CARREGA`, que depende também da transição).

| Porta / generic | Direção | Função |
|---|---|---|
| `N_ROUNDS` | generic | Ciclos completos (A + B) por `START` (padrão: 2) |
| `CLK`, `RESET` | entrada | Clock e reset síncrono, ativo em `'1'` |
| `START` | entrada | Inicia a execução (só é lido em `OCIOSO`) |
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

O contador interno `RODADA` conta os rounds já concluídos e volta a 0 no último, então não precisa de limpeza separada. `RESET` também o zera. `START` recebido fora de `OCIOSO` é ignorado.

### `semaforo_top.vhdl`

Top-level: instancia e conecta `FSM_SEMAFORO` (`U_FSM`), `TABELA_DURACAO` (`U_TABELA`), `TEMPORIZADOR` (`U_TEMPORIZADOR`) e `DECODIFICADOR_LUZES` (`U_DECODIFICADOR`). É aqui que os parâmetros do projeto são definidos, uma única vez.

| Porta / generic | Direção | Função |
|---|---|---|
| `DUR_VERDE_A`, `DUR_AMARELO_A`, `DUR_VERDE_B`, `DUR_AMARELO_B` | generic | Durações dos estados, em ciclos (padrão: 10, 3, 10, 3) |
| `N_ROUNDS` | generic | Ciclos completos por `START` (padrão: 2) |
| `CLK`, `RESET`, `START` | entrada | Interface de controle |
| `LUZ_A`, `LUZ_B` | saída | Luzes das duas vias (`(2)` vermelho, `(1)` amarelo, `(0)` verde) |
| `BUSY` | saída | Executando |
| `DONE` | saída | Pulso de 1 ciclo ao concluir |

Detalhes de ligação:

- A tabela recebe `ESTADO_PROX` (não o estado atual), então a duração já está pronta no mesmo clock em que o estado muda e o temporizador carrega. Por isso não se perde ciclo entre estados.
- `HABILITA` do temporizador está ligado a `BUSY`: ele só conta durante a execução.

Tempo de execução: de `START` até `DONE` são exatamente `N_ROUNDS × (DUR_VERDE_A + DUR_AMARELO_A + DUR_VERDE_B + DUR_AMARELO_B)` ciclos, sem overhead, porque o estado muda no mesmo clock que amostra `START`. O número de ciclos depende dos **parâmetros**, não dos dados. Com os valores padrão: 2 × 26 = 52 ciclos.

## Testes

| Testbench | Módulo testado | Verificações | O que confere |
|---|---|---|---|
| `tb_temporizador` | `TEMPORIZADOR` | 14 | Durações de 1 a 255, `DURACAO = 0`, pausa com `HABILITA`, `RESET` no meio, recarga no meio, `TC` permanece em 1 |
| `tb_tabela_duracao` | `TABELA_DURACAO` | 6 | Duração de cada estado (valores diferentes entre si) e `OCIOSO`/`FIM` = 1 |
| `tb_decodificador_luzes` | `DECODIFICADOR_LUZES` | 6 | Luzes das duas vias nos 6 estados, nunca verde nas duas |
| `tb_semaforo_top` | sistema completo (e a FSM) | 9 | Execução completa de 22 ciclos com luzes conferidas ciclo a ciclo, `START` ignorado durante a execução, `DONE` com 1 ciclo, `RESET` no meio |

A FSM não tem testbench próprio: é exercitada por inteiro pelo `tb_semaforo_top`.

Esses são testes simples, para verificar que o sistema funciona. O testbench completo exigido pelo enunciado (pelo menos 10 conjuntos de dados) ainda está pendente.

## Como rodar os testes

### Requisitos

- [GHDL](https://github.com/ghdl/ghdl) (com suporte a VHDL-2008)
- GTKWave (opcional, para ver as formas de onda)

No Fedora:

```
sudo dnf install ghdl gtkwave
```

### Rodando todos os testes

```
cd ~/circuitos-logicos
chmod +x tests/run_all.sh
./tests/run_all.sh
```

Saída esperada:

```
PASSOU  tb_temporizador   (TODOS OS 14 TESTES)
PASSOU  tb_tabela_duracao   (TODOS OS 6 TESTES)
PASSOU  tb_decodificador_luzes   (TODOS OS 6 TESTES)
PASSOU  tb_semaforo_top   (TODOS OS 9 TESTES)
----------------------------------------
4 de 4 testbenches passaram
```

Se algum falhar, aparece `FALHOU` e o log completo fica em `build/<testbench>.log`. O script pode ser chamado de qualquer pasta.

### Rodando só o teste do temporizador

```
./tests/run_test_temporizador.sh
```

### Ver as formas de onda

Cada testbench gera `build/<testbench>.ghw`:

```
gtkwave build/tb_semaforo_top.ghw
```

No GTKWave, para o sistema completo, expanda `tb_semaforo_top` → `dut` e adicione: `clk`, `reset`, `start`, `luz_a`, `luz_b`, `busy`, `done`, e os sinais internos `s_estado`, `s_estado_prox`, `s_carrega`, `s_tc` e `s_duracao`. Dentro de `u_temporizador`, o sinal `cont` mostra a contagem regressiva de cada estado. Para o temporizador isolado, use `tb_temporizador` → `dut` → `cont`.

### Rodando manualmente, sem o script

A partir da pasta `circuitos-logicos/`:

```
mkdir -p build
ghdl -a --std=08 --workdir=build pacote_semaforo.vhdl
ghdl -a --std=08 --workdir=build temporizador.vhdl
ghdl -a --std=08 --workdir=build tabela_duracao.vhdl
ghdl -a --std=08 --workdir=build decodificador_luzes.vhdl
ghdl -a --std=08 --workdir=build fsm_semaforo.vhdl
ghdl -a --std=08 --workdir=build semaforo_top.vhdl
ghdl -a --std=08 --workdir=build tests/tb_semaforo_top.vhdl
ghdl -e --std=08 --workdir=build tb_semaforo_top
ghdl -r --std=08 --workdir=build tb_semaforo_top --stop-time=20us --wave=build/tb_semaforo_top.ghw
```

O `--stop-time` serve de segurança: o clock é gerado por `CLK <= NOT CLK AFTER ...`, então uma simulação que não termina sozinha rodaria para sempre.

## Ordem de compilação

```
pacote_semaforo -> temporizador -> tabela_duracao -> decodificador_luzes -> fsm_semaforo -> semaforo_top -> testbenches
```

O `pacote_semaforo` sempre vem primeiro, pois os outros arquivos dependem dele.

## Convenções do projeto

- Nomes em português e código em MAIÚSCULAS (o VHDL não diferencia maiúsculas de minúsculas, então isso é só padrão de estilo).
- Reset síncrono, ativo em `'1'`.
- Duração D = exatamente D ciclos de clock.
- Cada parâmetro é definido uma única vez (tipos e constantes no package, durações e rounds nos generics do top).

## Limitações conhecidas

- `START` é lido por nível, só no estado `OCIOSO`. Se ficar em `'1'` depois do `DONE`, a FSM inicia outra execução imediatamente. Um sincronizador com detector de borda (`start_sync`) evitaria isso, mas não é necessário para o funcionamento em simulação.
- Durações limitadas a 255 ciclos (`LARGURA_DUR = 8`); basta aumentar a constante no pacote para durações maiores.

## Próximos passos

- Testbench completo com pelo menos 10 conjuntos de teste e tabela de ciclos (Entrada / Esperado / Obtido / Ciclos)
- Formas de onda e capturas para o relatório
- Diagramas de bloco (sistema, FSM, temporizador, caminho de dados)
- Relatório (formato IEEE) e vídeo de apresentação
- Opcionais: temporização programável por portas, modo noturno, botão de pedestres