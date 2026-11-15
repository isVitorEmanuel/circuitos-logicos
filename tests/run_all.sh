#!/bin/bash
# RODA TODOS OS TESTES E MOSTRA UM RESUMO (PASSOU / FALHOU) POR TESTBENCH.

cd "$(dirname "$0")/.."
mkdir -p build
STD="--std=08 --workdir=build"

# 1) COMPILA O PROJETO NA ORDEM DE DEPENDENCIA
for ARQ in pacote_semaforo temporizador tabela_duracao \
           decodificador_luzes registrador_config fsm_semaforo semaforo_top; do
  ghdl -a $STD $ARQ.vhdl || { echo "ERRO AO COMPILAR $ARQ.vhdl"; exit 1; }
done

# 2) RODA CADA TESTBENCH
FALHAS=0
TOTAL=0
for TB in tb_casos_semaforo; do
  TOTAL=$((TOTAL + 1))
  if ghdl -a $STD tests/$TB.vhdl &&
     (cd build && ghdl -e --std=08 --workdir=. $TB &&
      ghdl -r --std=08 --workdir=. $TB --stop-time=200us --wave=$TB.ghw) > build/$TB.log 2>&1 &&
     grep -q "PASSARAM" build/$TB.log && ! grep -q "ERRO" build/$TB.log; then
    echo "PASSOU  $TB   ($(grep -o 'TODOS OS [0-9]* TESTES' build/$TB.log))"
  else
    echo "FALHOU  $TB   (veja build/$TB.log)"
    FALHAS=$((FALHAS + 1))
  fi
done

echo "----------------------------------------"
echo "$((TOTAL - FALHAS)) de $TOTAL testbenches passaram"
[ "$FALHAS" -eq 0 ]
