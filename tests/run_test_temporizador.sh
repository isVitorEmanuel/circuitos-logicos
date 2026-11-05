#!/bin/bash
set -e
cd "$(dirname "$0")/.."

mkdir -p build
STD="--std=08 --workdir=build"
ghdl -a $STD pacote_semaforo.vhdl
ghdl -a $STD temporizador.vhdl
ghdl -a $STD tabela_duracao.vhdl
ghdl -a $STD tests/tb_temporizador.vhdl
ghdl -e $STD tb_temporizador
ghdl -r $STD tb_temporizador --stop-time=20us --wave=build/tb_temporizador.ghw
