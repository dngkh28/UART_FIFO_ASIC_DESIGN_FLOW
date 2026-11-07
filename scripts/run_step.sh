#!/usr/bin/env bash
# Usage: ./run_step.sh 02_floorplan.tcl    (steps 02..06 run in OpenROAD, 07 in Magic, 01 in Yosys)
set -e
step=$1
PDK_ROOT=/home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
cd "$(dirname "$0")"; mkdir -p ../reports ../results
name=${step%.tcl}
case $name in
  01*) cmd="yosys -c $step -l ../reports/$name.log" ;;
  07*|08*|09*) cmd="magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc $step" ;;
  10*) cmd="netgen -batch source $step" ;;
  *)   cmd="openroad -exit -no_splash $step" ;;
esac
docker run --rm --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -e DESIGN_NAME=uart \
  -w "$PWD" ghcr.io/efabless/openlane2:2.3.10 $cmd 2>&1 | tee ../reports/$name.log | tail -${TAIL:-40}
