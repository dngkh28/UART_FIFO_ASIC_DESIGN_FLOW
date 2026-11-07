#!/usr/bin/env bash
# Run synth.ys with Yosys inside the OpenLane 2.3.10 Docker image.
set -e
cd "$(dirname "$0")"
mkdir -p ../results ../reports
docker run --rm --user 1000:1000 -v /home/thu:/home/thu -w "$PWD" \
  ghcr.io/efabless/openlane2:2.3.10 yosys -s synth.ys -l ../results/synth.log
