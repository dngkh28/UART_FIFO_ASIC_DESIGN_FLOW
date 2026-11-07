vlog -sv FIFO.sv uart_tx.sv uart_rx.sv receiver.sv transmitter.sv uart.sv uart_tb.sv
vsim -onfinish stop uart_tb
add wave /uart_tb/clk /uart_tb/rst /uart_tb/tx /uart_tb/we /uart_tb/re
add wave -radix hex /uart_tb/tx_data_in /uart_tb/rx_data_out
add wave /uart_tb/empty_tx /uart_tb/empty_rx /uart_tb/tx_active
run -all
wave zoom full
