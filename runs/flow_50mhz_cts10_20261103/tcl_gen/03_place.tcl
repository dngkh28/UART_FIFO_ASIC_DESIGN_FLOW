# 03_place.tcl : global placement -> IO placement -> global placement -> repair_design -> detailed placement
source 00_setup.tcl
step_begin 03_place
open_step $RESULTS/${DESIGN}_02_floorplan.odb
set_rc_values

# global placement without IO, then place pins, then final global placement
global_placement -skip_io -density $PL_DENSITY
place_pins -hor_layers met3 -ver_layers met2 -random_seed 42 -min_distance 3
set_pin_length -hor_length 4 -ver_length 4
set_pin_thick_multiplier -hor_multiplier 2 -ver_multiplier 2
global_placement -density $PL_DENSITY -timing_driven -routability_driven
estimate_parasitics -placement

# repair design (buffer ports, slew, cap)
buffer_ports -inputs
buffer_ports -outputs
repair_design -verbose -slew_margin 20 -cap_margin 20
repair_tie_fanout sky130_fd_sc_hd__conb_1/LO
repair_tie_fanout sky130_fd_sc_hd__conb_1/HI

legalize
estimate_parasitics -placement
report_design_area
write_db $RESULTS/${DESIGN}_03_place.odb
