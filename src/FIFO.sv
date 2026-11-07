module FIFO(clk, rst, ff_in, we, re, ff_out, full, empty);

input  logic       clk;
input  logic       rst;
input  logic [7:0] ff_in;
input  logic       we;
input  logic       re;
output logic [7:0] ff_out;
output logic       full;
output logic       empty;
logic [7:0] mem [16];
logic [4:0] wr_ptr, rd_ptr;   // 5 bit: 4 bit địa chỉ + 1 bit vòng

  always_ff @(posedge clk) begin
    if (rst) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
    end else begin
      if (we && !full) begin
        mem[wr_ptr[3:0]] <= ff_in;
        wr_ptr           <= wr_ptr + 1;
      end
      if (re && !empty)
        rd_ptr <= rd_ptr + 1;
    end
  end
  assign ff_out = mem[rd_ptr[3:0]];
  assign empty  = (wr_ptr == rd_ptr);
  assign full   = (wr_ptr[4] != rd_ptr[4]) &&
                  (wr_ptr[3:0] == rd_ptr[3:0]);
endmodule



