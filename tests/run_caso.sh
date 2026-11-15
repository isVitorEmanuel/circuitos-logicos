#!/bin/bash
# RODA UM CASO DE TESTE ESPECIFICO (1 A 10).
# USO:  ./tests/run_caso.sh 3          RODA O CASO 3
source "$(dirname "$0")/_compila.sh"

if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$((10#$1))" -lt 1 ] || [ "$((10#$1))" -gt 10 ]; then
  echo "USO: ./tests/run_caso.sh N [ondas]     (N de 1 a 10)"
  exit 1
fi
NN=$(printf "%02d" "$((10#$1))")

compila_projeto || exit 1
if roda_caso "$1"; then
  echo "PASSOU  caso $NN   ($(grep -o 'TODOS OS [0-9]* TESTES' build/tb_caso_$NN.log))"
  echo "        $(resumo_caso "$1")"
  STATUS=0
else
  echo "FALHOU  caso $NN   (veja build/tb_caso_$NN.log)"
  STATUS=1
fi

if [ "$2" = "ondas" ]; then
  gtkwave build/tb_caso_$NN.ghw &
fi
exit $STATUS
