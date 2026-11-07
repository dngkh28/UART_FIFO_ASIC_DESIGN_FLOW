`timescale 1ns/1ps

module uart_tx_tb;

  // Small divider (16 clk/bit) for fast simulation.
  // For real values use 80_000_000 and 115_200.
  localparam int CLK_FREQ   = 1_600_000;
  localparam int BAUD_RATE  = 100_000;
  localparam int CLK_PERIOD = 10;                      // ns
  localparam int DIV        = CLK_FREQ / BAUD_RATE;    // clk cycles per bit
  localparam int BIT_TIME   = DIV * CLK_PERIOD;        // ns per bit
  localparam int N_BYTES    = 5;

  // Signals
  logic       clk = 0;
  logic       rst = 1;
  logic       start = 0;
  logic [7:0] tx_data_in = '0;
  logic       tx, tx_active, done_tx, tx_busy;

  // DUT
  uart_tx #(.clk_freq(CLK_FREQ), .baud_rate(BAUD_RATE)) dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .tx_data_in(tx_data_in),
    .tx(tx),
    .tx_active(tx_active),
    .done_tx(done_tx),
    .tx_busy(tx_busy)
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
  end

  int rx_count   = 0;   // bytes decoded by monitor
  int done_count = 0;   // done_tx pulses
  int errors     = 0;

  // Send one byte: wait until idle, pulse start for 1 cycle
  task automatic send_byte(input logic [7:0] b);
    wait (!tx_busy);
    @(negedge clk);
    tx_data_in = b;
    start      = 1;
    @(negedge clk);
    start      = 0;
  endtask

  // Monitor: decode the tx line, sample in the middle of each bit
  initial begin : monitor
    logic [7:0] b;
    forever begin
      @(negedge tx);                 // start bit edge
      #(BIT_TIME/2);                 // middle of start bit
      if (tx !== 1'b0) begin
        $display("[%0t] ERROR: start bit is not 0", $time);
        errors++;
      end
      for (int i = 0; i < 8; i++) begin
        #(BIT_TIME);
        b[i] = tx;                   // LSB first
      end
      #(BIT_TIME);                   // middle of stop bit
      if (tx !== 1'b1) begin
        $display("[%0t] ERROR: stop bit is not 1", $time);
        errors++;
      end
      if (rx_count < N_BYTES && b === expected[rx_count])
        $display("[%0t] OK   : byte %0d = 0x%h", $time, rx_count, b);
      else begin
        $display("[%0t] ERROR: byte %0d = 0x%h, expected 0x%h",
                 $time, rx_count, b, expected[rx_count]);
        errors++;
      end
      rx_count++;
    end
  end

  // Count done_tx pulses
  always @(posedge clk)
    if (done_tx) done_count++;

  // Main test
  initial begin
    $dumpfile("uart_tx_tb.vcd");
    $dumpvars(0, uart_tx_tb);

    // Reset
    repeat (5) @(negedge clk);
    rst = 0;
    @(negedge clk);

    // Test 1: after reset, tx idle high and not busy
    if (tx !== 1'b1 || tx_busy !== 1'b0) begin
      $display("ERROR: after reset tx = %b, tx_busy = %b", tx, tx_busy);
      errors++;
    end else
      $display("OK   : after reset tx = 1, tx_busy = 0");

    // Test 2: send first byte
    send_byte(expected[0]);

    // Test 3: start while busy must be ignored (0xEE not sent)
    #(BIT_TIME * 3);
    @(negedge clk);
    tx_data_in = 8'hEE;
    start      = 1;
    @(negedge clk);
    start      = 0;

    // Test 4: send remaining bytes back to back
    for (int i = 1; i < N_BYTES; i++)
      send_byte(expected[i]);

    // Wait for last byte to finish
    wait (!tx_busy);
    #(BIT_TIME * 2);

    // Summary
    if (rx_count != N_BYTES) begin
      $display("ERROR: received %0d bytes, expected %0d", rx_count, N_BYTES);
      errors++;
    end
    if (done_count != N_BYTES) begin
      $display("ERROR: %0d done_tx pulses, expected %0d", done_count, N_BYTES);
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