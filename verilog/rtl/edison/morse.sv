// SystemVerilog Counter Module
// Simple 4-bit up counter with reset and enable

module morse (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       enable,
  output logic [3:0] count
);

  logic [3:0] count_n;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 4'b0000;
    end else begin
      count <= count_n;
    end
  end

  always_comb begin
    if (enable) begin
        count_n = count + 1;
    end else begin
        count_n = count;
    end
  end

endmodule
