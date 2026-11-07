// Self-checking testbench for uart_rx
// Author: Khoa
`timescale 1ns/1ps

module uart_rx_tb;

  // Small divider (16 clk/bit) for fast simulation.
  // For real values use 80_000_000 and 115_200.
  localparam int CLK_FREQ   = 1_600_000;
  localparam int BAUD_RATE  = 100_000;
  localparam int CLK_PERIOD = 10;                      // ns
  localparam int DIV        = CLK_FREQ / BAUD_RATE;    // clk cycles per bit
  localparam int BIT_TIME   = DIV * CLK_PERIOD;        // ns per bit
  localparam int N_BYTES    = 6;

  // Signals
  logic       clk = 0;
  logic       rst = 1;
  logic       rx  = 1;          // idle high
  logic [7:0] rx_data_out;
  logic       rx_done;

  // DUT
  uart_rx #(.clk_freq(CLK_FREQ), .baud_rate(BAUD_RATE)) dut (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .rx_data_out(rx_data_out),
    .rx_done(rx_done)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  // Expected bytes
  logic [7:0] expected [N_BYTES];
  initial begin
    expected[0] = 8'hA5;
    expected[1] = 8'h3C;
    expected[2] = 8'h00;
    expected[3] = 8'hFF;
    expected[4] = 8'h81;
    expected[5] = 8'h5A;
  end

  int rx_count = 0;   // rx_done pulses seen
  int errors   = 0;

  // Drive one 8N1 frame on rx, LSB first.
  // bit_ns lets us test a slightly wrong baud rate.
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

  // Checker: compare data on every rx_done pulse
  always @(posedge clk) begin
    if (rx_done) begin
      if (rx_count < N_BYTES && rx_data_out === expected[rx_count])
        $display("[%0t] OK   : byte %0d = 0x%h", $time, rx_count, rx_data_out);
      else begin
        $display("[%0t] ERROR: byte %0d = 0x%h, expected 0x%h",
                 $time, rx_count, rx_data_out, expected[rx_count]);
        errors++;
      end
      rx_count++;
    end
  end

  // Main test
  initial begin
    $dumpfile("uart_rx_tb.vcd");
    $dumpvars(0, uart_rx_tb);

    // Reset
    repeat (5) @(negedge clk);
    rst = 0;
    #(BIT_TIME * 2);

    // Test 1: no rx_done while line is idle
    if (rx_count != 0) begin
      $display("ERROR: rx_done while idle");
      errors++;
    end else
      $display("OK   : no rx_done while idle");

    // Test 2: start edge not aligned to clk (rx is asynchronous)
    #3;
    send_frame(expected[0], BIT_TIME);

    // Test 3: back-to-back frames, no idle gap
    send_frame(expected[1], BIT_TIME);
    send_frame(expected[2], BIT_TIME);
    send_frame(expected[3], BIT_TIME);

    // Test 4: short glitch must be ignored (no byte)
    #(BIT_TIME * 2);
    rx = 0;
    #(CLK_PERIOD * 3);               // much shorter than half a bit
    rx = 1;
    #(BIT_TIME * 2);
    if (rx_count != 4) begin
      $display("ERROR: glitch was received as a byte");
      errors++;
    end else
      $display("OK   : glitch ignored");

    // Test 5: sender 3% slower than expected
    send_frame(expected[4], BIT_TIME * 103 / 100);

    // Test 6: sender 3% faster than expected
    send_frame(expected[5], BIT_TIME * 97 / 100);

    #(BIT_TIME * 2);

    // Summary
    if (rx_count != N_BYTES) begin
      $display("ERROR: received %0d bytes, expected %0d", rx_count, N_BYTES);
      errors++;
    end

    if (errors == 0) $display("\n===== PASS =====");
    else             $display("\n===== FAIL: %0d errors =====", errors);
    $finish;
  end

  // Timeout guard
  initial begin
    #(BIT_TIME * 12 * (N_BYTES + 5));
    $display("ERROR: timeout");
    $finish;
  end

endmodule