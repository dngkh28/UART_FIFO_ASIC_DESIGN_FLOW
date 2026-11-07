module uart(clk,rst,rx,tx,tx_data_in,rx_data_out,we,re,tx_active, full_rx, empty_rx, full_tx, empty_tx);
parameter clk_freq = 50000000; //MHz
parameter baud_rate = 115200; //bits per second

input logic clk;
input logic rst;
input logic rx;
input logic [7:0] tx_data_in;
input logic we,re;
output logic tx;
output logic [7:0] rx_data_out;
output logic tx_active;
output logic full_tx, full_rx;
output logic empty_rx,empty_tx;
	
receiver #(.clk_freq(clk_freq),
			  .baud_rate(baud_rate))
		 rec(.clk(clk),
			  .rst(rst),
			  .rx(rx),
			  .rx_data_out(rx_data_out),
			  .re(re),
			  .full_rx(full_rx),
			  .empty_rx(empty_rx));
transmitter #(.clk_freq(clk_freq),
				  .baud_rate(baud_rate))				  
      trans	( .clk(clk), 
				  .rst(rst), 
				  .tx_data_in(tx_data_in), 
				  .we(we), 
				  .tx(tx), 
				  .tx_active(tx_active), 
				  .full_tx(full_tx), 
				  .empty_tx(empty_tx));

endmodule

