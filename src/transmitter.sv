module transmitter(clk, rst, tx_data_in, we, tx, tx_active, full_tx, empty_tx);
parameter clk_freq = 50000000; // Hz
parameter baud_rate = 115200;   // bit/s
input  logic       clk;
input  logic       rst;
input  logic [7:0] tx_data_in;
input  logic       we;
output logic       tx;
output logic       tx_active;
output logic       full_tx;
output logic       empty_tx;

logic [7:0] ff_out;
logic       start, tx_busy, done_tx;

assign start = !empty_tx && !tx_busy;   // có byte và uart rảnh

FIFO ftx (.clk(clk), 
			 .rst(rst), 
			 .ff_in(tx_data_in), 
			 .we(we),
          .re(start), 
			 .ff_out(ff_out), 
			 .full(full_tx), 
			 .empty(empty_tx));

uart_tx  #(.clk_freq(clk_freq), .baud_rate(baud_rate)) utx(.clk(clk), 
				 .rst(rst), 
				 .start(start), 
				 .tx_data_in(ff_out),
             .tx(tx), .tx_active(tx_active), 
				 .tx_busy(tx_busy),
             .done_tx(done_tx));
endmodule