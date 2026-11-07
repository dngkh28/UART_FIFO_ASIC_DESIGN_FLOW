# 04_cts.tcl : clock tree synthesis + post-CTS timing repair
source 00_setup.tcl
step_begin 04_cts
open_step $RESULTS/${DESIGN}_03_place.odb
set_rc_values
estimate_parasitics -placement
repair_clock_inverters

configure_cts_characterization
clock_tree_synthesis -buf_list {sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_2} \
    -root_buf sky130_fd_sc_hd__clkbuf_16 \
    -sink_clustering_size $CTS_CLUSTER_SIZE -sink_clustering_max_diameter $CTS_CLUSTER_DIAM \
    -sink_clustering_enable
set_propagated_clock [all_clocks]
estimate_parasitics -placement
repair_clock_nets -max_wire_length 0
estimate_parasitics -placement
legalize
estimate_parasitics -placement
tee -file $REPORTS/cts.rpt {report_cts}

# post-CTS timing repair
repair_timing -verbose -setup -setup_margin 0.05 -max_buffer_percent 50
repair_timing -verbose -hold  -setup_margin 0.05 -hold_margin 0.1 -max_buffer_percent 50
legalize
estimate_parasitics -placement
write_db $RESULTS/${DESIGN}_04_cts.odb
