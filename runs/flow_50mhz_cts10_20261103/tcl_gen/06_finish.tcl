# 06_finish.tcl : filler insertion -> reports (timing, area, power) -> write DEF/LEF/Verilog for GDSII
source 00_setup.tcl
step_begin 06_finish
open_step $RESULTS/${DESIGN}_05_route.odb
set_propagated_clock [all_clocks]
set_rc_values

filler_placement {sky130_ef_sc_hd__decap_12 sky130_fd_sc_hd__decap_8 sky130_fd_sc_hd__decap_6 sky130_fd_sc_hd__decap_4 sky130_fd_sc_hd__decap_3 sky130_fd_sc_hd__fill*}
connect_power   ;# connect VPWR/VGND/VPB/VNB of the newly inserted fillers
check_placement -verbose
estimate_parasitics -placement

tee -file $REPORTS/final_area.rpt   {report_design_area}
tee -file $REPORTS/final_timing.rpt {report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins}
                                     report_checks -path_delay min -format full_clock_expanded
                                     report_worst_slack -max
                                     report_worst_slack -min
                                     report_tns
                                     report_check_types -max_fanout -max_slew -max_capacitance -violators}
tee -file $REPORTS/final_power.rpt  {report_power}

write_db $RESULTS/${DESIGN}.odb
write_def $RESULTS/${DESIGN}.def
write_verilog $RESULTS/${DESIGN}.pnl.v
write_verilog -include_pwr_gnd $RESULTS/${DESIGN}.pwr.v
write_sdc $RESULTS/${DESIGN}_final.sdc
