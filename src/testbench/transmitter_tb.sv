// Self-checking testbench for transmitter (FIFO + uart_tx)
// Author: Phuong Dang
`timescale 1ns/1ps

module transmitter_tb;

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
  logic [7:0] tx_data_in = '0;
  logic       we = 0;
  logic       tx, tx_active, full_tx, empty_tx;

  // DUT
  transmitter #(.clk_freq(CLK_FREQ), .baud_rate(BAUD_RATE)) dut (
    .clk(clk),
    .rst(rst),
    .tx_data_in(tx_data_in),
    .we(we),
    .tx(tx),
    .tx_active(tx_active),
    .full_tx(full_tx),
    .empty_tx(empty_tx)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  logic [7:0] exp_q [$];      // bytes accepted by the FIFO, in order
  int  rx_count   = 0;        // frames decoded by monitor
  int  errors     = 0;
  logic mon_ignore = 0;       // 1 while a frame is cut by reset

  // Scoreboard: remember every byte the FIFO accepts (not written when full)
  always @(posedge clk)
    if (we && !full_tx && !rst) exp_q.push_back(tx_data_in);

  // Write one byte into the FIFO (we is high for 1 cycle)
  task automatic write_byte(input logic [7:0] b);
    @(negedge clk);
    tx_data_in = b;
    we         = 1;
    @(negedge clk);
    we         = 0;
  endtask

  // Write n bytes on consecutive clock cycles
  task automatic write_burst(input int n, input logic [7:0] base);
    @(negedge clk);
    for (int i = 0; i < n; i++) begin
      tx_data_in = base + 8'(i * 13);
      we         = 1;
      @(negedge clk);
    end
    we = 0;
  endtask

  // Wait until the monitor has decoded every accepted byte
  task automatic drain();
    wait (exp_q.size() == 0);
    #(BIT_TIME * 2);
  endtask

  // Check empty_tx / full_tx / tx
  task automatic check_state(input string what, input logic exp_empty,
                             input logic exp_full);
    @(negedge clk);
    if (empty_tx !== exp_empty || full_tx !== exp_full || tx !== 1'b1) begin
      $display("[%0t] ERROR: %s: empty_tx = %b, full_tx = %b, tx = %b, expected %b, %b, 1",
               $time, what, empty_tx, full_tx, tx, exp_empty, exp_full);
      errors++;
    end else
      $display("[%0t] OK   : %s (empty_tx = %b, full_tx = %b, tx = 1)",
               $time, what, empty_tx, full_tx);
  endtask

  // Monitor: decode the tx line, sample in the middle of each bit
  initial begin : monitor
    logic [7:0] b, e;
    forever begin
      @(negedge tx);                 // start bit edge
      #(BIT_TIME/2);                 // middle of start bit
      if (!mon_ignore && (tx !== 1'b0 || tx_active !== 1'b0)) begin
        $display("[%0t] ERROR: start bit: tx = %b, tx_active = %b", $time, tx, tx_active);
        errors++;
      end
      for (int i = 0; i < 8; i++) begin
        #(BIT_TIME);
        b[i] = tx;                   // LSB first
        if (!mon_ignore && tx_active !== 1'b1) begin
          $display("[%0t] ERROR: tx_active is 0 in data bit %0d", $time, i);
          errors++;
        end
      end
      #(BIT_TIME);                   // middle of stop bit
      if (!mon_ignore && (tx !== 1'b1 || tx_active !== 1'b0)) begin
        $display("[%0t] ERROR: stop bit: tx = %b, tx_active = %b", $time, tx, tx_active);
        errors++;
      end
      if (!mon_ignore) begin
        if (exp_q.size() == 0) begin
          $display("[%0t] ERROR: unexpected frame 0x%h", $time, b);
          errors++;
        end else begin
          e = exp_q.pop_front();
          if (b === e)
            $display("[%0t] OK   : frame %0d = 0x%h", $time, rx_count, b);
          else begin
            $display("[%0t] ERROR: frame %0d = 0x%h, expected 0x%h", $time, rx_count, b, e);
            errors++;
          end
        end
      end
      rx_count++;
    end
  end

  // Main test
  initial begin
    int n0;

    $dumpfile("transmitter_tb.vcd");
    $dumpvars(0, transmitter_tb);

    // Reset: tx must be high even during reset
    repeat (5) @(negedge clk);
    if (tx !== 1'b1) begin
      $display("ERROR: tx = %b during reset, expected 1", tx);
      errors++;
    end
    rst = 0;

    // Test 1: after reset the FIFO is empty and the line is idle
    check_state("after reset", 1'b1, 1'b0);
    if (tx_active !== 1'b0) begin
      $display("ERROR: tx_active = %b when idle", tx_active);
      errors++;
    end

    // Test 2: one byte written, sent automatically
    write_byte(8'hA5);
    drain();
    check_state("after one byte", 1'b1, 1'b0);

    // Test 3: four bytes written on consecutive cycles, sent in order
    write_burst(4, 8'h41);
    drain();
    check_state("after four bytes", 1'b1, 1'b0);

    // Test 4: fill the FIFO. The first byte leaves the FIFO as soon as
    // uart_tx starts, so DEPTH + 1 bytes are accepted and the next is dropped.
    write_burst(DEPTH + 2, 8'h10);
    if (exp_q.size() != DEPTH + 1) begin
      $display("ERROR: FIFO accepted %0d bytes, expected %0d", exp_q.size(), DEPTH + 1);
      errors++;
    end else
      $display("OK   : FIFO accepted %0d bytes, extra byte dropped", exp_q.size());
    if (full_tx !== 1'b1) begin
      $display("ERROR: full_tx = %b after burst, expected 1", full_tx);
      errors++;
    end else
      $display("OK   : full_tx = 1 after burst");
    drain();
    n0 = rx_count;
    #(BIT_TIME * 25);                // the dropped byte must not be sent
    if (rx_count != n0) begin
      $display("ERROR: extra frame sent after the FIFO drained");
      errors++;
    end else
      $display("OK   : no frame for the dropped byte");
    check_state("after full FIFO drained", 1'b1, 1'b0);

    // Test 5: reset in the middle of a frame clears the FIFO and the line
    write_burst(5, 8'h60);
    #(BIT_TIME * 4);
    mon_ignore = 1;                  // monitor sees a cut frame, do not check
    @(negedge clk);
    rst = 1;
    repeat (3) @(negedge clk);
    exp_q.delete();
    rst = 0;
    check_state("after reset with data", 1'b1, 1'b0);
    #(BIT_TIME * 14);                // monitor finishes the cut frame
    n0 = rx_count;
    #(BIT_TIME * 25);                // no queued byte may be sent
    if (rx_count != n0) begin
      $display("ERROR: frame sent after reset, FIFO was not cleared");
      errors++;
    end else
      $display("OK   : no frame after reset");
    mon_ignore = 0;

    // Test 6: works again after reset
    write_byte(8'hC3);
    drain();
    check_state("after reset and one byte", 1'b1, 1'b0);

    // Summary
    if (errors == 0) $display("\n===== PASS =====");
    else             $display("\n===== FAIL: %0d errors =====", errors);
    $finish;
  end

  // Timeout guard
  initial begin
    #(BIT_TIME * 12 * 300);
    $display("ERROR: timeout");
    $finish;
  end

endmodule
