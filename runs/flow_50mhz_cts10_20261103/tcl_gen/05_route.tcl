# 05_route.tcl : global routing -> antenna check/repair -> detailed routing
source 00_setup.tcl
step_begin 05_route
open_step $RESULTS/${DESIGN}_04_cts.odb
set_propagated_clock [all_clocks]
set_rc_values

set_routing_layers -signal $RT_MIN_LAYER-$RT_MAX_LAYER -clock $RT_MIN_LAYER-$RT_MAX_LAYER
set_global_routing_layer_adjustment * 0.3
set_global_routing_layer_adjustment li1 0.99
global_route -congestion_iterations 50 -verbose
tee -file $REPORTS/antenna_grt.rpt {check_antennas -verbose}
estimate_parasitics -global_routing

repair_antennas sky130_fd_sc_hd__diode_2
check_placement -verbose

detailed_route -bottom_routing_layer $RT_MIN_LAYER -top_routing_layer $RT_MAX_LAYER \
    -output_drc $REPORTS/${DESIGN}.drc -droute_end_iter 64 -or_seed 42 -verbose 1
write_db $RESULTS/${DESIGN}_05_route.odb
