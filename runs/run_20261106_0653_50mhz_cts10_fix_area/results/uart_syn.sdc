###############################################################################
# Created by write_sdc
# Fri Nov  6 00:01:09 2026
###############################################################################
current_design uart
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 20.0000 [get_ports {clk}]
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
###############################################################################
# Design Rules
###############################################################################
