// Self-checking testbench for FIFO (16 x 8 bit, 5-bit pointers)
// Author: Phuong Dang
`timescale 1ns/1ps

module FIFO_tb;

  localparam int CLK_PERIOD = 10;                      // ns
  localparam int DEPTH      = 16;
  localparam int N_RANDOM   = 3000;                    // random cycles

  // Signals
  logic       clk = 0;
  logic       rst = 1;
  logic [7:0] ff_in = '0;
  logic       we = 0;
  logic       re = 0;
  logic [7:0] ff_out;
  logic       full, empty;

  // DUT
  FIFO dut (
    .clk(clk),
    .rst(rst),
    .ff_in(ff_in),
    .we(we),
    .re(re),
    .ff_out(ff_out),
    .full(full),
    .empty(empty)
  );

  always #(CLK_PERIOD/2) clk = ~clk;

  int errors = 0;
  int checks = 0;

  // Test pattern: byte number i
  function automatic logic [7:0] pattern(input int i);
    return 8'(i * 13 + 7);
  endfunction

  // ---------------------------------------------------------------
  // Reference model: a queue that follows the same rules as the FIFO.
  // A write is accepted when not full, a read when not empty, both
  // decided from the state before the clock edge.
  // ---------------------------------------------------------------
  logic [7:0] model [$];
  logic       checking = 0;
  int         cnt_full_we  = 0;    // we while full
  int         cnt_empty_re = 0;    // re while empty
  int         cnt_both     = 0;    // we and re in the same cycle

  always @(posedge clk) begin
    if (rst) model.delete();
    else begin
      logic do_w, do_r;
      do_w = we && (model.size() < DEPTH);
      do_r = re && (model.size() > 0);
      if (we && model.size() == DEPTH) cnt_full_we++;
      if (re && model.size() == 0)     cnt_empty_re++;
      if (we && re)                    cnt_both++;
      if (do_r) void'(model.pop_front());
      if (do_w) model.push_back(ff_in);
    end
  end

  // Checker: compare flags and head of the FIFO with the model every cycle
  always @(negedge clk) if (checking) begin
    checks++;
    if (empty !== (model.size() == 0)) begin
      errors++;
      if (errors <= 10)
        $display("[%0t] ERROR: empty = %b, model has %0d entries", $time, empty, model.size());
    end
    if (full !== (model.size() == DEPTH)) begin
      errors++;
      if (errors <= 10)
        $display("[%0t] ERROR: full = %b, model has %0d entries", $time, full, model.size());
    end
    if (model.size() > 0 && ff_out !== model[0]) begin
      errors++;
      if (errors <= 10)
        $display("[%0t] ERROR: ff_out = 0x%h, model head = 0x%h", $time, ff_out, model[0]);
    end
  end

  // ---------------------------------------------------------------
  // Helper tasks (drive on negedge, DUT samples on posedge)
  // ---------------------------------------------------------------
  task automatic push(input logic [7:0] b);
    @(negedge clk);
    ff_in = b;
    we    = 1;
    @(negedge clk);
    we    = 0;
  endtask

  // Check the head of the FIFO, then pop it
  task automatic pop_check(input string what, input logic [7:0] exp);
    @(negedge clk);
    if (empty !== 1'b0) begin
      $display("[%0t] ERROR: %s: FIFO is empty, expected 0x%h", $time, what, exp);
      errors++;
    end else if (ff_out !== exp) begin
      $display("[%0t] ERROR: %s = 0x%h, expected 0x%h", $time, what, ff_out, exp);
      errors++;
    end else
      $display("[%0t] OK   : %s = 0x%h", $time, what, ff_out);
    re = 1;
    @(negedge clk);
    re = 0;
  endtask

  task automatic check_flags(input string what, input logic exp_empty,
                             input logic exp_full);
    @(negedge clk);
    if (empty !== exp_empty || full !== exp_full) begin
      $display("[%0t] ERROR: %s: empty = %b, full = %b, expected %b, %b",
               $time, what, empty, full, exp_empty, exp_full);
      errors++;
    end else
      $display("[%0t] OK   : %s (empty = %b, full = %b)", $time, what, empty, full);
  endtask

  // Main test
  initial begin
    logic [7:0] q [$];
    int pw, pr;

    $dumpfile("FIFO_tb.vcd");
    $dumpvars(0, FIFO_tb);

    // Reset
    repeat (3) @(negedge clk);
    rst = 0;
    checking = 1;

    // Test 1: after reset the FIFO is empty and not full
    check_flags("after reset", 1'b1, 1'b0);

    // Test 2: one byte in, visible at the output, then out
    push(8'hA5);
    check_flags("after one write", 1'b0, 1'b0);
    pop_check("single byte", 8'hA5);
    check_flags("after one read", 1'b1, 1'b0);

    // Test 3: first in, first out
    for (int i = 0; i < 8; i++) push(pattern(i));
    check_flags("after eight writes", 1'b0, 1'b0);
    for (int i = 0; i < 8; i++) pop_check($sformatf("order byte %0d", i), pattern(i));
    check_flags("after eight reads", 1'b1, 1'b0);

    // Test 4: fill the FIFO, extra write must be ignored
    for (int i = 0; i < DEPTH; i++) push(pattern(i));
    check_flags("FIFO full", 1'b0, 1'b1);
    push(8'hEE);
    check_flags("write while full ignored", 1'b0, 1'b1);
    for (int i = 0; i < DEPTH; i++) pop_check($sformatf("full FIFO byte %0d", i), pattern(i));
    check_flags("FIFO drained (0xEE not stored)", 1'b1, 1'b0);

    // Test 5: read while empty must be ignored (read pointer must not move)
    @(negedge clk);
    re = 1;
    repeat (3) @(negedge clk);
    re = 0;
    check_flags("read while empty ignored", 1'b1, 1'b0);
    push(8'h11);
    push(8'h22);
    pop_check("after read while empty, first", 8'h11);
    pop_check("after read while empty, second", 8'h22);

    // Test 6: write and read in the same cycle when empty:
    // the write is stored, the read is ignored
    @(negedge clk);
    ff_in = 8'h5A;
    we    = 1;
    re    = 1;
    @(negedge clk);
    we    = 0;
    re    = 0;
    check_flags("write and read when empty", 1'b0, 1'b0);
    pop_check("write and read when empty, data", 8'h5A);

    // Test 7: write and read in the same cycle with data inside,
    // the number of entries stays the same and the order is kept
    for (int i = 0; i < 5; i++) begin
      push(pattern(i));
      q.push_back(pattern(i));
    end
    for (int k = 0; k < 10; k++) begin
      @(negedge clk);
      ff_in = pattern(100 + k);
      we    = 1;
      re    = 1;
      q.push_back(pattern(100 + k));
      void'(q.pop_front());
    end
    @(negedge clk);
    we = 0;
    re = 0;
    check_flags("after 10 simultaneous cycles", 1'b0, 1'b0);
    for (int i = 0; i < 5; i++) pop_check($sformatf("simultaneous byte %0d", i), q[i]);
    check_flags("after simultaneous test", 1'b1, 1'b0);

    // Test 8: write and read in the same cycle when full:
    // the read happens, the write is dropped
    for (int i = 0; i < DEPTH; i++) push(pattern(i));
    @(negedge clk);
    ff_in = 8'hEE;
    we    = 1;
    re    = 1;
    @(negedge clk);
    we    = 0;
    re    = 0;
    check_flags("write and read when full", 1'b0, 1'b0);
    for (int i = 1; i < DEPTH; i++) pop_check($sformatf("after full + both, byte %0d", i), pattern(i));
    check_flags("after full + both drained (0xEE not stored)", 1'b1, 1'b0);

    // Test 9: pointers wrap around many times (3 in, 3 out, 100 times)
    for (int n = 0; n < 100; n++) begin
      for (int i = 0; i < 3; i++) push(pattern(n * 3 + i));
      for (int i = 0; i < 3; i++) pop_check($sformatf("wrap %0d byte %0d", n, i), pattern(n * 3 + i));
    end
    check_flags("after wrap-around", 1'b1, 1'b0);

    // Test 10: reset when full clears the FIFO, old data is not readable
    for (int i = 0; i < DEPTH; i++) push(pattern(i));
    check_flags("full before reset", 1'b0, 1'b1);
    @(negedge clk);
    rst = 1;
    repeat (2) @(negedge clk);
    rst = 0;
    check_flags("after reset when full", 1'b1, 1'b0);
    push(8'h5A);
    pop_check("byte after reset", 8'h5A);
    check_flags("after reset test", 1'b1, 1'b0);

    // Test 11: random reads and writes, compared with the model every cycle.
    // Phases: mostly writing, mostly reading, balanced, both busy.
    for (int cyc = 0; cyc < N_RANDOM; cyc++) begin
      case ((cyc / 250) % 4)
        0: begin pw = 80; pr = 20; end
        1: begin pw = 20; pr = 80; end
        2: begin pw = 50; pr = 50; end
        default: begin pw = 95; pr = 95; end
      endcase
      @(negedge clk);
      we    = ($urandom_range(0, 99) < pw);
      re    = ($urandom_range(0, 99) < pr);
      ff_in = $urandom_range(0, 255);
    end
    @(negedge clk);
    we = 0;
    re = 0;
    $display("[%0t] INFO : random: %0d cycles, we while full %0d, re while empty %0d, we+re %0d",
             $time, N_RANDOM, cnt_full_we, cnt_empty_re, cnt_both);
    if (cnt_full_we == 0 || cnt_empty_re == 0 || cnt_both == 0) begin
      $display("ERROR: random test did not reach all corner cases");
      errors++;
    end
    // Drain what is left
    re = 1;
    repeat (DEPTH + 2) @(negedge clk);
    re = 0;
    check_flags("after random test drained", 1'b1, 1'b0);

    // Summary
    $display("INFO : %0d cycles compared with the model", checks);
    if (errors == 0) $display("\n===== PASS =====");
    else             $display("\n===== FAIL: %0d errors =====", errors);
    $finish;
  end

  // Timeout guard
  initial begin
    #(CLK_PERIOD * 40000);
    $display("ERROR: timeout");
    $finish;
  end

endmodule
