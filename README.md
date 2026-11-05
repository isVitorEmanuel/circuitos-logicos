# Controlador de Tráfego em VHDL

Trabalho prático de **Circuitos Lógicos** — Opção C: controlador digital para uma interseção de duas vias (Via A e Via B), implementado em VHDL.

O projeto separa **unidade de controle** (FSM) e **caminho de dados** (temporizador e tabela de durações). Cada estado do semáforo dura exatamente **D ciclos de clock**, onde D vem da tabela de durações.

## Organização das pastas

```
circuitos-logicos/
├── pacote_semaforo.vhdl      # tipos e constantes compartilhados
├── temporizador.vhdl         # contador regressivo programável
├── tabela_duracao.vhdl       # estado -> duração em ciclos
├── tests/
│   ├── tb_temporizador.vhdl          # testbench do temporizador
│   └── run_test_temporizador.sh      # script que compila e simula
└── build/                    # gerado automaticamente (não versionar)
```

Os arquivos de código ficam na raiz do projeto. Os testbenches e seus scripts ficam em `tests/`. A pasta `build/` é criada pelo script e contém os arquivos intermediários do GHDL e a forma de onda (`.ghw`).

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

### `tests/tb_temporizador.vhdl`

Testbench autoverificável do temporizador, com contador de erros e resumo final. Cobre:

| Teste | O que verifica |
|---|---|
| 1 | Durações 1, 2, 3, 5, 10, 100 e 255 duram exatamente D ciclos |
| 2 | `DURACAO = 0` é tratada como 1 ciclo |
| 3 | `HABILITA = '0'` congela a contagem e ela retoma de onde parou |
| 4 | `RESET` no meio da contagem zera o contador |
| 5 | Nova carga no meio da contagem substitui a anterior |
| 6 | `TC` permanece em `'1'` após o fim, até uma nova carga |

Total: **14 verificações**. Cada uma imprime `OK [...]` ou `ERRO [...]`, e o final mostra `TODOS OS 14 TESTES PASSARAM`.

### `tests/run_test_temporizador.sh`

Script que entra na raiz do projeto (então pode ser chamado de qualquer pasta), compila os arquivos na ordem correta, elabora o testbench e roda a simulação, gerando as ondas em `build/tb_temporizador.ghw`.

## Como rodar os testes

### Requisitos

- [GHDL](https://github.com/ghdl/ghdl) (com suporte a VHDL-2008)
- GTKWave (opcional, para ver as formas de onda)

No Fedora:

```
sudo dnf install ghdl gtkwave
```

### Rodando o teste do temporizador

```
cd ~/circuitos-logicos
./tests/run_test_temporizador.sh
```

Na primeira vez, se o script não for executável:

```
chmod +x tests/run_test_temporizador.sh
```

Saída esperada (final):

```
TODOS OS 14 TESTES PASSARAM
```

### Ver as formas de onda

```
gtkwave build/tb_temporizador.ghw
```

No GTKWave, expanda `tb_temporizador` → `dut` e adicione: `clk`, `reset`, `carrega`, `habilita`, `duracao`, `tc` e `cont` (o sinal interno `cont` mostra a contagem regressiva).

## Convenções do projeto

- Nomes em português e código em MAIÚSCULAS (o VHDL não diferencia maiúsculas de minúsculas, então isso é só padrão de estilo).
- Reset síncrono, ativo em `'1'`.
- Duração D = exatamente D ciclos de clock.
- Cada parâmetro é definido uma única vez (generics no top, tipos e constantes no package).

## Próximos passos

- `lights_decoder` / decodificador das luzes (estado -> sinais das duas vias)
- `fsm_semaforo` (unidade de controle, com contador de rounds e sinal `DONE`)
- `semaforo_top` (interface `CLK`, `RESET`, `START`, `DONE`)
- Testbench completo com pelo menos 10 conjuntos de teste
- Relatório (formato IEEE) e vídeo de apresentação
