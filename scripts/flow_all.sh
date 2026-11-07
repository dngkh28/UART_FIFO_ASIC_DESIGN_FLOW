#!/usr/bin/env bash
# =====================================================================
#  flow_all.sh  -  SO TAY GO TAY: UART tu bat Docker den GDSII
#  Tac gia: Khoadang
#  PDK sky130A (sky130_fd_sc_hd, tt_025C_1v80) | clock 50 MHz (20 ns) | CTS cluster size 10
#
#  CACH DUNG: KHONG chay ca file. Copy tung khoi lenh vao terminal / vao prompt cong cu.
#    - Dong co nhan [TERMINAL]  : go o terminal (bash)
#    - Dong nam giua "[go tai <cong cu>]" ... : go tai prompt cua cong cu do
#    - Buoc 02..06 (OpenROAD) chay TRONG MOT cua so GUI duy nhat, hinh tu cap nhat sau moi buoc.
#      Cac buoc con lai (01, 01b, 07, 08, 09, 10) mo cong cu o che do dong lenh, go het roi thoat.
#    - Duong dan trong lenh cua cong cu la DUONG DAN THAT (khong dung bien).
#  Neu lo chay ca file, no chi in huong dan roi thoat (dong ngay duoi day).
#
#  Thu tu: A (Docker) -> B (bien) -> 01 synth -> 01b STA (tuy chon) -> 02..06 OpenROAD -> 07..09 Magic -> 10 Netgen -> 11 gom metrics
#  Chay lai tu buoc bat ky: moi buoc doc file ket qua cua buoc truoc trong run/results/.
#  MOI LAN CHAY nam gon trong mot thu muc: designs/uart/runs/<ten>/{results,reports}.
#  'designs/uart/run' la lien ket (symlink) toi lan chay hien tai. Lan chay moi = dat RUN moi o phan B.
#  Xem lai lan cu: ls designs/uart/runs ; ket qua nam o runs/<ten>/results va runs/<ten>/reports.
# =====================================================================
echo "flow_all.sh la SO TAY GO TAY. Hay mo file ra va copy tung khoi lenh, khong chay ca file."
return 0 2>/dev/null || exit 0


# =====================================================================
#  PHAN A : BAT DOCKER                                       [TERMINAL]
# =====================================================================
sudo systemctl start docker
docker ps                               # khong bao loi = Docker da chay
docker image ls | grep openlane2        # phai thay ghcr.io/efabless/openlane2  2.3.10


# =====================================================================
#  PHAN B : KHAI BAO BIEN (chi go o TERMINAL; mat khi dong terminal)
#  Chi dung o dong "docker run" cua tung buoc. Lenh trong cong cu dung duong dan that.
# =====================================================================
UART_DIR=~/openlane2/designs/uart
IMAGE=ghcr.io/efabless/openlane2:2.3.10
PDK_ROOT=/home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
RUN=run_$(date +%Y%m%d_%H%M)_50mhz_cts10_fix_area        # DAT TEN cho lan chay nay (doi phan sau neu muon)
mkdir -p $UART_DIR/runs/$RUN/results/extraction $UART_DIR/runs/$RUN/reports
ln -sfn runs/$RUN $UART_DIR/run                  # 'run' = lien ket toi lan chay HIEN TAI; lenh trong cac buoc dung run/results, run/reports
cd $UART_DIR
ls -l $UART_DIR/run                              # kiem tra: run -> runs/<ten lan chay>
echo $UART_DIR $IMAGE                   # kiem tra: ra duong dan day du, khong rong


# =====================================================================
#  BUOC 01 : SYNTHESIS (Yosys): RTL -> netlist cell sky130
#  Doc thu vien + RTL, dung cay phan cap, tong hop, anh xa sang cell sky130, ghi netlist.
# =====================================================================
# [TERMINAL] mo yosys tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE yosys

# [go tai yosys] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> yosys 01
read_liberty -overwrite -setattr liberty_cell -lib /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib #import cell library
read_verilog -sv /home/thu/openlane2/designs/uart/src/uart.sv /home/thu/openlane2/designs/uart/src/receiver.sv /home/thu/openlane2/designs/uart/src/transmitter.sv /home/thu/openlane2/designs/uart/src/uart_tx.sv /home/thu/openlane2/designs/uart/src/uart_rx.sv /home/thu/openlane2/designs/uart/src/FIFO.sv
hierarchy -check -top uart 	#Define top_module
proc 				#Turn always@(), if_else,case into circuit
stat 				#print design statistics
synth -top uart -flatten -run :fine #flatten module top, mux[7:0] uart($alu,$eq,$ne,$mux,$gates,$dff,$mem )
opt -full 			#optimize cell,mux,dff,port
memory_map 			#turn mem into dff
opt -full
techmap 			#turn ($alu,$eq,$ne,$mux,$gates,$dff,$mem ) into (gates)-> multiple mux 1 bit
opt -fast 			#opt fast but not deep
stat				#print design statistics
dfflibmap -liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib #map dff to sky130 (vd dfxtp_1) in standard cell library
abc -liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib -D 20000 #map logic gates to standard_cell library and optimize comb logic part; -D 20000: aim clock period
opt_clean -purge 	#clear unused cell and wire 
setundef -zero		# replace undefine value into logic 0
hilomap -singleton -hicell sky130_fd_sc_hd__conb_1 HI -locell sky130_fd_sc_hd__conb_1 LO #connect logic 1 and 0 to tie cells
splitnets 		#divide net For example : wire [3:0] t ->  wire \t[0]...wire \t[3]
insbuf -buf sky130_fd_sc_hd__buf_2 A X  #Insert buffers where wires connect directly to other wires. 
opt_clean -purge 
tee -o /home/thu/openlane2/designs/uart/run/reports/synth_area.rep stat -liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
#save in report and print area design statistics 

tee -o /home/thu/openlane2/designs/uart/run/reports/synth_cells.rep  stat # write cell statistics and print
check #check the wire connection such as no driven, multiple driven,
write_verilog -noattr -noexpr -nohex -nodec /home/thu/openlane2/designs/uart/run/results/uart_manual.nl.v
exit
#<<

# Ket qua mong doi:
#   - "Imported 428 cell types from liberty file."
#   - Sau abc: khong con cong $_AND_/$_MUX_, chi con cell sky130
#   - stat -liberty cuoi: 1078 cell (332 dfxtp_1), Chip area 13345 um^2 (lan chay run_20261106_0653)
#   - check: "Found and reported 0 problems."
#   - Kiem tra o terminal: grep -c '\$_' $UART_DIR/run/results/uart_manual.nl.v  (phai ra 0)


# =====================================================================
#  BUOC 01b : STA SAU SYNTHESIS (OpenROAD) - tuy chon
#  Phan tich thoi gian tinh (OpenSTA) tren netlist vua tong hop. Clock ly tuong, chua co day nen ket qua LAC QUAN.
# =====================================================================
# [TERMINAL] mo openroad tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE openroad -no_splash

# [go tai openroad] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> openroad 01b
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_ef_sc_hd.lef
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_verilog /home/thu/openlane2/designs/uart/run/results/uart_manual.nl.v
link_design uart ; # link netlist to cell in liberty, set uart : top module
create_clock [get_ports clk] -name clk -period 20.0 ; # Define clock clk at clk gates, period:  20 ns (50 MHz)
set clk_input [get_ports clk] ; #exclude clk from input list
set all_inputs_wo_clk [lsearch -inline -all -not -exact [all_inputs] $clk_input] ; #input list except for clk
set_input_delay 4.0 -clock [get_clocks clk] $all_inputs_wo_clk ; #set input delay 
set_output_delay 4.0 -clock [get_clocks clk] [all_outputs] ; # set out put delay
report_checks -path_delay max -format full ; #print worst timing report
report_checks -path_delay min -format full ; #print worst timing report
report_worst_slack -max
report_worst_slack -min
report_tns
write_sdc /home/thu/openlane2/designs/uart/run/results/uart_syn.sdc
write_sdf -include_typ /home/thu/openlane2/designs/uart/run/results/uart_syn.sdf
exit
#<<

# Ket qua mong doi:
#   - Setup worst slack ~ +13.5 ns, hold worst slack ~ +0.4 ns, tns 0 (so cua ban gan nhu vay)
#   - Critical path setup: tu 1 flip-flop (vd _1773_) toi cong ra rx_data_out[...]
#   - LUU Y: chua co cay clock va day -> LAC QUAN. So chinh thuc xem o buoc 06 (final_timing.rpt)
#   - Tao ra: results/uart_syn.sdc (rang buoc) va results/uart_syn.sdf (do tre CHI CUA CELL, chua co day)
#   - Ten co _syn de KHONG ghi de uart_pnr.sdc (buoc 02), uart_final.sdc va uart.sdf (buoc 06)
#   - Buoc nay tuy chon, bo qua duoc


# =====================================================================
#  BUOC 02 : FLOORPLAN (OpenROAD)
#  Nap cong nghe + netlist, tao rang buoc SDC, tao khung die, track, tap/endcap, luoi nguon.
# =====================================================================
# [TERMINAL] mo OpenROAD co GUI. CHI mo MOT LAN, dung chung cho ca buoc 02..06:
xhost +local:docker
docker run --rm -it --user 1000:1000 --network host -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -e HOME=/home/thu -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v $HOME/.Xauthority:/.Xauthority -e XAUTHORITY=/.Xauthority --security-opt seccomp=unconfined -w $UART_DIR $IMAGE openroad -gui

# Cho den khi cua so GUI hien ra. Lenh go o O "Tcl console" phia duoi cua so GUI.

# [go tai o Tcl console cua GUI] -- tung dong, xem hinh cap nhat:
#>> openroad 02
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_ef_sc_hd.lef
read_lef /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog /home/thu/openlane2/designs/uart/run/results/uart_manual.nl.v
link_design uart ; #link uart to LEF
create_clock [get_ports clk] -name clk -period 20.0
set_max_fanout 10 [current_design]
set clk_input [get_ports clk]
set all_inputs_wo_clk [lsearch -inline -all -not -exact [all_inputs] $clk_input]
set_input_delay 4.0 -clock [get_clocks clk] $all_inputs_wo_clk
set_output_delay 4.0 -clock [get_clocks clk] [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $all_inputs_wo_clk ; #Set drive resistance for input port
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $clk_input ; #Set drive resistance for clk
set_load 0.033442 [all_outputs] ; #set output load
set_clock_uncertainty 0.25 [get_clocks clk] ; # du phong 0.25 ns cho jitter/skew (setup bi tru, hold bi thac chat), setup slack- 0.25, hold slack -0.25
set_clock_transition 0.15 [get_clocks clk] ; #set slew rate
set_timing_derate -early 0.95 ; #hold_delayx0.95 : To assume worst case
set_timing_derate -late 1.05 ; #setup_delayx1.05 : To assume worst case
set_propagated_clock [all_clocks] ; # set ideal clock to propagated clock(calcutate from bufffer, wirelength)
write_sdc /home/thu/openlane2/designs/uart/run/results/uart_pnr.sdc ; #write sdc to reduce number of writing scripts timing
unset_propagated_clock [all_clocks] 
initialize_floorplan -site unithd -utilization 70 -aspect_ratio 1 -core_space "10.88 10.88 5.52 5.52"
insert_tiecells sky130_fd_sc_hd__conb_1/LO -prefix TIE_ZERO_
insert_tiecells sky130_fd_sc_hd__conb_1/HI -prefix TIE_ONE_

#set offset values
make_tracks li1 -x_offset 0.23 -x_pitch 0.46 -y_offset 0.17 -y_pitch 0.34
make_tracks met1 -x_offset 0.17 -x_pitch 0.34 -y_offset 0.17 -y_pitch 0.34
make_tracks met2 -x_offset 0.23 -x_pitch 0.46 -y_offset 0.23 -y_pitch 0.46
make_tracks met3 -x_offset 0.34 -x_pitch 0.68 -y_offset 0.34 -y_pitch 0.68
make_tracks met4 -x_offset 0.46 -x_pitch 0.92 -y_offset 0.46 -y_pitch 0.92
make_tracks met5 -x_offset 1.70 -x_pitch 3.40 -y_offset 1.70 -y_pitch 3.40
#Place tap cell, endcap ell(distance to both sides 13 side for tapcell, halo for two types)
tapcell -distance 13 -tapcell_master sky130_fd_sc_hd__tapvpwrvgnd_1 -endcap_master sky130_fd_sc_hd__decap_3 -halo_width_x 10 -halo_width_y 10
#Declare source connection rules: Supply power,gnd to source and body of pmos,nmos 
add_global_connection -net VPWR -inst_pattern .* -pin_pattern ^VPWR$ -power
add_global_connection -net VPWR -inst_pattern .* -pin_pattern ^VPB$ -power
add_global_connection -net VGND -inst_pattern .* -pin_pattern ^VGND$ -ground
add_global_connection -net VGND -inst_pattern .* -pin_pattern ^VNB$ -ground
global_connect

#Specify voltage domain : VPWR: power, VGND:ground
set_voltage_domain -name CORE -power VPWR -ground VGND

define_pdn_grid -name stdcell_grid -starts_with POWER -voltage_domain CORE -pins "met4 met5" ; #Define PDN grid ,start wire : power for CORE domain, layerlayer for source pins:met4, met5
add_pdn_stripe -grid stdcell_grid -layer met4 -width 1.6 -pitch 153.6 -offset 16.32 -spacing 1.7 -starts_with POWER -extend_to_core_ring ; # add vertical met4 power stripes: 1.6 um wide, VPWR/VGND pair repeats every 153.6 um, 1.7 um apart, first pair 16.32 um from core edge, pitch > 2 × width + spacing 
add_pdn_stripe -grid stdcell_grid -layer met5 -width 1.6 -pitch 153.18 -offset 16.65 -spacing 1.7 -starts_with POWER -extend_to_core_ring ; # add horizontal met5 power stripes: 1.6 um wide, VPWR/VGND pair repeats every 153.18 um, 1.7 um apart, first pair 16.65 um from core edge
add_pdn_connect -grid stdcell_grid -layers "met4 met5" ; # noi met4 <-> met5
add_pdn_stripe -grid stdcell_grid -layer met1 -width 0.48 -followpins -starts_with POWER ; # met1 power rails following cell row pins (VPWR/VGND alternate per row)
add_pdn_connect -grid stdcell_grid -layers "met1 met4" ; # add stacked vias at met1/met4 crossings to connect same-net met1 rails to met4 stripes 
pdngen ; #build the power grid  (met1 rails, met4/met5 stripes, vias) from the PDN config above
#########
report_design_area
set fh [open /home/thu/openlane2/designs/uart/run/reports/area_steps.rpt a]
puts $fh "buoc 02: Design area [sta::format_area [rsz::design_area] 0] u^2 [format %.0f [expr {[rsz::utilization] * 100}]]% utilization."
close $fh
write_db /home/thu/openlane2/designs/uart/run/results/uart_02_floorplan.odb
# exit   <- CHI go khi muon dong GUI (vd sau buoc 06)
#<<

# Ket qua mong doi:
#   - Added 50 rows; Inserted 100 endcaps (PHY_EDGE), 260 tapcells
#   - Design area 13345 -> 13671 u^2 (+2.4% tap/endcap). Voi -utilization 70 ra 73% (core 138 x 136 um); voi -utilization 50 thi ~52%
#   - Tao ra: results/uart_pnr.sdc va results/uart_02_floorplan.odb
#   - Them 1 dong vao reports/area_steps.rpt (nhan "buoc 02")


# =====================================================================
#  BUOC 03 : PLACEMENT (OpenROAD)
#  Dat cell, dat chan IO, sua slew/cap, chia cell vao dung hang.
# =====================================================================
# DUNG CHUNG cua so GUI cua buoc truoc (khong mo lai). Hinh se tu cap nhat sau moi buoc.

# [chi khi mo GUI MOI] go 3 dong sau o Tcl console. Neu dang o CHUNG GUI thi BO QUA
# (thiet ke VA thu vien da nam trong bo nho; read_db se bao ORD-0047).
# CANH BAO: neu van go read_liberty lan 2 trong cung GUI -> thu vien bi nap 2 lan -> CTS bao CTS-0118
# (dau hieu: [WARNING STA-1140] ... library ... already exists). Khi do phai DONG GUI va mo lai:
#>o 03
read_db /home/thu/openlane2/designs/uart/run/results/uart_02_floorplan.odb
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc /home/thu/openlane2/designs/uart/run/results/uart_pnr.sdc
#<o

# [go tai o Tcl console cua GUI] -- tung dong, xem hinh cap nhat:
#>> openroad 03
set_wire_rc -signal -layers {met1 met2 met3 met4 met5}
set_wire_rc -clock -layers {met1 met2 met3 met4 met5}
global_placement -skip_io -density 0.75
place_pins -hor_layers met3 -ver_layers met2 -random_seed 42 -min_distance 3
set_pin_length -hor_length 4 -ver_length 4
set_pin_thick_multiplier -hor_multiplier 2 -ver_multiplier 2
global_placement -density 0.75 -timing_driven -routability_driven
estimate_parasitics -placement
buffer_ports -inputs
buffer_ports -outputs
repair_design -verbose -slew_margin 20 -cap_margin 20
repair_tie_fanout sky130_fd_sc_hd__conb_1/LO
repair_tie_fanout sky130_fd_sc_hd__conb_1/HI
set_placement_padding -global -right 0 -left 0
remove_fillers
detailed_placement -max_displacement {500 100}
optimize_mirroring
check_placement -verbose
estimate_parasitics -placement
report_design_area
set fh [open /home/thu/openlane2/designs/uart/run/reports/area_steps.rpt a]
puts $fh "buoc 03: Design area [sta::format_area [rsz::design_area] 0] u^2 [format %.0f [expr {[rsz::utilization] * 100}]]% utilization."
close $fh
write_db /home/thu/openlane2/designs/uart/run/results/uart_03_place.odb
# exit   <- CHI go khi muon dong GUI (vd sau buoc 06)
#<<

# Ket qua mong doi:
#   - Cuoi cung: "Design area ... u^2 ... utilization" (lenh report_design_area). Vd 15079 u^2, 80% (+13% so voi synthesis: them buffer cong IO, sua slew/cap). Voi core 70% phai dat -density >= 0.74 (dang dung 0.75), neu khong GPL-0302
#   - Xem them: report_cell_usage (so cell va dien tich theo loai). Phai read_liberty truoc, neu khong report_design_area bao 0 u^2
#   - Tao ra: results/uart_03_place.odb
#   - Them 1 dong vao reports/area_steps.rpt (nhan "buoc 03")


# =====================================================================
#  BUOC 04 : CLOCK TREE SYNTHESIS (OpenROAD) - cluster size 10
#  Tao cay clock, sua clock net, sua setup va hold sau CTS. Tham so hien tai: sink_clustering_size 9 (size 10 tung gay 3 loi max fanout 11 tren leaf buffer).
# =====================================================================
# DUNG CHUNG cua so GUI cua buoc truoc (khong mo lai). Hinh se tu cap nhat sau moi buoc.

# [chi khi mo GUI MOI] go 3 dong sau o Tcl console. Neu dang o CHUNG GUI thi BO QUA
# (thiet ke VA thu vien da nam trong bo nho; read_db se bao ORD-0047).
# CANH BAO: neu van go read_liberty lan 2 trong cung GUI -> thu vien bi nap 2 lan -> CTS bao CTS-0118
# (dau hieu: [WARNING STA-1140] ... library ... already exists). Khi do phai DONG GUI va mo lai:
#>o 04
read_db /home/thu/openlane2/designs/uart/run/results/uart_03_place.odb
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc /home/thu/openlane2/designs/uart/run/results/uart_pnr.sdc
#<o

# [go tai o Tcl console cua GUI] -- tung dong, xem hinh cap nhat:
#>> openroad 04
set_wire_rc -signal -layers {met1 met2 met3 met4 met5}
set_wire_rc -clock -layers {met1 met2 met3 met4 met5}
estimate_parasitics -placement
repair_clock_inverters
configure_cts_characterization
clock_tree_synthesis -buf_list {sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_2} -root_buf sky130_fd_sc_hd__clkbuf_16 -sink_clustering_size 9 -sink_clustering_max_diameter 50 -sink_clustering_enable
set_propagated_clock [all_clocks]
estimate_parasitics -placement
repair_clock_nets -max_wire_length 0
estimate_parasitics -placement
set_placement_padding -global -right 0 -left 0
remove_fillers
detailed_placement -max_displacement {500 100}
optimize_mirroring
check_placement -verbose
estimate_parasitics -placement
report_cts
repair_timing -verbose -setup -setup_margin 0.05 -max_buffer_percent 50
repair_timing -verbose -hold -setup_margin 0.05 -hold_margin 0.1 -max_buffer_percent 50
set_placement_padding -global -right 0 -left 0
remove_fillers
detailed_placement -max_displacement {500 100}
optimize_mirroring
check_placement -verbose
estimate_parasitics -placement
write_db /home/thu/openlane2/designs/uart/run/results/uart_04_cts.odb
# exit   <- CHI go khi muon dong GUI (vd sau buoc 06)
#<<

# Ket qua mong doi:
#   - CTS-0019: "Total number of sinks after clustering" ~37 (cluster 9, 332 flip-flop)
#   - Leaf buffers: 37 (clkbuf_leaf_*_clk trong uart.def), khong con loi max fanout
#   - Tao ra: results/uart_04_cts.odb
#   - LUU Y: chay clock_tree_synthesis 2 lan trong cung 1 phien se loi CTS-0065 -> thoat (exit) va mo phien moi


# =====================================================================
#  BUOC 05 : ROUTING (OpenROAD)
#  Di day toan cuc, kiem tra va sua antenna, di day chi tiet. Buoc lau nhat (~2-3 phut).
# =====================================================================
# DUNG CHUNG cua so GUI cua buoc truoc (khong mo lai). Hinh se tu cap nhat sau moi buoc.

# [chi khi mo GUI MOI] go 3 dong sau o Tcl console. Neu dang o CHUNG GUI thi BO QUA
# (thiet ke VA thu vien da nam trong bo nho; read_db se bao ORD-0047).
# CANH BAO: neu van go read_liberty lan 2 trong cung GUI -> thu vien bi nap 2 lan -> CTS bao CTS-0118
# (dau hieu: [WARNING STA-1140] ... library ... already exists). Khi do phai DONG GUI va mo lai:
#>o 05
read_db /home/thu/openlane2/designs/uart/run/results/uart_04_cts.odb
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc /home/thu/openlane2/designs/uart/run/results/uart_pnr.sdc
#<o

# [go tai o Tcl console cua GUI] -- tung dong, xem hinh cap nhat:
#>> openroad 05
set_propagated_clock [all_clocks]
set_wire_rc -signal -layers {met1 met2 met3 met4 met5}
set_wire_rc -clock -layers {met1 met2 met3 met4 met5}
set_routing_layers -signal met1-met5 -clock met1-met5
set_global_routing_layer_adjustment * 0.3
set_global_routing_layer_adjustment li1 0.99
global_route -congestion_iterations 50 -verbose
check_antennas -verbose
estimate_parasitics -global_routing
repair_antennas sky130_fd_sc_hd__diode_2
check_placement -verbose
detailed_route -bottom_routing_layer met1 -top_routing_layer met5 -output_drc /home/thu/openlane2/designs/uart/run/reports/uart.drc -droute_end_iter 64 -or_seed 42 -verbose 1
write_db /home/thu/openlane2/designs/uart/run/results/uart_05_route.odb
# exit   <- CHI go khi muon dong GUI (vd sau buoc 06)
#<<

# Ket qua mong doi:
#   - Cuoi detailed_route: "Number of violations = 0"
#   - Tao ra: results/uart_05_route.odb, reports/uart.drc


# =====================================================================
#  BUOC 06 : HOAN THIEN (OpenROAD): filler, bao cao, ghi DEF
#  Chen filler, noi nguon cho filler, bao cao timing/power/area, ghi DEF va netlist co chan nguon.
# =====================================================================
# DUNG CHUNG cua so GUI cua buoc truoc (khong mo lai). Hinh se tu cap nhat sau moi buoc.

# [chi khi mo GUI MOI] go 3 dong sau o Tcl console. Neu dang o CHUNG GUI thi BO QUA
# (thiet ke VA thu vien da nam trong bo nho; read_db se bao ORD-0047).
# CANH BAO: neu van go read_liberty lan 2 trong cung GUI -> thu vien bi nap 2 lan -> CTS bao CTS-0118
# (dau hieu: [WARNING STA-1140] ... library ... already exists). Khi do phai DONG GUI va mo lai:
#>o 06
read_db /home/thu/openlane2/designs/uart/run/results/uart_05_route.odb
read_liberty /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_sdc /home/thu/openlane2/designs/uart/run/results/uart_pnr.sdc
#<o

# [go tai o Tcl console cua GUI] -- tung dong, xem hinh cap nhat:
#>> openroad 06
set_propagated_clock [all_clocks]
set_wire_rc -signal -layers {met1 met2 met3 met4 met5}
set_wire_rc -clock -layers {met1 met2 met3 met4 met5}
filler_placement {sky130_ef_sc_hd__decap_12 sky130_fd_sc_hd__decap_8 sky130_fd_sc_hd__decap_6 sky130_fd_sc_hd__decap_4 sky130_fd_sc_hd__decap_3 sky130_fd_sc_hd__fill*}
add_global_connection -net VPWR -inst_pattern .* -pin_pattern ^VPWR$ -power
add_global_connection -net VPWR -inst_pattern .* -pin_pattern ^VPB$ -power
add_global_connection -net VGND -inst_pattern .* -pin_pattern ^VGND$ -ground
add_global_connection -net VGND -inst_pattern .* -pin_pattern ^VNB$ -ground
global_connect
check_placement -verbose
estimate_parasitics -placement
report_design_area
report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins}
report_checks -path_delay min -format full_clock_expanded
report_worst_slack -max
report_worst_slack -min
report_tns
report_check_types -max_fanout -max_slew -max_capacitance -violators
report_power
sta::redirect_file_begin /home/thu/openlane2/designs/uart/run/reports/final_timing.rpt
report_checks -path_delay max -format full_clock_expanded -fields {slew cap input_pins}
report_checks -path_delay min -format full_clock_expanded
report_worst_slack -max
report_worst_slack -min
report_tns
report_check_types -max_fanout -max_slew -max_capacitance -violators
sta::redirect_file_end
sta::redirect_file_begin /home/thu/openlane2/designs/uart/run/reports/final_power.rpt
report_power
sta::redirect_file_end
set fh [open /home/thu/openlane2/designs/uart/run/reports/final_area.rpt w]
puts $fh "Design area [sta::format_area [rsz::design_area] 0] u^2 [format %.0f [expr {[rsz::utilization] * 100}]]% utilization."
close $fh
set blk [ord::get_db_block]
set tot 0
foreach net [$blk getNets] {
    if {[$net getSigType] ne "SIGNAL" && [$net getSigType] ne "CLOCK"} continue
    set w [$net getWire]
    if {$w eq "NULL"} continue
    incr tot [$w getLength]
}
set fh [open /home/thu/openlane2/designs/uart/run/reports/route_wirelength.rpt w]
puts $fh [format "%.0f" [expr {$tot / double([$blk getDbUnitsPerMicron])}]]
close $fh
set fh [open /home/thu/openlane2/designs/uart/run/reports/area_steps.rpt a]
puts $fh "buoc 06: Design area [sta::format_area [rsz::design_area] 0] u^2 [format %.0f [expr {[rsz::utilization] * 100}]]% utilization."
close $fh
write_db /home/thu/openlane2/designs/uart/run/results/uart.odb
write_def /home/thu/openlane2/designs/uart/run/results/uart.def
write_verilog /home/thu/openlane2/designs/uart/run/results/uart.pnl.v
write_verilog -include_pwr_gnd /home/thu/openlane2/designs/uart/run/results/uart.pwr.v
write_sdc /home/thu/openlane2/designs/uart/run/results/uart_final.sdc
write_sdf -include_typ /home/thu/openlane2/designs/uart/run/results/uart.sdf
# exit   <- CHI go khi muon dong GUI (vd sau buoc 06)
#<<

# Ket qua mong doi:
#   - "worst slack" setup va hold deu duong. Vd setup +13.05 ns, hold +0.12 ns, tns 0, max fanout/slew/cap violation = 0
#   - Tao ra: results/uart.def, uart.pwr.v, uart.sdf, reports/final_timing.rpt, final_power.rpt, final_area.rpt (1 dong: Design area ... u^2 ... utilization), route_wirelength.rpt (tong chieu dai day, um)
#   - Them 1 dong vao reports/area_steps.rpt (nhan "buoc 06"); file nay NOI THEM moi lan chay, muon so sanh sach thi xoa/doi ten truoc khi chay lai
#   - uart.sdf: do tre (min:typ:max) tung cell/day de mo phong gate-level; dung RC UOC LUONG (estimate_parasitics), chua trich RC that


# =====================================================================
#  BUOC 07 : GDSII (Magic): DEF -> uart.gds
#  Doc LEF + GDS cua cell + DEF cua thiet ke, ghi ra GDSII.
# =====================================================================
# [TERMINAL] mo magic tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc

# [go tai magic] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> magic 07
drc off
gds readonly true
gds rescale false
tech unlock *
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_ef_sc_hd.lef
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
gds read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds
def read /home/thu/openlane2/designs/uart/run/results/uart.def
load uart
select top cell
gds write /home/thu/openlane2/designs/uart/run/results/uart.gds
quit -noprompt
#<<

# Ket qua mong doi:
#   - Tao ra: results/uart.gds (~4.4 MB)


# =====================================================================
#  BUOC 08 : DRC (Magic)
#  Kiem tra luat thiet ke tren GDSII.
# =====================================================================
# [TERMINAL] mo magic tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc

# [go tai magic] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> magic 08
gds read /home/thu/openlane2/designs/uart/run/results/uart.gds
load uart
select top cell
drc euclidean on
drc style drc(full)
drc check
drc catchup
set why [drc listall why]
puts "So luat bi vi pham: [expr {[llength $why] / 2}]"
set total 0
foreach {rule boxes} $why { incr total [llength $boxes] }
set fh [open /home/thu/openlane2/designs/uart/run/reports/drc_magic.rpt w]
puts $fh "DRC total violation boxes: $total"
close $fh
quit -noprompt
#<<

# Ket qua mong doi:
#   - "No errors found." va "So luat bi vi pham: 0"
#   - Tao ra: reports/drc_magic.rpt ("DRC total violation boxes: 0")


# =====================================================================
#  BUOC 09 : TRICH SPICE (Magic) cho LVS
#  Trich netlist SPICE tu layout (doc tu DEF + LEF).
# =====================================================================
# [TERMINAL] mo magic tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc

# [go tai magic] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> magic 09
tech unlock *
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_ef_sc_hd.lef
lef read /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
def read /home/thu/openlane2/designs/uart/run/results/uart.def
load uart -dereference
cd /home/thu/openlane2/designs/uart/run/results/extraction
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract
ext2spice lvs
ext2spice -o /home/thu/openlane2/designs/uart/run/results/uart.spice uart.ext
quit -noprompt
#<<

# Ket qua mong doi:
#   - Tao ra: results/uart.spice (~186 KB)


# =====================================================================
#  BUOC 10 : LVS (Netgen)
#  So netlist trich tu layout voi netlist Verilog co chan nguon; cell SPICE nap ben phia Verilog.
# =====================================================================
# [TERMINAL] mo netgen tuong tac:
docker run --rm -it --user 1000:1000 -v /home/thu:/home/thu -e PDK_ROOT=$PDK_ROOT -w $UART_DIR $IMAGE netgen -noconsole

# [go tai netgen] -- tung dong mot, xem ket qua roi moi sang dong sau:
#>> netgen 10
set circuit1 [readnet spice /home/thu/openlane2/designs/uart/run/results/uart.spice]
set circuit2 [readnet verilog /dev/null]
readnet spice /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_ef_sc_hd__decap_12.spice $circuit2
readnet spice /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_ef_sc_hd__fill_12.spice $circuit2
readnet spice /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_ef_sc_hd__fill_4.spice $circuit2
readnet spice /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_ef_sc_hd__fill_8.spice $circuit2
readnet spice /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice $circuit2
readnet verilog /home/thu/openlane2/designs/uart/run/results/uart.pwr.v $circuit2
lvs "$circuit1 uart" "$circuit2 uart" /home/thu/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.tech/netgen/sky130A_setup.tcl /home/thu/openlane2/designs/uart/run/reports/lvs_netgen.rpt -blackbox
quit
#<<

# Ket qua mong doi:
#   - Cuoi: "Circuits match uniquely." (1244 device, 1250 net o ca hai phia)
#   - Neu "do not match": mo reports/lvs_netgen.rpt xem net/device lech


# =====================================================================
#  BUOC 11 : GOM SO LIEU THANH metrics.csv (terminal, khong can Docker)
#  Doc DEF + cac bao cao (area, timing, power, DRC, LVS) va ghi results/metrics.csv dang "Metric,Value" nhu OpenLane.
# =====================================================================
# [TERMINAL] go:
python3 $UART_DIR/scripts/make_metrics.py
cat $UART_DIR/run/results/metrics.csv

# Ket qua mong doi:
#   - In ra: da ghi .../results/metrics.csv (~30 chi so)
#   - Chi so chinh: design__instance__area, design__die__area, route__wirelength, timing__setup__ws, timing__hold__ws, power__total, magic__drc_error__count, design__lvs_error__count
#   - File nao thieu (chua chay buoc tuong ung) thi script in "luu y: thieu file ..." va bo qua dong do
#   - Doi chieu voi metrics.csv that cua OpenLane (run base_new): die/core/instance/flip-flop/fill/tap/hold buffer KHOP CHINH XAC; route__wirelength lech ~0.02%
