#!/bin/bash
# FUNCOES COMPARTILHADAS PELOS SCRIPTS DOS CASOS (NAO RODAR DIRETO).
# TODOS OS ARQUIVOS GERADOS (INCLUSIVE OS DA ELABORACAO DO GHDL) FICAM EM build/.

cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p build
STD="--std=08 --workdir=build"
STD_BUILD="--std=08 --workdir=."   # PARA COMANDOS EXECUTADOS DENTRO DE build/

# COMPILA O PROJETO + PACOTE DE APOIO DOS TESTBENCHES
compila_projeto() {
  for ARQ in pacote_semaforo temporizador tabela_duracao \
             decodificador_luzes registrador_config fsm_semaforo semaforo_top; do
    ghdl -a $STD $ARQ.vhdl || { echo "ERRO AO COMPILAR $ARQ.vhdl"; return 1; }
  done
  ghdl -a $STD tests/pacote_tb.vhdl || { echo "ERRO AO COMPILAR tests/pacote_tb.vhdl"; return 1; }
}

# RODA UM CASO (NUMERO 1..10). LOG EM build/tb_caso_NN.log, ONDAS EM build/tb_caso_NN.ghw.
# RETORNA 0 SE PASSOU.
roda_caso() {
  local NN
  NN=$(printf "%02d" "$((10#$1))")
  local TB="tb_caso_$NN"
  ghdl -a $STD tests/casos/$TB.vhdl &&
  (cd build && ghdl -e $STD_BUILD $TB &&
   ghdl -r $STD_BUILD $TB --stop-time=200us --wave=$TB.ghw) > build/$TB.log 2>&1 &&
  grep -q "PASSARAM" build/$TB.log && ! grep -q "ERRO" build/$TB.log
}

# IMPRIME UMA LINHA RESUMO DO CASO A PARTIR DO LOG
resumo_caso() {
  local NN
  NN=$(printf "%02d" "$((10#$1))")
  grep "TABELA;" build/tb_caso_$NN.log | sed 's/.*note): //' | grep -v "CASO;G_A" | \
    awk -F';' '{printf "G_A=%s Y_A=%s G_B=%s Y_B=%s N=%s | esperado %s ciclos, obtido %s ciclos", $3,$4,$5,$6,$7,$8,$9}'
}
