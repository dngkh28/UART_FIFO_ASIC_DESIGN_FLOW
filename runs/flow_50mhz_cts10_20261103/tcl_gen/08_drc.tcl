# 08_drc.tcl (Magic) : DRC on the final GDSII. Report -> ../reports/drc_magic.rpt
set DESIGN $::env(DESIGN_NAME)
set rpt [open ../reports/drc_magic.rpt w]
gds read ../results/${DESIGN}.gds
load $DESIGN
select top cell
drc euclidean on
drc style drc(full)
drc check
drc catchup
set why [drc listall why]
set total 0
foreach {rule boxes} $why { incr total [llength $boxes] }
puts $rpt "DRC total violation boxes: $total"
puts $rpt "violation rules: [expr {[llength $why] / 2}]"
foreach {rule boxes} $why {
    puts $rpt "$rule : [llength $boxes] violation box(es)"
}
close $rpt
puts "Magic DRC finished, see ../reports/drc_magic.rpt"
quit -noprompt
