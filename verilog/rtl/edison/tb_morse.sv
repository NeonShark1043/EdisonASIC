// SystemVerilog Testbench
module tb_morse;

  logic       clk;
  logic       rst_n;
  logic       enable;
  logic [3:0] count;

  // Instantiate the counter
  counter dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .count(count)
  );

  // Clock generation
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 10ns period
  end

  // Test sequence
  initial begin
    // Initialize
    rst_n = 1'b0;
    enable = 1'b0;
    #10 rst_n = 1'b1;

    // Test 1: Count with enable
    $display("Test 1: Counting with enable");
    enable = 1'b1;
    repeat(10) @(posedge clk);

    // Test 2: Disable counting
    $display("Test 2: Disable counting (hold value)");
    enable = 1'b0;
    repeat(5) @(posedge clk);

    // Test 3: Re-enable counting
    $display("Test 3: Re-enable counting");
    enable = 1'b1;
    repeat(8) @(posedge clk);

    // Test 4: Reset
    $display("Test 4: Reset");
    rst_n = 1'b0;
    #10 rst_n = 1'b1;
    repeat(3) @(posedge clk);

    $finish;
  end

  // Monitor output
  initial begin
    $monitor("Time: %0t | clk: %b | rst_n: %b | enable: %b | count: %d",
             $time, clk, rst_n, enable, count);
  end

endmodule
