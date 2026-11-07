module receiver(clk,rst,rx,rx_data_out, re, full_rx, empty_rx);
parameter clk_freq = 50000000; // Hz
parameter baud_rate = 115200;   // bit/s
input logic clk;
input logic rst;
input logic rx;
input logic re;

output logic [7:0]rx_data_out;
output logic full_rx;
output logic empty_rx;
logic [7:0]data;
logic done;
logic we_wire;
logic re_wire;
logic empty_wire;
logic full_wire;
uart_rx #(.clk_freq(clk_freq), .baud_rate(baud_rate)) urx (
  .clk(clk),
  .rst(rst),
  .rx(rx),
  .rx_data_out(data),
  .rx_done(done)
);

FIFO frx(.clk(clk), 
			.rst(rst), 
			.ff_in(data), 
			.we(we_wire), 
			.re(re_wire), 
			.ff_out(rx_data_out), 
			.full(full_wire), 
			.empty(empty_wire));
assign we_wire = (!full_wire && done);
assign re_wire = re ;
assign empty_rx = empty_wire;
assign full_rx = full_wire;

endmodule