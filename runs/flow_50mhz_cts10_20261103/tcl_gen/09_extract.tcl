# 09_extract.tcl (Magic) : extract SPICE netlist from DEF/LEF layout for LVS. Output: ../results/uart.spice
set DESIGN $::env(DESIGN_NAME)
set PDK_ROOT $::env(PDK_ROOT)
set SCL "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"
tech unlock *
lef read $SCL/techlef/sky130_fd_sc_hd__nom.tlef
lef read $SCL/lef/sky130_ef_sc_hd.lef
lef read $SCL/lef/sky130_fd_sc_hd.lef
def read ../results/${DESIGN}.def
load $DESIGN -dereference
file mkdir ../results/extraction
cd ../results/extraction
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract
ext2spice lvs
ext2spice -o ../${DESIGN}.spice ${DESIGN}.ext
puts "SPICE written: ../results/${DESIGN}.spice"
quit -noprompt
