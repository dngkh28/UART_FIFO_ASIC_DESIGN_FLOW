`timescale 1ns/1ps
module uart_tb();
  logic clk, rst;
  logic rx, tx;
  logic [7:0] tx_data_in;
  logic [7:0] rx_data_out;
  logic we, re;
  logic tx_active;
  logic full_tx, empty_tx, full_rx, empty_rx;
  int   errors = 0;
  byte unsigned test_data[] = '{8'h41, 8'hA5, 8'h00, 8'hFF};

  // 1. Gọi module cần kiểm tra (DUT)
  uart #(.clk_freq(50000000), .baud_rate(115200)) dut (
    .clk(clk), .rst(rst), .rx(rx), .tx(tx),
    .tx_data_in(tx_data_in), .rx_data_out(rx_data_out),
    .we(we), .re(re), .tx_active(tx_active),
    .full_rx(full_rx), .empty_rx(empty_rx),
    .full_tx(full_tx), .empty_tx(empty_tx)
  );

  // 2. Tạo clock 50 MHz (chu kỳ 20 ns)
  initial clk = 0;
  always #10 clk = ~clk;

  // 3. Nối vòng: dây tx đưa thẳng về rx
  assign rx = tx;

  // 4. Task ghi 1 byte vào FIFO phát
  task write_byte(input [7:0] data);
    @(negedge clk);
    tx_data_in = data;
    we         = 1;
    @(negedge clk);
    we         = 0;
  endtask

  // 5. Task chờ FIFO nhận có dữ liệu, đọc ra và so sánh
  task read_check(input [7:0] expected);
    wait (!empty_rx);
    @(negedge clk);
    if (rx_data_out === expected)
      $display("[%0t] PASS: gui 0x%h, nhan 0x%h", $time, expected, rx_data_out);
    else begin
      $display("[%0t] FAIL: gui 0x%h, nhan 0x%h", $time, expected, rx_data_out);
      errors++;
    end
    re = 1;                         // FIFO show-ahead: đọc xong mới pop
    @(negedge clk);
    re = 0;
  endtask

  // 6. Kịch bản kiểm tra
  initial begin
    $timeformat(-6, 1, " us", 10);
    rst = 1; we = 0; re = 0; tx_data_in = 8'h00;
    repeat (5) @(negedge clk);
    rst = 0;
    repeat (5) @(negedge clk);

    // Gửi từng byte một
    foreach (test_data[i]) begin
      write_byte(test_data[i]);
      read_check(test_data[i]);
    end

    // Gửi liên tiếp (burst) qua FIFO rồi mới đọc
    foreach (test_data[i]) write_byte(test_data[i]);
    foreach (test_data[i]) read_check(test_data[i]);

    if (errors == 0) $display("===== PASS =====");
    else             $display("===== FAIL: %0d loi =====", errors);
    $finish;
  end


  // 7. Watchdog: tránh treo mô phỏng nếu không nhận được byte
  initial begin
    #5ms;
    $display("TIMEOUT"); $finish;
  end

endmodule
