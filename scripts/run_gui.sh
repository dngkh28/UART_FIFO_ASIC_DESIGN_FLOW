#!/usr/bin/env bash
# Open OpenROAD GUI inside the OpenLane Docker image (X11 forwarding).
# Usage:
#   ./run_gui.sh 04_cts.tcl      # run a step, GUI stays open afterwards (like Innovus: run script, then inspect)
#   ./run_gui.sh                 # empty GUI; in the Tcl console use: source 04_cts.tcl  or  read_db ../results/uart.odb
set -e
PDK_ROOT=/home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
cd "$(dirname "$0")"
xhost +local:docker >/dev/null 2>&1 || true
docker run --rm -it --user 1000:1000 --network host \
  -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -e DESIGN_NAME=uart \
  -e DISPLAY=$DISPLAY -e HOME=/home/thu -v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/.Xauthority \
  -e XAUTHORITY=/.Xauthority --security-opt seccomp=unconfined \
  -e STEP_PAUSE=${STEP_PAUSE:-0} -e FLOW_STEPS="${FLOW_STEPS:-}" \
  -w "$PWD" ghcr.io/efabless/openlane2:2.3.10 openroad -gui $1
