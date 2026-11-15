#!/bin/bash
# RODA OS 10 CASOS DE TESTE, CADA UM EM SEU PROPRIO TESTBENCH, E MOSTRA O RESUMO
# USO: ./tests/run_todos_casos.sh
source "$(dirname "$0")/_compila.sh"

compila_projeto || exit 1

FALHAS=0
for I in 1 2 3 4 5 6 7 8 9 10; do
  NN=$(printf "%02d" "$I")
  if roda_caso "$I"; then
    echo "PASSOU  caso $NN   $(resumo_caso "$I")"
  else
    echo "FALHOU  caso $NN   (veja build/tb_caso_$NN.log)"
    FALHAS=$((FALHAS + 1))
  fi
done

echo "----------------------------------------"
echo "$((10 - FALHAS)) de 10 casos passaram"
echo
echo "| Caso | G_A | Y_A | G_B | Y_B | N | Esperado (ciclos) | Obtido (ciclos) | Resultado |"
echo "|---|---|---|---|---|---|---|---|---|"
for I in 1 2 3 4 5 6 7 8 9 10; do
  NN=$(printf "%02d" "$I")
  grep "TABELA;" build/tb_caso_$NN.log 2>/dev/null | sed 's/.*note): //' | grep -v "CASO;G_A" | \
    awk -F';' '{printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $2,$3,$4,$5,$6,$7,$8,$9,($10=="true"?"OK":"ERRO")}'
done
[ "$FALHAS" -eq 0 ]
