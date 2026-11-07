# 07_gds.tcl (Magic) : DEF -> GDSII stream out. Run with run_step.sh (selects magic by number 07)
set DESIGN $::env(DESIGN_NAME)
set PDK_ROOT $::env(PDK_ROOT)
set SCL "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"
drc off
gds readonly true
gds rescale false
tech unlock *
lef read $SCL/techlef/sky130_fd_sc_hd__nom.tlef
lef read $SCL/lef/sky130_ef_sc_hd.lef
lef read $SCL/lef/sky130_fd_sc_hd.lef
gds read $SCL/gds/sky130_fd_sc_hd.gds
def read ../results/${DESIGN}.def
load $DESIGN
select top cell
gds write ../results/${DESIGN}.gds
puts "GDS written: ../results/${DESIGN}.gds"
quit -noprompt
