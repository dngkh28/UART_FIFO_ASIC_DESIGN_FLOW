###############################################################################
# Created by write_sdc
# Tue Nov  3 08:28:40 2026
###############################################################################
current_design uart
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 20.0000 [get_ports {clk}]
set_clock_transition 0.1500 [get_clocks {clk}]
set_clock_uncertainty 0.2500 clk
set_propagated_clock [get_clocks {clk}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {re}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[0]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[1]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[2]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[3]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[4]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[5]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[6]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_data_in[7]}]
set_input_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {we}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {empty_rx}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {empty_tx}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {full_rx}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {full_tx}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[0]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[1]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[2]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[3]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[4]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[5]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[6]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rx_data_out[7]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx_active}]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.0334 [get_ports {empty_rx}]
set_load -pin_load 0.0334 [get_ports {empty_tx}]
set_load -pin_load 0.0334 [get_ports {full_rx}]
set_load -pin_load 0.0334 [get_ports {full_tx}]
set_load -pin_load 0.0334 [get_ports {tx}]
set_load -pin_load 0.0334 [get_ports {tx_active}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[7]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[6]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[5]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[4]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[3]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[2]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[1]}]
set_load -pin_load 0.0334 [get_ports {rx_data_out[0]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {clk}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {re}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rst}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {rx}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {we}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[7]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[6]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[5]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[4]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[3]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[2]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[1]}]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin {Y} -input_transition_rise 0.0000 -input_transition_fall 0.0000 [get_ports {tx_data_in[0]}]
set_timing_derate -early 0.9500
set_timing_derate -late 1.0500
###############################################################################
# Design Rules
###############################################################################
set_max_fanout 10.0000 [current_design]
