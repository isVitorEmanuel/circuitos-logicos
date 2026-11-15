#!/bin/bash
# GERA A TABELA (ENTRADA / ESPERADO / OBTIDO / CICLOS) DOS 10 CASOS EM MARKDOWN.
# USO: ./tests/tabela_casos.sh   (DEPOIS DE ./tests/run_all.sh)
cd "$(dirname "$0")/.."
LOG=build/tb_casos_semaforo.log
[ -f "$LOG" ] || { echo "RODE ./tests/run_all.sh PRIMEIRO"; exit 1; }
echo "| Caso | G_A | Y_A | G_B | Y_B | N | Esperado (ciclos) | Obtido (ciclos) | Resultado |"
echo "|---|---|---|---|---|---|---|---|---|"
grep "TABELA;" "$LOG" | sed 's/.*note): //' | grep -v "CASO;G_A" | \
  awk -F';' '{printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", $2,$3,$4,$5,$6,$7,$8,$9,($10=="true"?"OK":"ERRO")}'
