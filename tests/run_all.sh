#!/bin/bash
# RODA TODOS OS TESTES E MOSTRA UM RESUMO (PASSOU / FALHOU) POR TESTBENCH.
# USO: ./tests/run_all.sh        (DE QUALQUER PASTA)
# O LOG COMPLETO DE CADA TESTE FICA EM build/<testbench>.log
# AS ONDAS (GTKWAVE) FICAM EM build/<testbench>.ghw

cd "$(dirname "$0")/.."
mkdir -p build
STD="--std=08 --workdir=build"

# 1) COMPILA O PROJETO NA ORDEM DE DEPENDENCIA
for ARQ in pacote_semaforo temporizador tabela_duracao \
           decodificador_luzes fsm_semaforo semaforo_top; do
  ghdl -a $STD $ARQ.vhdl || { echo "ERRO AO COMPILAR $ARQ.vhdl"; exit 1; }
done

# 2) RODA CADA TESTBENCH
FALHAS=0
TOTAL=0
for TB in tb_temporizador tb_tabela_duracao tb_decodificador_luzes tb_semaforo_top; do
  TOTAL=$((TOTAL + 1))
  if ghdl -a $STD tests/$TB.vhdl && ghdl -e $STD $TB &&
     ghdl -r $STD $TB --stop-time=20us --wave=build/$TB.ghw > build/$TB.log 2>&1 &&
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
