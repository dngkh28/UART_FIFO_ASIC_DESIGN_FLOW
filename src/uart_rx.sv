module uart_rx(clk, rst, rx, rx_data_out, rx_done);

parameter clk_freq = 50000000; // Hz
parameter baud_rate = 115200;   // bit/s

input  logic       clk;
input  logic       rst;
input  logic       rx;           // chan rx tho, chua dong bo
output logic [7:0] rx_data_out;
output logic       rx_done;      // xung 1 chu ky khi nhan xong 1 byte

localparam clock_divide = clk_freq / baud_rate;
localparam CNT_W        = $clog2(clock_divide);

enum logic [2:0] {
  rx_IDLE  = 3'b000,
  rx_START = 3'b001,
  rx_DATA  = 3'b010,
  rx_STOP  = 3'b011,
  rx_DONE  = 3'b100
} rx_STATE, rx_NEXT;

logic [CNT_W-1:0] clk_div_reg,   clk_div_next;
logic [7:0]       rx_data_reg,   rx_data_next;
logic [2:0]       index_bit_reg, index_bit_next;

// ---------------------------------------------------------------
// Dong bo 2-FF: chi rx_ff1 doc rx tho, FSM chi doc rx_sync.
// Reset ve 1 vi duong rx ranh o muc 1.
// ---------------------------------------------------------------
logic rx_ff1, rx_sync;

always_ff @(posedge clk) begin
  if (rst) begin
    rx_ff1  <= 1'b1;
    rx_sync <= 1'b1;
  end else begin
    rx_ff1  <= rx;
    rx_sync <= rx_ff1;
  end
end

// ---------------------------------------------------------------
// Thanh ghi trang thai
// ---------------------------------------------------------------
always_ff @(posedge clk) begin
  if (rst) begin
    rx_STATE      <= rx_IDLE;
    clk_div_reg   <= '0;
    rx_data_reg   <= '0;
    index_bit_reg <= '0;
  end else begin
    rx_STATE      <= rx_NEXT;
    clk_div_reg   <= clk_div_next;
    rx_data_reg   <= rx_data_next;
    index_bit_reg <= index_bit_next;
  end
end

// ---------------------------------------------------------------
// Logic chuyen trang thai (to hop)
// ---------------------------------------------------------------
always_comb begin
  rx_NEXT        = rx_STATE;
  clk_div_next   = clk_div_reg;
  rx_data_next   = rx_data_reg;
  index_bit_next = index_bit_reg;

  case (rx_STATE)
    // Cho canh xuong cua start bit
    rx_IDLE: begin
      clk_div_next   = '0;
      index_bit_next = '0;
      if (rx_sync == 1'b0)
        rx_NEXT = rx_START;
    end

    // Den giua start bit, kiem tra lai rx van bang 0 de loc nhieu
    rx_START: begin
      if (clk_div_reg == (clock_divide - 1) / 2) begin
        clk_div_next = '0;
        if (rx_sync == 1'b0)
          rx_NEXT = rx_DATA;
        else
          rx_NEXT = rx_IDLE;
      end else begin
        clk_div_next = clk_div_reg + 1'b1;
      end
    end

    // Lay mau 8 bit o giua moi bit, LSB truoc
    rx_DATA: begin
      if (clk_div_reg < clock_divide - 1) begin
        clk_div_next = clk_div_reg + 1'b1;
      end else begin
        clk_div_next                = '0;
        rx_data_next[index_bit_reg] = rx_sync;
        if (index_bit_reg < 3'd7) begin
          index_bit_next = index_bit_reg + 1'b1;
        end else begin
          index_bit_next = '0;
          rx_NEXT        = rx_STOP;
        end
      end
    end

    // Cho het stop bit
    rx_STOP: begin
      if (clk_div_reg < clock_divide - 1) begin
        clk_div_next = clk_div_reg + 1'b1;
      end else begin
        clk_div_next = '0;
        rx_NEXT      = rx_DONE;
      end
    end

    // Phat xung rx_done trong 1 chu ky
    rx_DONE: begin
      rx_NEXT = rx_IDLE;
    end

    default: rx_NEXT = rx_IDLE;
  endcase
end

assign rx_data_out = rx_data_reg;
assign rx_done     = (rx_STATE == rx_DONE);

endmodule