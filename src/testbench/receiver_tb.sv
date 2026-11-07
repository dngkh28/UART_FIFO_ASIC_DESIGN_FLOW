// Self-checking testbench for receiver (uart_rx + FIFO)
// Author: Phuong Dang
`timescale 1ns/1ps

module receiver_tb;

  // Small divider (16 clk/bit) for fast simulation.
  // For real values use 80_000_000 and 115_200.
  localparam int CLK_FREQ   = 1_600_000;
  localparam int BAUD_RATE  = 100_000;
  localparam int CLK_PERIOD = 10;                      // ns
  localparam int DIV        = CLK_FREQ / BAUD_RATE;    // clk cycles per bit
  localparam int BIT_TIME   = DIV * CLK_PERIOD;        // ns per bit
  localparam int DEPTH      = 16;                      // FIFO depth

  // Signals
  logic       clk = 0;
  logic       rst = 1;
  logic       rx  = 1;          // idle high
  logic       re  = 0;
  logic [7:0] rx_data_out;
  logic       full_rx, empty_rx;

  // DUT
  receiver #(.clk_freq(CLK_FREQ), .baud_rate(BAUD_RATE)) dut (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .rx_data_out(rx_data_out),
    .re(re),
    .full_rx(full_rx),
    .empty_rx(empty_rx)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  int errors = 0;

  // Test pattern: byte number i
  function automatic logic [7:0] pattern(input int i);
    return 8'(i * 13 + 7);
  endfunction

  // Drive one 8N1 frame on rx, LSB first
  task automatic send_frame(input logic [7:0] b, input int bit_ns);
    rx = 0;                          // start bit
    #(bit_ns);
    for (int i = 0; i < 8; i++) begin
      rx = b[i];
      #(bit_ns);
    end
    rx = 1;                          // stop bit
    #(bit_ns);
  endtask

  // Let the last byte reach the FIFO
  task automatic settle();
    repeat (4) @(negedge clk);
  endtask

  // Check empty_rx / full_rx
  task automatic check_flags(input string what, input logic exp_empty,
                             input logic exp_full);
    @(negedge clk);
    if (empty_rx !== exp_empty || full_rx !== exp_full) begin
      $display("[%0t] ERROR: %s: empty_rx = %b, full_rx = %b, expected %b, %b",
               $time, what, empty_rx, full_rx, exp_empty, exp_full);
      errors++;
    end else
      $display("[%0t] OK   : %s (empty_rx = %b, full_rx = %b)",
               $time, what, empty_rx, full_rx);
  endtask

  // Check the byte at the head of the FIFO, then pop it with re
  task automatic pop_check(input string what, input logic [7:0] exp);
    @(negedge clk);
    if (empty_rx !== 1'b0) begin
      $display("[%0t] ERROR: %s: FIFO is empty, expected 0x%h", $time, what, exp);
      errors++;
    end else if (rx_data_out !== exp) begin
      $display("[%0t] ERROR: %s = 0x%h, expected 0x%h", $time, what, rx_data_out, exp);
      errors++;
    end else
      $display("[%0t] OK   : %s = 0x%h", $time, what, rx_data_out);
    re = 1;
    @(negedge clk);
    re = 0;
  endtask

  // Main test
  initial begin
    $dumpfile("receiver_tb.vcd");
    $dumpvars(0, receiver_tb);

    // Reset
    repeat (5) @(negedge clk);
    rst = 0;
    #(BIT_TIME * 2);

    // Test 1: after reset the FIFO is empty
    check_flags("after reset", 1'b1, 1'b0);

    // Test 2: one byte goes into the FIFO and comes out (rx is asynchronous)
    #3;
    send_frame(8'hA5, BIT_TIME);
    settle();
    check_flags("after one byte", 1'b0, 1'b0);
    pop_check("single byte", 8'hA5);
    check_flags("after pop", 1'b1, 1'b0);

    // Test 3: five bytes back to back come out in the same order
    for (int i = 0; i < 5; i++)
      send_frame(pattern(i), BIT_TIME);
    settle();
    check_flags("after five bytes", 1'b0, 1'b0);
    for (int i = 0; i < 5; i++)
      pop_check($sformatf("order byte %0d", i), pattern(i));
    check_flags("after five pops", 1'b1, 1'b0);

    // Test 4: re while empty must be ignored (read pointer must not move)
    @(negedge clk);
    re = 1;
    repeat (3) @(negedge clk);
    re = 0;
    send_frame(8'h3C, BIT_TIME);
    settle();
    pop_check("after re while empty", 8'h3C);

    // Test 5: short glitch must not put a byte into the FIFO
    #(BIT_TIME * 2);
    rx = 0;
    #(CLK_PERIOD * 3);               // much shorter than half a bit
    rx = 1;
    #(BIT_TIME * 2);
    check_flags("after glitch", 1'b1, 1'b0);

    // Test 6: fill the FIFO, the extra byte must be dropped
    for (int i = 0; i < DEPTH; i++)
      send_frame(pattern(i), BIT_TIME);
    settle();
    check_flags("FIFO full", 1'b0, 1'b1);
    send_frame(8'hEE, BIT_TIME);     // 17th byte, must be dropped
    settle();
    check_flags("17th byte dropped", 1'b0, 1'b1);
    for (int i = 0; i < DEPTH; i++)
      pop_check($sformatf("full FIFO byte %0d", i), pattern(i));
    check_flags("FIFO drained (0xEE not stored)", 1'b1, 1'b0);

    // Test 7: pop while the next byte is being received
    send_frame(8'h11, BIT_TIME);
    settle();
    fork
      send_frame(8'h22, BIT_TIME);
      begin
        #(BIT_TIME * 4);
        pop_check("pop during receive", 8'h11);
      end
    join
    settle();
    pop_check("byte received during pop", 8'h22);
    check_flags("after read during write", 1'b1, 1'b0);

    // Test 8: reset clears the FIFO and it works again afterwards
    for (int i = 0; i < 3; i++)
      send_frame(pattern(i), BIT_TIME);
    settle();
    @(negedge clk);
    rst = 1;
    repeat (3) @(negedge clk);
    rst = 0;
    check_flags("after reset with data", 1'b1, 1'b0);
    #(BIT_TIME * 2);
    send_frame(8'h77, BIT_TIME);
    settle();
    pop_check("byte after reset", 8'h77);

    #(BIT_TIME * 2);

    // Summary
    if (errors == 0) $display("\n===== PASS =====");
    else             $display("\n===== FAIL: %0d errors =====", errors);
    $finish;
  end

  // Timeout guard
  initial begin
    #(BIT_TIME * 12 * 150);
    $display("ERROR: timeout");
    $finish;
  end

endmodule
