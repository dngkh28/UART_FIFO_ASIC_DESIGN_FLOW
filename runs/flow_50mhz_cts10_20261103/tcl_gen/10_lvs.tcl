# 10_lvs.tcl (Netgen) : LVS between extracted layout SPICE (circuit 1) and the post-PnR Verilog (circuit 2).
# Mirrors OpenLane's Netgen.LVS step: cell SPICE models are loaded on the Verilog side only, -blackbox.
set DESIGN $::env(DESIGN_NAME)
set PDK_ROOT $::env(PDK_ROOT)
set SCL   "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"
set SETUP "netgen_setup.tcl"   ;# copy of OpenLane's scripts/netgen/setup.tcl
set CELLS [list]
foreach f [lsort [glob -nocomplain $SCL/spice/sky130_ef_sc_hd__*.spice]] { lappend CELLS $f }
lappend CELLS $SCL/spice/sky130_fd_sc_hd.spice

set circuit1 [readnet spice ../results/${DESIGN}.spice]
set circuit2 [readnet verilog /dev/null]
foreach f $CELLS { readnet spice $f $circuit2 }
readnet verilog ../results/${DESIGN}.pwr.v $circuit2   ;# powered netlist (-include_pwr_gnd) = OpenLane "pnl.v"
lvs "$circuit1 $DESIGN" "$circuit2 $DESIGN" $SETUP ../reports/lvs_netgen.rpt -blackbox -json
